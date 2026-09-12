# Vaultwarden — self-hosted, Bitwarden-compatible password manager, served at
# vault.<domain>. Caddy terminates TLS and proxies (system/caddy.nix).
#
# NixOS ships a FIRST-CLASS module for this (services.vaultwarden), so there is
# NO Docker, NO compose, and NO bespoke packaging here — unlike LinkStack, which
# had to be hand-packaged. The module gives us the SQLite backend, a hardened
# systemd unit (ProtectSystem=strict, PrivateTmp, syscall filtering, a 0700
# StateDirectory), a loopback-bound listener, and a built-in backup
# service+timer (see the `backupDir` note at the bottom).
#
# The web vault is PUBLIC: Vaultwarden's own login is the only gate, because
# Bitwarden browser extensions and phone apps must reach it from anywhere. (A
# Caddy basic_auth layer would break every non-browser client, exactly as it
# would break OPDS on the calibre vhost.) TLS comes from Caddy's own ACME over
# HTTP-01 on :80 — so the `vault` DNS A record must be DNS-ONLY (grey cloud).
#
# Secrets (NOT in this public repo):
#   /etc/secrets/vaultwarden.env   →   ADMIN_TOKEN=<long random>
#     Generate + create (before `nixos-rebuild switch`):
#       sudo install -m 600 /dev/null /etc/secrets/vaultwarden.env
#       printf 'ADMIN_TOKEN=%s\n' "$(openssl rand -base64 48)" | sudo tee /etc/secrets/vaultwarden.env
#     The admin panel is then https://vault.<domain>/admin (paste the token).
#
# Bootstrap — registration is CLOSED, so there is no self-signup:
#   1. Open https://vault.<domain>/admin and enter ADMIN_TOKEN.
#   2. Either use the admin panel's "Invite" (the email is delivered through the
#      local Stalwart below), or temporarily set SIGNUPS_ALLOWED = true, create
#      your account, then set it straight back to false.
{ config, domain, pkgs, ... }:

{
  services.vaultwarden = {
    enable = true;

    # SQLite — the right backend for a personal vault: one file, trivial to
    # dump. (Note the module asserts backupDir requires sqlite, so keeping this
    # backend is also what keeps the built-in backup path available.)
    dbBackend = "sqlite";

    # Extra env file: the ADMIN_TOKEN lives here, never in the world-readable
    # Nix store. systemd reads it as root before dropping to the vaultwarden
    # user.
    environmentFile = "/etc/secrets/vaultwarden.env";

    config = {
      # Public URL clients and the web vault use; also the base for links in
      # the emails Vaultwarden sends.
      DOMAIN = "https://vault.${domain}";

      # Bind IPv4 loopback. The module DEFAULT here is "::1" (IPv6 loopback),
      # while Caddy proxies to 127.0.0.1:8222 — so the default would refuse
      # every request. This must stay 127.0.0.1.
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";

      # Registration is CLOSED. The only way in is the initial account created
      # from the admin panel (or a temporary SIGNUPS_ALLOWED window); later
      # additions are admin-initiated invitations only. Never open signups on a
      # public vhost.
      SIGNUPS_ALLOWED = false;

      # --- Email: relay through the local Stalwart (system/stalwart.nix) -----
      # Used for 2FA-by-email, password hints, and admin invitations.
      # Stalwart listens on :25 and its outbound strategy routes every
      # non-local recipient through the Scaleway relay — so this box never has
      # to reach Linode's blocked outbound SMTP ports.
      SMTP_HOST = "127.0.0.1";
      SMTP_PORT = 25;
      SMTP_SECURITY = "off";      # loopback hop; Stalwart needs no TLS/auth from 127.0.0.1
      SMTP_FROM = "vault@${domain}";
      SMTP_FROM_NAME = "Tsiru's Vaultwarden";

      # NOTE: no USE_SENDMAIL — using SMTP keeps the module's strict systemd
      # sandbox (USE_SENDMAIL=true would relax PrivateUsers/NoNewPrivileges).
    };

    # Backups are deliberately NOT enabled yet. See the Discord reminder job
    # "Remind: Vaultwarden has NO backup". To turn the built-in nightly dump on,
    # uncomment (the module then adds backup-vaultwarden.service + a 23:00
    # timer that runs `sqlite3 .backup` + copies attachments):
    #   backupDir = "/var/backup/vaultwarden";
  };
}
