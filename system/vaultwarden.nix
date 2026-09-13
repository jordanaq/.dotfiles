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
# The web vault is re-skinned to Catppuccin Macchiato (pink accent) — see
# system/vaultwarden-catppuccin-macchiato.scss and the tmpfiles rules at the end.
#
# Secrets (NOT in this public repo):
#   /etc/secrets/vaultwarden.env   →   ADMIN_TOKEN=<long random>
#                                      SMTP_USERNAME=vault@<domain>
#                                      SMTP_PASSWORD=<that mailbox's password>
#     Generate + create (before `nixos-rebuild switch`):
#       sudo install -m 600 /dev/null /etc/secrets/vaultwarden.env
#       printf 'ADMIN_TOKEN=%s\n' "$(openssl rand -base64 48)" | sudo tee /etc/secrets/vaultwarden.env
#       printf 'SMTP_USERNAME=vault@<domain>\nSMTP_PASSWORD=<pw>\n' | sudo tee -a /etc/secrets/vaultwarden.env
#     The admin panel is then https://vault.<domain>/admin (paste the token).
#     ⚠ systemd reads EnvironmentFile ONLY at service start — after editing this
#     file you MUST `sudo systemctl restart vaultwarden` or the change is ignored.
#
# Bootstrap — registration is CLOSED and invitations are now OFF (the account
# was created 2026-09-12), so there is no way to add a user without temporarily
# re-enabling INVITATIONS_ALLOWED (or SIGNUPS_ALLOWED) and rebuilding.
# The admin panel itself is TAILNET-ONLY — the public vhost blocks /admin (see
# system/caddy.nix). Reach it by serving the app on the tailnet, one-time on the
# box:
#   sudo tailscale serve --bg --https=10000 http://127.0.0.1:8222
#   ->  https://tsiru-cloud.<tailnet>.ts.net:10000/admin
# ⚠ Use 10000. 8443 is Uptime Kuma, and --https=443 makes tailscaled bind the
#   tailnet address on :443, which collides with Caddy's wildcard bind and takes
#   EVERY public vhost down (see system/uptime-kuma.nix).
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

      # --- Hardening (2026-09-12) --------------------------------------------
      # The single account now exists, so close user creation ENTIRELY — no
      # self-signup (above) AND no admin invitations. Re-open temporarily if a
      # second user is ever needed.
      INVITATIONS_ALLOWED = false;
      # Password hints are EMAILED to anyone who requests one for a known
      # address — information disclosure for zero benefit. Off.
      PASSWORD_HINTS_ALLOWED = false;
      # Single-user vault: no Send (public file-sharing surface) and no
      # emergency access (meaningless with one account).
      SENDS_ALLOWED = false;
      EMERGENCY_ACCESS_ALLOWED = false;
      # NOTE: icon downloads deliberately stay ENABLED (favicons come from the
      # sites you save, proxied by this server). Flip DISABLE_ICON_DOWNLOAD to
      # true for privacy at the cost of losing favicons.

      # --- Email: authenticated submission to the local Stalwart --------------
      # Used for 2FA-by-email, password hints, and admin invitations. Stalwart
      # routes non-local recipients out via the Scaleway relay, so this box
      # never needs Linode's blocked outbound SMTP ports.
      #
      # AUTHENTICATED on :587 (STARTTLS), not plaintext :25: an unauthenticated
      # loopback submission has no aligned SPF/DKIM, so Stalwart's spam filter
      # scored it and filed the admin invite into Junk. Authenticating as a real
      # local account removes that penalty. NOTE :587 advertises PLAIN/LOGIN only
      # AFTER the TLS handshake — verified by probe (pre-TLS it offers OAuth
      # mechanisms only, which Vaultwarden cannot use).
      SMTP_HOST = "127.0.0.1";
      SMTP_PORT = 587;
      SMTP_SECURITY = "starttls";
      # Loopback hop: Stalwart's cert is issued for mail.<domain>, not for
      # 127.0.0.1, so the hostname can never match. Keep full CHAIN validation
      # and relax only the NAME — there is no MITM surface on loopback.
      SMTP_ACCEPT_INVALID_HOSTNAMES = true;
      SMTP_FROM = "vault@${domain}";
      SMTP_FROM_NAME = "Tsiru's Vaultwarden";

      # EHLO name. REQUIRED — Vaultwarden otherwise sends the bare hostname
      # ("tsiru-cloud"), and Stalwart 0.16 rejects a dotless EHLO domain with
      # `550 5.5.0 Invalid EHLO domain`, failing every invite/notification.
      # Must be an FQDN. Verified: EHLO localhost/tsiru-cloud -> 550,
      # EHLO vault.${domain} -> 250.
      HELO_NAME = "vault.${domain}";

      # NOTE: no USE_SENDMAIL — using SMTP keeps the module's strict systemd
      # sandbox (USE_SENDMAIL=true would relax PrivateUsers/NoNewPrivileges).

      # --- Theme: Catppuccin Macchiato ---------------------------------------
      # Where Vaultwarden looks for `scss/user.vaultwarden.scss.hbs`. The module
      # default is already DATA_FOLDER/templates, but we set it explicitly so the
      # contract is visible next to the tmpfiles rules that install the file.
      TEMPLATES_FOLDER = "/var/lib/vaultwarden/templates";
    };

    # Backups are deliberately NOT enabled yet. See the Discord reminder job
    # "Remind: Vaultwarden has NO backup". To turn the built-in nightly dump on,
    # uncomment (the module then adds backup-vaultwarden.service + a 23:00
    # timer that runs `sqlite3 .backup` + copies attachments):
    #   backupDir = "/var/backup/vaultwarden";
  };

  # --- Catppuccin Macchiato re-skin -----------------------------------------
  # Vaultwarden compiles templates/scss/user.vaultwarden.scss.hbs and serves the
  # result as /css/vaultwarden.css, which the web vault loads AFTER its own
  # stylesheet (styles.<hash>.css) — so the whole UI can be re-themed with no CSP
  # change, no HTML patching, and no custom web-vault build.
  #
  # `L+` symlinks to the file in the Nix store (the store copy is world-readable;
  # the service only needs to read it, not write it). A symlink rather than a
  # copy is deliberate: tmpfiles `C` leaves an existing destination alone, so
  # palette edits would never reach the box — `L+` replaces the link on every
  # rebuild.
  #
  # The directories are 0755 and root-owned: they hold nothing but a public
  # stylesheet, and deliberately NOT naming the vaultwarden user here keeps these
  # rules working regardless of whether tmpfiles runs before that user exists.
  # (Ownership of a symlink is irrelevant anyway — the target's permissions
  # govern reads.)
  systemd.tmpfiles.rules = [
    "d /var/lib/vaultwarden/templates 0755 root root -"
    "d /var/lib/vaultwarden/templates/scss 0755 root root -"
    "L+ /var/lib/vaultwarden/templates/scss/user.vaultwarden.scss.hbs - - - - ${./vaultwarden-catppuccin-macchiato.scss}"
  ];
}
