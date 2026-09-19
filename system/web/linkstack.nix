# LinkStack — self-hosted Linktree alternative, served at links.<domain>.
# Not in nixpkgs: fetches the official release, runs it under php-fpm on SQLite,
# publishes via system/web/caddy.nix.
#
# Runs from a mutable StateDirectory (store path is read-only; the installer
# writes .env and storage/ at runtime). linkstack-setup rsyncs the store copy
# on every activation, excluding app-owned mutable paths; bumping `version`
# below is the upgrade mechanism and state survives because those paths are
# excluded.
#
# Security: docroot == app root, so .env/SQLite/source must not be exposed.
# Caddy ignores .htaccess, so its denials are re-stated in caddy.nix — keep in
# sync.
{ config, lib, pkgs, domain, ... }:

let
  # Bump to upgrade; hash must match the new asset (nix store prefetch-file <url>).
  version = "4.8.6";

  user = "linkstack";
  group = "linkstack";
  dataDir = "/var/lib/linkstack";
  vhost = "links.${domain}";

  linkstackSrc = pkgs.fetchurl {
    url = "https://github.com/LinkStackOrg/LinkStack/releases/download/v${version}/linkstack.zip";
    hash = "sha256-HeblPCSImxEP0t311jqtq0NNrdmbgTdnm7qgpmRDk84=";
  };

  # Read-only reference copy; zip has a single top-level `linkstack/` dir.
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

  # Laravel's required extensions (incl. those index.php asserts at install);
  # sqlite3 + pdo_sqlite back the default database.
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
  # --- PHP-FPM pool, tuned small (single-user page on a 2 GB box) -----------
  services.phpfpm.pools.linkstack = {
    inherit user group;
    phpPackage = php;

    # phpOptions is appended RAW to php.ini: comments must be `;` not `#` — a
    # `#` line aborts the file and silently drops every option after it.
    phpOptions = ''
      log_errors = on
      memory_limit = 256M
      upload_max_filesize = 16M
      post_max_size = 20M

      ; Don't advertise the PHP build (pentest F-08); nothing depends on it.
      expose_php = off
    '';

    settings = {
      # Caddy runs as the `caddy` user and must be able to talk to the socket.
      "listen.owner" = "caddy";
      "listen.group" = group;
      "listen.mode" = "0660";

      # LinkStack opens config/advanced-config.php via a path RELATIVE to cwd;
      # php-fpm's default cwd is `/` (no WorkingDirectory/chdir), so the admin
      # config editor 500s. Pin cwd to the docroot (as Apache/nginx hosting does).
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

    # Re-run on upgrade (release change / version bump).
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

      # rsync the store copy into the data dir. Exclusions are APP-OWNED
      # mutable paths (seeded below); no --delete, so user themes/data survive
      # upgrades. The sqlite exclusion is the critical one: the release ships
      # its own schema-migrated copy, so without it every activation would
      # overwrite the live database and silently wipe all accounts/links.
      #
      # -rlp not -a: unit is unprivileged (no-owner/no-group); store tree is
      # 0555/0444 so --chmod is required, and -p re-applies modes to existing
      # files (else database.sqlite stays 0444 -> "readonly database").
      ${pkgs.rsync}/bin/rsync -rlp --no-owner --no-group \
        --chmod=D755,F644 \
        --exclude='/.env' \
        --exclude='/INSTALLING' \
        --exclude='/storage' \
        --exclude='/bootstrap/cache' \
        --exclude='/config/advanced-config.php' \
        --exclude='/database/database.sqlite' \
        ${linkstack}/ ${dataDir}/

      # Seed storage/'s non-mutable skeleton (the tree itself is excluded
      # above). storage/app/ISINSTALLED gates the self-heal that creates
      # config/advanced-config.php; it's never written by the app, so if
      # missing, the admin config editor 500s (chicken-and-egg: "Restore
      # defaults" is the only fix and needs the file). storage/templates/
      # advanced-config.php is that copy's source. --ignore-existing: never
      # overwrite runtime state or a user-edited template. --chmod matches
      # tmpfiles modes below so existing dirs aren't churned.
      ${pkgs.rsync}/bin/rsync -rlp --no-owner --no-group --ignore-existing \
        --chmod=D750,F640 \
        ${linkstack}/storage/ ${dataDir}/storage/

      # First run: seed .env (empty APP_KEY, sqlite) — the installer fills it in.
      if [ ! -e ${dataDir}/.env ]; then
        install -m 0640 ${linkstack}/.env ${dataDir}/.env

        # Installer trigger: exists only during browser setup (app deletes it
        # when done). Reseed here (guarded by .env absence) so a rebuild can't
        # drop a live install back into installer mode — while INSTALLING
        # exists, `GET /skip` seeds AdminSeeder and logs in as `admin`. Deleting
        # .env is the documented way to force a re-install.
        install -m 0640 ${linkstack}/INSTALLING ${dataDir}/INSTALLING

        # Seed the SQLite DB from the release (Laravel won't create it); rsync
        # excludes it thereafter so a rebuild never clobbers live data.
        install -m 0640 ${linkstack}/database/database.sqlite ${dataDir}/database/database.sqlite
      fi

      # Generate the app encryption key on first run (Laravel throws
      # MissingAppKeyException before the installer otherwise). Written directly
      # because `artisan key:generate` boots Livewire and dies with the same
      # exception. Format: base64: + 32 random bytes. base64 -w0 no-newline and
      # the Nix-escaped variable are deliberate.
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
    # File-cache driver writes here; release ships it with only a .gitignore.
    "${dataDir}/storage/framework/cache/data".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/framework/sessions".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/framework/views".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/logs".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/backups".d = { inherit user group; mode = "0750"; };
    "${dataDir}/storage/templates".d = { inherit user group; mode = "0750"; };
    # `bootstrap` must be declared explicitly: otherwise tmpfiles makes it an
    # implicit root:root parent and the ${user} setup unit can't write it.
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

  # Caddy vhost is in system/web/caddy.nix: docroot=${dataDir}, proxies PHP to
  # the pool socket, re-states the .htaccess denials. vhost: ${vhost}.

  # --- Deployment -----------------------------------------------------------
  # 1. DNS: A record links.${domain} -> <LINODE_IP>, DNS-only (grey-cloud) so
  #    Caddy's ACME HTTP-01 challenge reaches this box.
  # 2. First visit runs the installer (INSTALLING present): https://${vhost}/
  #    creates the admin account + SQLite DB. Page and installer are PUBLIC (no
  #    basic-auth) — finish setup promptly; until then anyone can hit
  #    /create-admin.
  # 3. Manual fixes: edit ${dataDir} (owned by ${user}:${group}), not the store.
}
