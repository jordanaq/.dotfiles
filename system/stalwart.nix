# Stalwart — all-in-one mail + collaboration server (SMTP/IMAP/JMAP/POP3 and
# CalDAV/CardDAV/WebDAV). This IS the mail server; Bulwark (system/bulwark.nix)
# is the web client that talks to it over JMAP.
#
# VERSION: 0.16.21 — prebuilt from the upstream GitHub release via the overlay
# in system/stalwart-overlay.nix (nixpkgs still pins 0.15.5 as of 2026-09).
# 0.16 redesigned the management layer: the on-disk config is now a tiny JSON
# datastore descriptor, and EVERYTHING else (listeners, routing, domains,
# accounts…) lives in the datastore as JMAP objects. The module + provisioning
# below are vendored from open nixpkgs PR #552103 ("nixos/stalwart: update
# module for 0.16+", head 8b05caa6) — the stock 0.15.5 module cannot drive
# 0.16. DROP the vendored module + overlay once nixpkgs ships stalwart >= 0.16.
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
in
{
  # Replace nixpkgs' built-in 0.15.5-era module (it emits TOML config and has
  # no recovery/admin/provision options) with the vendored 0.16 module.
  imports = [
    ./stalwart-module/default.nix
    ./stalwart-module/provision.nix
  ];
  disabledModules = [ "services/mail/stalwart.nix" ];

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
    # Prebuilt 0.16.21 from the overlay.
    package = pkgs.stalwart;
    # Public base URL (advertised in OAuth/OIDC/JMAP well-known documents;
    # passed to the server as STALWART_PUBLIC_URL).
    url = "https://${mailHost}";
    # Ports are opened explicitly in configuration.nix (this branch's
    # convention), not via the module's openFirewall.
    openFirewall = false;

    # The 0.16 fallback administrator. NOTE: this is the PLAINTEXT password —
    # not the sha512 hash 0.15 used; the unit feeds it to
    # STALWART_RECOVERY_ADMIN verbatim. Kept out of this public repo, in
    # /etc/secrets/stalwart-admin-password (readable by the stalwart user,
    # e.g. root:stalwart 640).
    admin = {
      enable = true;
      username = "admin";
      passwordFile = "/etc/secrets/stalwart-admin-password";
    };

    # Recovery mode exists ONLY for the 0.15→0.16 migration (see the runbook
    # in the nixos-server-deployment skill): set enable = true for the first
    # 0.16 boot so the datastore migrates and export.json can be applied, then
    # flip it back off. Normally it must stay false.
    recovery = {
      enable = false;
      port = 8080;
    };

    # 0.16 on-disk config: describes ONLY the datastore (RocksDB, same layout
    # the 0.15 install used — recovery mode migrates it in place). Every other
    # setting is a JMAP object in the datastore, provisioned below.
    settings = {
      "@type" = "RocksDb";
      path = "/var/lib/stalwart/db";
    };

    # Declarative JMAP-object provisioning: applied idempotently at boot by
    # `stalwart-cli apply` (stalwart-provision.service). The migration script
    # does NOT convert listeners or routing, so without these the upgraded
    # server would listen on nothing and deliver outbound mail directly
    # (which Linode blocks).
    provision = {
      enable = true;
      url = "http://127.0.0.1:8080";

      singletons = {
        SystemSettings = {
          defaultHostname = mailHost;
        };
        # Local domain stays local, everything else → the Scaleway relay
        # (MtaRoute 'scaleway' below). Same logic as 0.15's
        # if_then(rcpt_domain == 'tsiru.pet', 'local', 'scaleway'), now in the
        # native Expression object form. The then/else values are expression
        # literals, hence the inner quotes.
        MtaOutboundStrategy = {
          route = {
            match = [
              {
                "if" = "rcpt_domain == '${domain}'";
                "then" = "'local'";
              }
            ];
            "else" = "'scaleway'";
          };
        };
      };

      objects = {
        # The local domain. certificate/dkim/dns management are all MANUAL:
        # the TLS cert is pasted in the WebUI (external security.acme files,
        # no repo secrets) and DKIM is Scaleway's (external, DNS-side).
        Domain = {
          reconcile = false;
          match = [ "name" ];
          objects = {
            main = {
              name = domain;
              certificateManagement = { "@type" = "Manual"; };
              dkimManagement = { "@type" = "Manual"; };
              dnsManagement = { "@type" = "Manual"; };
            };
          };
        };

        # Listeners. The 0.16 protocol enum has no 'submission' variants:
        # SMTP listeners serve both MX and client submission on their ports
        # (587/465 are distinguished by the TLS setup / stage config).
        NetworkListener = {
          reconcile = false;
          match = [ "name" ];
          objects = {
            smtp = {
              name = "smtp";
              protocol = "smtp";
              bind = [ "0.0.0.0:25" ];
            };
            submission = {
              name = "submission";
              protocol = "smtp";
              bind = [ "0.0.0.0:587" ];
            };
            submissions = {
              name = "submissions";
              protocol = "smtp";
              bind = [ "0.0.0.0:465" ];
              tlsImplicit = true;
            };
            imap = {
              name = "imap";
              protocol = "imap";
              bind = [ "0.0.0.0:993" ];
              tlsImplicit = true;
            };
            sieve = {
              name = "sieve";
              protocol = "manageSieve";
              bind = [ "0.0.0.0:4190" ];
            };
            http = {
              name = "http";
              protocol = "http";
              bind = [ "127.0.0.1:8080" ];
            };
          };
        };

        # Scaleway smarthost. The secret is NOT in this repo: authSecret reads
        # the file path at runtime (the same file the 0.15 config used). The
        # username (Scaleway project ID) is also kept out of the repo — set it
        # once in the WebUI after the migration (Settings › MTA › Outbound ›
        # Routes → scaleway → authUsername).
        MtaRoute = {
          reconcile = false;
          match = [ "name" ];
          objects = {
            scaleway = {
              "@type" = "Relay";
              name = "scaleway";
              address = "smtp.tem.scaleway.com";
              port = 2465;
              protocol = "smtp";
              implicitTls = true;
              authSecret = {
                "@type" = "File";
                filePath = "/etc/secrets/scaleway.smtp-password";
              };
            };
          };
        };
      };
    };
  };

  # --- Secrets this module requires on the box (0600, created before switch) --
  #   /etc/secrets/spaceship.env           SPACESHIP_API_KEY=... / SPACESHIP_API_SECRET=...
  #   /etc/secrets/scaleway.smtp-user      Scaleway SMTP username (from the TEM panel)
  #   /etc/secrets/scaleway.smtp-password  Scaleway API secret key
  #   /etc/secrets/stalwart-admin-password PLAINTEXT admin password (0.16; the
  #                                         0.15 sha512 hash file is obsolete)
  # DKIM is signed by Scaleway (add the records it shows you), so Stalwart does
  # not hold a DKIM key here.
}
