# Caddy — auto-TLS reverse proxy in front of SearXNG, Calibre, LinkStack, the
# public site, and the mail/office/webmail/vault vhosts.
#
# The basic-auth credential is NOT stored here (this repo is PUBLIC). It lives on
# the server in /etc/secrets/caddy.env as CADDY_AUTH_HASH, wired via
# services.caddy.environmentFile and referenced below as {$CADDY_AUTH_HASH} —
# Caddy substitutes {$VAR} from its environment, so the hash never enters the
# nix store or git. (Note `{$…}`, not `{env.…}`.)
# Before deploying: point A record search.<domain> at the Linode (DNS-only, so
# the ACME HTTP-01 challenge reaches the box directly), then create the secrets
# file BEFORE `nixos-rebuild switch` (systemd EnvironmentFile is not optional;
# Caddy refuses to start without the hash):
#   nix run nixpkgs#caddy -- hash-password --plaintext '<password>'
#   sudo install -m 600 /dev/null /etc/secrets/caddy.env
#   printf 'CADDY_AUTH_HASH=%s\n' '<$2a$14$… hash>' | sudo tee /etc/secrets/caddy.env
{ config, lib, domain, inputs, ... }:

let
  # HSTS on EVERY vhost. Pentest F-03: only library. carried it (from calibre-web,
  # not the proxy), so the password manager / webmail / mail admin went without.
  # Needs BOTH ops, as separate directives (a block would share deferral):
  # the immediate `header Field value` runs before the upstream writes its own
  # headers (covers Caddy short-circuits like search.'s 401), and `>Field`
  # (set-with-defer) overwrites an upstream's HSTS after the proxy writes.
  # Verified: exactly one STS field on every vhost. includeSubDomains is safe —
  # the only A-record name without HTTPS (status.<domain>) is stale and pending
  # deletion. Deliberately NO `preload` (one-way door).
  hstsValue = "max-age=31536000; includeSubDomains";
  hsts = ''
    header Strict-Transport-Security "${hstsValue}"
    header >Strict-Transport-Security "${hstsValue}"
  '';
in
{
  services.caddy = {
    enable = true;

    # Supplies CADDY_AUTH_HASH to Caddy's process environment.
    environmentFile = "/etc/secrets/caddy.env";

    # mapAttrs so the header is defined once and can't be forgotten on a new
    # vhost or drift between them.
    virtualHosts = lib.mapAttrs (name: vh: vh // {
      extraConfig = ''
        ${hsts}
        ${vh.extraConfig or ""}
      '';
    }) {
      "search.${domain}".extraConfig = ''
        basic_auth {
          tsiru {$CADDY_AUTH_HASH}
        }
        reverse_proxy 127.0.0.1:8888
      '';

      # calibre-web — browser UI for the Calibre library. Its OWN login is the
      # gate (a second basic_auth would break OPDS / reader-app access). Rolling
      # access log; fail2ban reads these files.
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

      # Calibre content server — remote calibredb + OPDS. calibre-server's own auth.
      "calibre.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-calibre.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          # Block TRACE: cross-site tracing / XST vector + fingerprint (pentest
          # F-07; calibre-server answered 200). `respond` is ordered before
          # reverse_proxy, so this wins.
          @trace method TRACE
          respond @trace 405

          reverse_proxy 127.0.0.1:8081
        '';
      };

      # tsiru.pet — the public personal site, built by Zola at nix build time
      # from the tsiru-pet flake input and served from the store path: no
      # service/DB, zero runtime RAM. Deliberately PUBLIC.
      "${domain}" = {
        extraConfig = ''
          root * ${inputs.tsiru-pet.packages.${config.nixpkgs.hostPlatform.system}.default}
          file_server
        '';
      };

      # notes.<domain> — public Quartz export of the vault's Concepts/, built on
      # this box (see system/web/notes-site) and served from /var/lib/notes-site.
      # Static only, zero runtime RAM. Deliberately PUBLIC.
      "notes.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-notes.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          root * /var/lib/notes-site

          # Quartz links are extensionless (/computing/.../mapreduce) while the
          # files are <name>.html — resolve before serving or every internal link
          # 404s.
          try_files {path} {path}.html {path}/index.html

          file_server

          # Use the site's own 404 page.
          handle_errors {
            rewrite * /404.html
            file_server
          }
        '';
      };

      # linkstack — link-in-bio page (see system/web/linkstack.nix). PUBLIC:
      # LinkStack's own admin login gates editing only. Docroot is the APP ROOT
      # (upstream shared-hosting layout) and `.htaccess` is what normally hides
      # .env/DB/archives — Caddy ignores `.htaccess`, so those denials are
      # re-stated here. KEEP IN SYNC with the release's `.htaccess`.
      "links.${domain}" = {
        extraConfig = ''
          root * /var/lib/linkstack

          # Deny dotfiles (.env), the SQLite DB, archives, and the app source.
          # Multiple `path` lines in one matcher are OR-ed.
          @blocked {
            path /.* *.sqlite *.zip
            path /app/* /config/* /database/* /bootstrap/* /vendor/* /routes/*
            path /storage/logs/* /storage/framework/* /storage/backups/*
            path /artisan /server.php /composer.json /composer.lock
            path /package.json /phpunit.xml
          }
          respond @blocked 404

          php_fastcgi unix/${config.services.phpfpm.pools.linkstack.socket}
          file_server
        '';
      };

      # mail.<domain> — JMAP + CalDAV/CardDAV + Stalwart webadmin. PUBLIC: Stalwart
      # authenticates these itself; basic_auth would break non-browser clients.
      # TLS is the security.acme DNS-01 cert (same one Stalwart uses), not Caddy's
      # own ACME — one cert for the name.
      "mail.${domain}" = {
        extraConfig = ''
          tls /var/lib/acme/mail.${domain}/fullchain.pem /var/lib/acme/mail.${domain}/key.pem

          # Bulwark is a different origin → browsers preflight every call and need
          # Access-Control-Allow-Origin. Stalwart's permissive-cors does NOT emit
          # these headers (verified live), so Caddy does. Phones/Thunderbird
          # (CalDAV/CardDAV) aren't browsers and ignore CORS.
          @cors header Origin https://webmail.${domain}
          header @cors {
            Access-Control-Allow-Origin "https://webmail.${domain}"
            Access-Control-Allow-Credentials "true"
            Access-Control-Allow-Methods "GET, POST, OPTIONS"
            Access-Control-Allow-Headers "Authorization, Content-Type, Accept"
            Vary "Origin"
          }
          @preflight {
            method OPTIONS
            header Origin https://webmail.${domain}
          }
          respond @preflight 204
          reverse_proxy 127.0.0.1:8080 {
            # Stalwart runs Http.useXForwarded and takes the client IP from
            # `Forwarded` (falling back to X-Forwarded-For) for auto-banning. SET
            # the true peer here: Caddy rewrites X-Forwarded-For itself, but
            # forwards a client-supplied `Forwarded` untouched — without this an
            # attacker picks the address they get banned as (or frames someone).
            header_up Forwarded "for={remote_host}"
          }
        '';
      };

      # office.<domain> — Collabora.
      "office.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-office.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          # Collabora (net.listen=loopback) binds ::1 (IPv6 loopback), NOT
          # 127.0.0.1 — proxy to [::1] or the reverse_proxy is refused (the
          # office 502). Plaintext on loopback; TLS by Caddy. Port 9983 = the
          # CODE AppImage's hardcoded AppRun port (not 9980).
          reverse_proxy [::1]:9983
        '';
      };

      # webmail.<domain> — Bulwark (system/mail/bulwark.nix). Public: its login IS
      # the mail account.
      "webmail.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-webmail.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          reverse_proxy 127.0.0.1:3100 {
            # Bulwark's next-intl builds an ABSOLUTE rewrite target from
            # X-Forwarded-Proto; forwarding "https" makes it proxy to
            # https://localhost:3100 (its own plaintext port) → EPROTO 500 on every
            # page. "http" is correct for this hop. COOKIE_SECURE is independent.
            header_up X-Forwarded-Proto http
          }
        '';
      };

      # vault.<domain> — Vaultwarden. PUBLIC: its own login gates it, and
      # Bitwarden extensions/phones must reach it from anywhere (basic_auth would
      # break non-browser clients). TLS is Caddy's own ACME over HTTP-01 on :80,
      # so the `vault` A record must be DNS-only / grey cloud.
      "vault.${domain}" = {
        logFormat = ''
          output file /var/log/caddy/access-vault.${domain}.log {
            roll_size 10MiB
            roll_keep 5
          }
        '';
        extraConfig = ''
          reverse_proxy 127.0.0.1:8222 {
            # Vaultwarden's IP_HEADER defaults to X-Real-IP, NOT X-Forwarded-For —
            # without this every client looks like 127.0.0.1 and rate limits go
            # GLOBAL (3 failed /admin logins locks the panel for everyone). Caddy
            # OVERWRITES X-Real-IP with the true peer (unlike X-Forwarded-For,
            # which it appends to and is spoofable).
            header_up X-Real-IP {remote_host}
          }

          # /admin is TAILNET-ONLY (can create users, read diagnostics); the public
          # vhost refuses it. Reach it over Tailscale — runbook in
          # system/web/vaultwarden. (`respond` is ordered before reverse_proxy.)
          @admin path /admin /admin/*
          respond @admin 403
        '';
      };

      # Deliberately NO admin.<domain> vhost: Stalwart's panel lives at
      # https://mail.<domain>/admin (gated by Stalwart's own login). A separate
      # vhost was bypassable by visiting mail.<domain>/admin AND broke the panel —
      # the browser reuses the cached Caddy Authorization header for the SPA's own
      # login, so Stalwart got the Caddy credentials and refused it.
    };
  };
}