# Vaultwarden — self-hosted Bitwarden-compatible password manager at
# vault.<domain>; Caddy terminates TLS and proxies (system/web/caddy.nix).
# NixOS module services.vaultwarden: SQLite backend, hardened systemd unit,
# loopback listener, built-in backup service+timer (see `backupDir` at bottom).
# Web vault is PUBLIC (extensions/phone apps must reach it from anywhere), so
# DNS `vault` record must be DNS-ONLY (grey cloud) — TLS via Caddy ACME :80.
#
# Secrets (NOT in this public repo): /etc/secrets/vaultwarden.env, chmod 600,
# holding ADMIN_TOKEN, SMTP_USERNAME=vault@<domain>, SMTP_PASSWORD. Create
# before `nixos-rebuild switch`:
#   sudo install -m 600 /dev/null /etc/secrets/vaultwarden.env
#   printf 'ADMIN_TOKEN=%s\n' "$(openssl rand -base64 48)" | sudo tee /etc/secrets/vaultwarden.env
#   printf 'SMTP_USERNAME=vault@<domain>\nSMTP_PASSWORD=<pw>\n' | sudo tee -a /etc/secrets/vaultwarden.env
# Admin panel: https://vault.<domain>/admin (paste token).
# ⚠ systemd reads EnvironmentFile only at service start — after editing, MUST
# `sudo systemctl restart vaultwarden` or the change is ignored.
#
# Registration is CLOSED; admin panel is TAILNET-ONLY (vhost blocks /admin, see
# caddy.nix). Reach it via one-time serve on the box:
#   sudo tailscale serve --bg --https=10000 http://127.0.0.1:8222
#   -> https://tsiru-cloud.<tailnet>.ts.net:10000/admin
# ⚠ Use 10000: 8443 is Uptime Kuma; --https=443 makes tailscaled bind the
# tailnet addr on :443, colliding with Caddy's wildcard bind and taking EVERY
# public vhost down (see system/monitoring/uptime-kuma.nix).
{ config, domain, pkgs, ... }:

{
  services.vaultwarden = {
    enable = true;

    # SQLite — right backend for a personal vault; module asserts backupDir
    # requires sqlite, so this keeps the built-in backup path available.
    dbBackend = "sqlite";

    # ADMIN_TOKEN lives here, never in the world-readable Nix store; read as
    # root before dropping to the vaultwarden user.
    environmentFile = "/etc/secrets/vaultwarden.env";

    config = {
      # Public URL + base for links in Vaultwarden-sent emails.
      DOMAIN = "https://vault.${domain}";

      # Module default here is "::1" (IPv6) while Caddy proxies 127.0.0.1:8222 —
      # default would refuse every request. Must stay 127.0.0.1.
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";

      # Registration is CLOSED — single account; re-open only temporarily.
      SIGNUPS_ALLOWED = false;

      # --- Hardening (2026-09-12) --------------------------------------------
      # Single account: no self-signup AND no admin invitations (re-open
      # temporarily if a second user is ever needed).
      INVITATIONS_ALLOWED = false;
      # Password hints are EMAILED to anyone who requests one for a known
      # address — disclosure for zero benefit.
      PASSWORD_HINTS_ALLOWED = false;
      # Single-user vault: no Send (public file-sharing surface) and no
      # emergency access (meaningless with one account).
      SENDS_ALLOWED = false;
      EMERGENCY_ACCESS_ALLOWED = false;
      # Icon downloads stay ENABLED (favicons from saved sites, proxied here);
      # set DISABLE_ICON_DOWNLOAD=true for privacy at the cost of favicons.

      # --- Email: authenticated submission to local Stalwart -----------------
      # Used for 2FA-by-email, password hints, admin invitations. Stalwart
      # relays non-local recipients out via SMTP2GO, so no open outbound SMTP.
      # Authenticated on :587 (STARTTLS), NOT plaintext :25: unauthenticated
      # loopback has no aligned SPF/DKIM so Stalwart's spam filter scored it and
      # filed the advisory into Junk. :587 advertises PLAIN/LOGIN only AFTER the
      # TLS handshake (pre-TLS it offers OAuth only, which Vaultwarden can't use).
      SMTP_HOST = "127.0.0.1";
      SMTP_PORT = 587;
      SMTP_SECURITY = "starttls";
      # Loopback hop: Stalwart's cert is for mail.<domain>, never 127.0.0.1, so
      # hostname can't match. Relax only the NAME, keep full CHAIN — no MITM
      # surface on loopback.
      SMTP_ACCEPT_INVALID_HOSTNAMES = true;
      SMTP_FROM = "vault@${domain}";
      SMTP_FROM_NAME = "Tsiru's Vaultwarden";
      # EHLO name REQUIRED FQDN — otherwise bare hostname "tsiru-cloud" is
      # rejected by Stalwart 0.16 `550 5.5.0 Invalid EHLO domain`. Verified:
      # localhost/tsiru-cloud -> 550, vault.${domain} -> 250.
      HELO_NAME = "vault.${domain}";

      # No USE_SENDMAIL: using SMTP keeps the module's strict systemd sandbox.
    };

    # Backups NOT enabled yet (see Discord reminder "Remind: Vaultwarden has NO
    # backup"). To enable, uncomment — adds backup-vaultwarden.service + 23:00
    # timer running `sqlite3 .backup` + copying attachments:
    #   backupDir = "/var/backup/vaultwarden";
  };
}