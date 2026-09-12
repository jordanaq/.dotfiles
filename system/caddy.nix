# Caddy — auto-TLS reverse proxy in front of SearXNG, the Calibre services,
# LinkStack, and the public personal site at the apex domain.
#
# Caddy obtains and renews a Let's Encrypt certificate for
# search.<domain> automatically (HTTP-01 challenge on :80) and enforces
# basic-auth, then proxies to the loopback SearXNG instance.
#
# The basic-auth credential is deliberately NOT stored here — this repo is
# PUBLIC. It lives on the server in /etc/secrets/caddy.env as
# `CADDY_AUTH_HASH=<bcrypt hash>`, wired in via services.caddy.environmentFile
# and referenced below as {$CADDY_AUTH_HASH}. Caddy substitutes {$VAR} from its
# process environment when it adapts the Caddyfile at startup, so the hash never
# enters the nix store or git. (Note `{$…}`, not `{env.…}`.)
#
# Before deploying:
#   1. DNS: A record  search.<domain> -> <LINODE_IP>  (DNS-only / grey cloud,
#      so the ACME HTTP-01 challenge reaches this box directly).
#   2. Create the secrets file on the server (0600):
#        nix run nixpkgs#caddy -- hash-password --plaintext '<password>'
#        sudo install -m 600 /dev/null /etc/secrets/caddy.env
#        printf 'CADDY_AUTH_HASH=%s\n' '<that $2a$14$… hash>' | sudo tee /etc/secrets/caddy.env
#      It MUST exist before `nixos-rebuild switch`: systemd's EnvironmentFile is
#      not optional here, and Caddy refuses to start without it
#      ("username and password cannot be empty or missing").
#   3. Change the password later with: edit /etc/secrets/caddy.env -> restart caddy.
{ config, domain, inputs, ... }:

{
  services.caddy = {
    enable = true;

    # Supplies CADDY_AUTH_HASH to Caddy's process environment (systemd
    # EnvironmentFile, read as root before dropping to the caddy user).
    environmentFile = "/etc/secrets/caddy.env";

    virtualHosts = {
      "search.${domain}".extraConfig = ''
        basic_auth {
          tsiru {$CADDY_AUTH_HASH}
        }
        reverse_proxy 127.0.0.1:8888
      '';

      # calibre-web — browser UI for the Calibre library. calibre-web's OWN
      # login is the gate (deliberately NO Caddy basicauth here: a second gate
      # would break OPDS / reader-app access).
      # Access logging is automatic (the module's `logFormat` default writes
      # /var/log/caddy/access-<host>.log); we add rolling so it can't grow
      # unbounded. fail2ban reads these files.
      "library.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-library.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          reverse_proxy 127.0.0.1:8083
        '';
      };

      # Calibre content server — remote `calibredb` + OPDS. calibre-server's
      # OWN auth is the gate.
      "calibre.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-calibre.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          reverse_proxy 127.0.0.1:8081
        '';
      };

      # tsiru.pet — the public personal site (bio + projects), built from the
      # `tsiru-pet` flake input (github.com/jordanaq/tsiru-pet) at nix build
      # time by Zola. Served straight out of the read-only store path: no
      # service, no PHP, no DB, zero runtime RAM.
      #
      # Deliberately PUBLIC: no `basic_auth` here (unlike search.${domain}).
      "${domain}" = {
        extraConfig = ''
          root * ${inputs.tsiru-pet.packages.${config.nixpkgs.hostPlatform.system}.default}
          file_server
        '';
      };

      # notes.<domain> — public Quartz export of the vault's Concepts/ folder
      # (see ~/Documents/Projects/notes-site). Static files are rsynced to
      # /var/lib/notes-site by the publish step; served read-only, no service,
      # no runtime RAM. Deliberately PUBLIC.
      "notes.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-notes.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          root * /var/lib/notes-site
          file_server
        '';
      };

      # linkstack — link-in-bio page (see system/linkstack.nix).
      #
      # Deliberately PUBLIC: no `basic_auth` here (unlike search.${domain}).
      # Anyone can read the page; LinkStack's own admin login — created by the
      # first-run installer — gates *editing* only, never viewing.
      #
      # ⚠️ Unlike the other vhosts, LinkStack's docroot is the APP ROOT, not a
      # `public/` subdir — that is how upstream ships it (shared-hosting layout),
      # and `.htaccess` is what normally hides `.env`, the SQLite DB and the
      # release archives. Caddy ignores `.htaccess`, so those denials are
      # re-stated here. KEEP THIS IN SYNC with the `.htaccess` in the release.
      "links.${domain}" = {
        extraConfig = ''
          root * /var/lib/linkstack

          # Deny dotfiles (covers .env), the SQLite database, release archives,
          # and the application source directories. Multiple `path` lines in
          # one named matcher are OR-ed together.
          @blocked {
            path /.* *.sqlite *.zip
            path /app/* /config/* /database/* /bootstrap/* /vendor/* /routes/*
          }
          respond @blocked 404

          php_fastcgi unix/${config.services.phpfpm.pools.linkstack.socket}
          file_server
        '';
      };

      # mail.<domain> — the JMAP + CalDAV/CardDAV endpoint (and the Stalwart
      # webadmin) served by Stalwart's loopback HTTP listener.
      #
      # Deliberately PUBLIC: Stalwart authenticates these requests itself, and
      # CalDAV/CardDAV clients (phones, Thunderbird) plus Bulwark talk to this
      # host directly. Putting basic_auth in front would break every non-browser
      # client, exactly as it would break OPDS on the calibre vhost.
      #
      # TLS comes from security.acme (DNS-01 via Spaceship), NOT Caddy's own
      # ACME — the same certificate Stalwart uses on the mail ports, so there is
      # one cert for the name instead of two.
      "mail.${domain}" = {
        extraConfig = ''
          tls /var/lib/acme/mail.${domain}/fullchain.pem /var/lib/acme/mail.${domain}/key.pem
          reverse_proxy 127.0.0.1:8080
        '';
      };

      # webmail.<domain> — Bulwark (system/bulwark.nix). Public: Bulwark's own
      # login gates it, and the login IS the mail account.
      "webmail.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-webmail.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          reverse_proxy 127.0.0.1:3100
        '';
      };

      # admin.<domain> — the Stalwart server control panel (create accounts,
      # DKIM, queues, logs). GATED with basic_auth, same mechanism as
      # search.<domain>, because this is the panel that can hand out accounts.
      "admin.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-admin.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          basic_auth {
            tsiru {$CADDY_AUTH_HASH}
          }
          reverse_proxy 127.0.0.1:8080
        '';
      };
    };
  };
}
