# Stalwart — all-in-one mail + collaboration server (SMTP/IMAP/JMAP/POP3 and
# CalDAV/CardDAV/WebDAV). This IS the mail server; Bulwark (system/bulwark.nix)
# is the web client that talks to it over JMAP.
#
# OUTBOUND = RELAY, not direct-to-MX. Mail is handed to Scaleway Transactional
#   Email (EU-hosted) instead of being delivered directly, so this box never
#   needs Linode's blocked outbound SMTP ports (25/465/587). Scaleway is reached
#   on port 2465 (implicit TLS), which Linode does NOT block. This is why there
#   is no port-25 support ticket and no IP-reputation warm-up anywhere here.
#
# TLS: the certificate for mail.<domain> is issued by security.acme using the
#   Spaceship DNS-01 provider (lego, which security.acme drives, speaks the
#   Spaceship API) and is shared with Caddy, which fronts the JMAP/CalDAV vhost
#   on :443. DNS-01 means no ACME challenge traffic on :80/:443 at all.
#
# HTTP listener binds loopback only — Caddy terminates TLS and proxies.
{ config, lib, pkgs, domain, ... }:

let
  mailHost = "mail.${domain}";
  acmeDir = "/var/lib/acme/${mailHost}";

  # Credentials the relay needs, stored on the box (never in this public repo).
  scalewayUserFile = "/etc/secrets/scaleway.smtp-user";
  scalewayPassFile = "/etc/secrets/scaleway.smtp-password";
in
{
  # --- TLS: one certificate for the mail hostname, via Spaceship DNS-01 -----
  # No ports 80/443 involvement (DNS-01), so it does not collide with Caddy.
  # group = tls-mail, so both Stalwart and Caddy (the JMAP vhost) can read the
  # key; both are added to that group below.
  security.acme = {
    acceptTerms = true;
    defaults.email = "postmaster@${domain}";
    certs."${mailHost}" = {
      dnsProvider = "spaceship";
      # EnvironmentFile for lego, holding SPACESHIP_API_KEY and
      # SPACESHIP_API_SECRET (chmod 600).
      environmentFile = "/etc/secrets/spaceship.env";
      group = "tls-mail";
      reloadServices = [ "stalwart" "caddy" ];
    };
  };
  users.groups.tls-mail = { };
  # Stalwart's user/group. stateVersion "26.05" selects the modern (post-26.05)
  # defaults — RocksDB storage and the `stalwart` user — rather than the legacy
  # SQLite / `stalwart-mail` layout, which is what a fresh install wants.
  users.users.stalwart.extraGroups = [ "tls-mail" ];
  users.users.caddy.extraGroups = [ "tls-mail" ];

  # --- Stalwart ------------------------------------------------------------
  services.stalwart = {
    enable = true;
    # Fresh install on a 25.05 host, but we want the current module defaults
    # (RocksDB + `stalwart` user). See the comment above.
    stateVersion = "26.05";
    # Ports are opened explicitly in configuration.nix (this branch's
    # convention), not via the module's openFirewall.
    openFirewall = false;

    settings = {
      server.hostname = mailHost;

      certificate."mail" = {
        cert = "%{file:${acmeDir}/fullchain.pem}%";
        private-key = "%{file:${acmeDir}/key.pem}%";
      };
      server.tls = {
        certificate = "mail";
        enable = true;
        implicit = false;
      };

      server.listener = {
        # 25  — MTA-to-MTA inbound (mail from other servers)
        smtp = {
          protocol = "smtp";
          bind = [ "0.0.0.0:25" ];
        };
        # 587 — client submission, STARTTLS
        submission = {
          protocol = "smtp";
          bind = [ "0.0.0.0:587" ];
        };
        # 465 — client submission, implicit TLS
        submissions = {
          protocol = "smtp";
          bind = [ "0.0.0.0:465" ];
          tls-implicit = true;
        };
        # 993 — IMAPS
        imap = {
          protocol = "imap";
          bind = [ "0.0.0.0:993" ];
          tls-implicit = true;
        };
        # 4190 — ManageSieve (Bulwark's filter UI + clients)
        sieve = {
          protocol = "manageSieve";
          bind = [ "0.0.0.0:4190" ];
        };
        # JMAP + CalDAV/CardDAV + the webadmin panel. Loopback only; Caddy
        # fronts mail.<domain> / admin.<domain> and terminates TLS.
        http = {
          protocol = "http";
          bind = [ "127.0.0.1:8080" ];
        };
      };

      # Local mail stays local; everything else goes out through the relay.
      queue.strategy.route = "if is_local_domain(rcpt_domain) { 'local' } else { 'scaleway' }";

      # Scaleway Transactional Email smarthost.
      # 2465 = implicit TLS; chosen over 587/465 precisely because Linode
      # blocks those outbound ports on this account.
      route."scaleway" = {
        type = "relay";
        address = "smtp.tem.scaleway.com";
        port = 2465;
        implicit-tls = true;
        auth-username = "%{file:${scalewayUserFile}}%";
        auth-secret = "%{file:${scalewayPassFile}}%";
      };
    };
  };

  # --- Secrets this module requires on the box (0600, created before switch) --
  #   /etc/secrets/spaceship.env           SPACESHIP_API_KEY=... / SPACESHIP_API_SECRET=...
  #   /etc/secrets/scaleway.smtp-user      Scaleway SMTP username (from the TEM panel)
  #   /etc/secrets/scaleway.smtp-password  Scaleway API secret key
  # DKIM is signed by Scaleway (add the records it shows you), so Stalwart does
  # not hold a DKIM key here.
}
