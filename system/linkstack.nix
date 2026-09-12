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
#   into /var/lib/linkstack on every activation, PRESERVING the mutable paths
#   (`.env`, `storage/`, `bootstrap/cache/`). Bumping `version` below is the
#   upgrade mechanism; state survives because those paths are excluded.
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
      # --exclude keeps the mutable paths the installer owns; no --delete, so
      # user-uploaded themes/blocks are never clobbered on upgrade.
      #
      # -rl (NOT -a) plus the --no-* flags: this unit runs as an unprivileged
      # user, which cannot preserve owner/group/perms/times from the root-owned
      # store tree. `-a` here fails with "Operation not permitted" on every dir.
      #
      # --chmod is REQUIRED, not cosmetic: store dirs are mode 0555, and rsync
      # would otherwise create e.g. `vendor/` read-only and then fail to mkdir
      # its children ("mkdir .../vendor/vlucas failed: Permission denied").
      ${pkgs.rsync}/bin/rsync -rl --no-perms --no-owner --no-group \
        --chmod=D755,F644 \
        --exclude='/.env' \
        --exclude='/storage' \
        --exclude='/bootstrap/cache' \
        ${linkstack}/ ${dataDir}/

      # First run: seed .env from the shipped template (empty APP_KEY, sqlite).
      # The browser installer fills it in; it must be writable by the service.
      if [ ! -e ${dataDir}/.env ]; then
        install -m 0640 ${linkstack}/.env ${dataDir}/.env
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
