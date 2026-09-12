# LinkStack — self-hosted Linktree alternative, served at links.<domain>.
#
# LinkStack is NOT in nixpkgs (no package, no module), so this file does three
# things itself:
#   1. fetches the official release bundle (which already vendors composer's
#      `vendor/` — no PHP build step needed),
#   2. runs it under php-fpm with a SQLite database,
#   3. publishes it through the existing Caddy reverse proxy (system/caddy.nix).
#
# WHY A STATE-DIRECTORY COPY (not a read-only store path):
#   LinkStack ships in the shared-hosting layout — the front controller
#   `index.php` sits at the APP ROOT, and `.htaccess` rewrites everything to it.
#   Its installer is a browser wizard that WRITES to the install: it creates
#   `.env` and populates `storage/`. A Nix store path is read-only, so the app
#   must live in a mutable directory. `linkstack-setup` rsyncs the store copy
#   into /var/lib/linkstack on every activation, PRESERVING the app-owned
#   mutable paths (`.env`, `INSTALLING`, `storage/`, `bootstrap/cache/`,
#   `config/advanced-config.php`). Two of those still need a seed from the
#   release on first run — the installer trigger and the non-mutable skeleton
#   files shipped inside `storage/` — so the unit seeds them separately
#   without ever overwriting what the app has written since. Bumping `version`
#   below is the upgrade mechanism; state survives because those paths are
#   excluded.
#
# SECURITY NOTE: because the docroot is the app root, the web server must NOT
#   expose `.env` / the SQLite DB / the app source. On Apache that is the job of
#   `.htaccess` (which denies dotfiles, *.sqlite, *.zip). Caddy ignores
#   `.htaccess`, so the equivalent denials are re-stated in system/caddy.nix.
#   Keep the two in sync if either changes.
{ config, lib, pkgs, domain, ... }:

let
  # Bump this to upgrade. The hash must match the new release asset; recompute
  # with:  nix store prefetch-file <url>
  version = "4.8.6";

  user = "linkstack";
  group = "linkstack";
  dataDir = "/var/lib/linkstack";
  vhost = "links.${domain}";

  linkstackSrc = pkgs.fetchurl {
    url = "https://github.com/LinkStackOrg/LinkStack/releases/download/v${version}/linkstack.zip";
    hash = "sha256-HeblPCSImxEP0t311jqtq0NNrdmbgTdnm7qgpmRDk84=";
  };

  # Unpack the release into the store as a read-only reference copy. The zip
  # contains a single top-level `linkstack/` directory (hence sourceRoot).
  linkstack = pkgs.stdenvNoCC.mkDerivation {
    pname = "linkstack";
    inherit version;
    src = linkstackSrc;
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = "linkstack";
    dontConfigure = true;
    dontBuild = true;
    dontPatchShebangs = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      runHook postInstall
    '';
  };

  # Laravel's required extensions, plus the ones index.php checks for at install
  # time (it asserts bcmath/ctype/curl/dom/fileinfo/json/mbstring/openssl/pcre/
  # pdo/tokenizer/xml/iconv). sqlite3 + pdo_sqlite back the default database.
  php = pkgs.php83.withExtensions (
    { enabled, all }:
    enabled
    ++ (with all; [
      bcmath
      ctype
      curl
      dom
      fileinfo
      gd
      iconv
      intl
      mbstring
      openssl
      pdo_sqlite
      simplexml
      sqlite3
      tokenizer
      xml
      zip
    ])
  );
in
{
  # --- PHP-FPM pool ---------------------------------------------------------
  # One pool, tuned small (single-user page on a 2 GB box).
  services.phpfpm.pools.linkstack = {
    inherit user group;
    phpPackage = php;

    phpOptions = ''
      log_errors = on
      memory_limit = 256M
      upload_max_filesize = 16M
      post_max_size = 20M
    '';

    settings = {
      # Caddy runs as the `caddy` user and must be able to talk to the socket.
      "listen.owner" = "caddy";
      "listen.group" = group;
      "listen.mode" = "0660";

      # LinkStack resolves a handful of paths RELATIVE to the process working
      # directory rather than through Laravel's base_path(): the admin config
      # editor reads `file_get_contents('config/advanced-config.php')` and
      # AdminController::editAC writes `file_put_contents('config/advanced-config.php')`.
      # php-fpm runs with cwd `/` unless told otherwise — the systemd unit the
      # module generates sets no WorkingDirectory, and the pool conf it emits
      # carries no `chdir` — so those relative opens resolve against `/` and the
      # editor 500s with `Failed to open stream: No such file or directory`
      # even though config/advanced-config.php exists at the app root.
      # Pin the pool's working directory to the docroot, which is how LinkStack
      # is run under Apache/nginx shared hosting (cwd == app root).
      "chdir" = dataDir;

      "pm" = "dynamic";
      "pm.max_children" = 8;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
      "pm.max_requests" = 500;
    };
  };

  # --- Deploy the app into the mutable data directory -----------------------
  systemd.services.linkstack-setup = {
    description = "Deploy LinkStack into ${dataDir} and prepare writable state";
    before = [ "phpfpm-linkstack.service" ];
    requiredBy = [ "phpfpm-linkstack.service" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    wants = [ "systemd-tmpfiles-setup.service" ];

    # Re-run when the packaged release changes (i.e. on a version bump).
    restartTriggers = [ linkstack ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = user;
      Group = group;
      # Creates /var/lib/linkstack owned by user:group if it does not exist.
      StateDirectory = "linkstack";
    };

    script = ''
      set -euo pipefail

      # Copy the code from the read-only store copy into the data dir.
      # --exclude keeps the APP-OWNED mutable paths out of the sync; no
      # --delete, so user-uploaded themes/blocks are never clobbered on
      # upgrade. Each exclusion is a path the app itself rewrites at runtime:
      #
      #   /.env                       seeded below, then owned by the installer
      #   /INSTALLING                 installer trigger — seeded below, and the
      #                               APP DELETES IT once setup completes, so
      #                               re-shipping it would put a live install
      #                               back into installer mode on every rebuild
      #   /storage                    app-owned runtime state; the non-mutable
      #                               skeleton inside it is re-seeded below
      #   /bootstrap/cache            Laravel's regenerated caches
      #   /config/advanced-config.php created at runtime by the self-heal in
      #                               routes/web.php, then edited from the
      #                               admin panel (see the seed block below)
      #
      # -rlp (NOT -a): --no-owner/--no-group because this unit is unprivileged
      # and cannot set ownership from the root-owned store tree.
      #
      # --chmod is REQUIRED, not cosmetic: store dirs/files are mode 0555/0444,
      # so without it rsync creates e.g. `vendor/` read-only and cannot mkdir
      # its children, and every copied file lands read-only.
      #
      # -p (perms) is ALSO REQUIRED: it makes rsync re-apply the --chmod modes to
      # files that already exist, repairing in place a tree that an earlier
      # deploy left read-only. Without it `database/database.sqlite` stays 0444
      # and SQLite fails with "attempt to write a readonly database".
      ${pkgs.rsync}/bin/rsync -rlp --no-owner --no-group \
        --chmod=D755,F644 \
        --exclude='/.env' \
        --exclude='/INSTALLING' \
        --exclude='/storage' \
        --exclude='/bootstrap/cache' \
        --exclude='/config/advanced-config.php' \
        ${linkstack}/ ${dataDir}/

      # --- Seed the release's storage/ skeleton -----------------------------
      # `storage/` is app-owned runtime state and is deliberately excluded
      # above — but the release ALSO ships a few NON-mutable files inside it
      # that the app needs in order to boot correctly. Excluding the whole tree
      # dropped those too, and that is what broke the admin config page:
      #
      #   storage/app/ISINSTALLED
      #     Gate for the post-install self-heal at the top of routes/web.php.
      #     NOTHING in LinkStack ever writes this file — it ships in the release
      #     and is only ever read — so if it is missing that block never runs
      #     and config/advanced-config.php is never created. The admin panel's
      #     config editor then dies on file_get_contents('config/advanced-config.php')
      #     *before* you can reach the "Restore defaults" button — which is the
      #     one thing that would have created the file. Chicken-and-egg, and
      #     exactly the reported HTTP 500.
      #
      #   storage/templates/advanced-config.php
      #     The source for that self-heal copy, and for the panel's "Restore
      #     defaults" button (AdminController::editAC).
      #
      # --ignore-existing: create what is absent, never overwrite. Runtime state
      # the app has since written (uploads, compiled views, sessions, logs,
      # backups) is left strictly alone — which is also what preserves a
      # user-edited storage/templates/advanced-config.php across upgrades.
      #
      # --chmod deliberately matches the modes systemd-tmpfiles declares below,
      # so this does not churn the permissions of the storage dirs it walks
      # through; only genuinely new entries get the declared modes.
      ${pkgs.rsync}/bin/rsync -rlp --no-owner --no-group --ignore-existing \
        --chmod=D750,F640 \
        ${linkstack}/storage/ ${dataDir}/storage/

      # First run: seed .env from the shipped template (empty APP_KEY, sqlite).
      # The browser installer fills it in; it must be writable by the service.
      if [ ! -e ${dataDir}/.env ]; then
        install -m 0640 ${linkstack}/.env ${dataDir}/.env

        # Installer trigger. LinkStack only wires up the browser installer while
        # `INSTALLING` exists at the app root, and InstallerController DELETES
        # it when setup finishes — hence --exclude above. Seeding it inside this
        # same first-run guard (the app never removes .env, so this block runs
        # exactly once) means a rebuild cannot drop a live install back into
        # installer mode. That is not merely cosmetic: while INSTALLING exists
        # the installer's catch-all registers `GET /skip`, which runs
        # `db:seed AdminSeeder` and logs the caller in as `admin`.
        # Deleting .env is therefore the documented way to force a re-install.
        install -m 0640 ${linkstack}/INSTALLING ${dataDir}/INSTALLING
      fi

      # Generate the application encryption key on first run. Laravel throws
      # MissingAppKeyException from the HTTP middleware pipeline BEFORE the
      # installer route is reached, so the app cannot self-install without it.
      #
      # Written directly rather than via `artisan key:generate`: the console
      # kernel boots service providers (Livewire) that resolve the encrypter,
      # so artisan dies with the same exception it is meant to fix. Format is
      # Laravel's own: base64: + 32 random bytes.
      # NOTE: base64 -w0 emits no trailing newline, and the shell variable
      # reference below is Nix-escaped — both deliberate, not typos.
      if ! grep -q '^APP_KEY=base64:' ${dataDir}/.env; then
        key="base64:$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 -w0)"
        ${pkgs.gnused}/bin/sed -i "s|^APP_KEY=.*|APP_KEY=''${key}|" ${dataDir}/.env
      fi
    '';
  };

  # --- Writable tree the app owns (survives upgrades) -----------------------
  systemd.tmpfiles.settings."10-linkstack" = {
    "${dataDir}".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/app".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/app/public".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/framework".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/framework/cache".d = { inherit user group; mode = "0750"; };
    # Laravel's file cache driver writes here. The release ships this dir with
    # only a .gitignore in it, so declare it next to its parent to keep the
    # owner/mode authoritative here rather than inherited from whatever the
    # release happens to contain.
    "${dataDir}/storage/framework/cache/data".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/framework/sessions".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/framework/views".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/logs".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/backups".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/templates".d = { inherit user group; mode = "0750"; };
    # `bootstrap` MUST be listed explicitly. If only `bootstrap/cache` is
    # declared, systemd-tmpfiles creates `bootstrap` as an implicit parent
    # (root:root), and the setup unit — running as ${user} — then cannot write
    # bootstrap/app.php into it ("mkstemp ... Permission denied").
    "${dataDir}/bootstrap".d = { inherit user group; mode = "0750"; };
    "${dataDir}/bootstrap/cache".d = { inherit user group; mode = "0750"; };
  };

  # --- Service account ------------------------------------------------------
  users.users.${user} = {
    isSystemUser = true;
    inherit group;
    home = dataDir;
    description = "LinkStack service user";
  };
  users.groups.${group} = { };

  # Caddy needs read access to the static files it serves from ${dataDir}.
  users.users.caddy.extraGroups = [ group ];

  # --- Caddy vhost is declared in system/caddy.nix (kept with the others) ---
  # It serves ${dataDir} as the docroot, proxies PHP to the pool socket, and
  # re-states LinkStack's .htaccess denials. vhost name: ${vhost}.

  # --- Deployment checklist -------------------------------------------------
  # 1. DNS: A record links.${domain} -> <LINODE_IP>, grey-cloud (DNS-only) so
  #    Caddy's ACME HTTP-01 challenge reaches this box.
  # 2. First visit runs LinkStack's browser installer (INSTALLING file present):
  #      https://${vhost}/  ->  creates the admin account + SQLite DB.
  #    No secret file is needed up front; the installer writes ${dataDir}/.env.
  #    ⚠️ The page is PUBLIC (no basic-auth), so the installer is too — finish
  #    setup promptly after the first deploy so nobody else claims the admin
  #    login. Until then, anyone can reach /create-admin.
  # 3. If the wizard ever needs manual intervention, the app tree is at
  #    ${dataDir} (owned by ${user}:${group}) — inspect/edit there, not in the
  #    store.
}
