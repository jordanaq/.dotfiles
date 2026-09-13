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
          # #main = the Domain object key below; the Lua sorter orders the
          # plan so the domain upsert lands before this update. Required
          # field — without it apply fails with `defaultDomainId: required`.
          defaultDomainId = "#main";
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

        # Auto-banning — Stalwart's own fail2ban. This is the ONLY defence that
        # can see brute force against the mail protocols: IMAP/SMTP/Sieve on
        # 993/465/587 connect straight to Stalwart and never touch Caddy, so the
        # fail2ban jail (which parses Caddy access logs) is structurally blind
        # to them. Failures are counted across JMAP, IMAP, SMTP and ManageSieve
        # and keyed on BOTH the source IP and the login name, so a distributed
        # attack against a single account still trips it. Deliberately
        # conservative — 10 failures / 15 min -> 1 h ban — because the block
        # drops the connection and a false positive locks the owner out of their
        # own mail. Fields not named here keep their defaults (abuse/loiter/scan
        # rates, and scanBanPaths, which instantly bans exploit-path probes).
        Security = {
          authBanRate = {
            count = 10;
            period = 900000;
          };
          authBanPeriod = 3600000;
        };

        # Stalwart's HTTP listener is loopback-only behind Caddy. Without this,
        # Stalwart attributes EVERY proxied request to 127.0.0.1, so auto-ban
        # would count all failures against the proxy and eventually ban it —
        # locking out all webmail/JMAP access behind it (the failure mode the
        # upstream docs explicitly warn about). With `useXForwarded` Stalwart
        # reads the client IP from the `Forwarded` header, falling back to
        # X-Forwarded-For. Both are only trustworthy while Caddy controls them,
        # which is why the mail. vhost in system/caddy.nix SETS `Forwarded`:
        # Caddy overwrites X-Forwarded-For itself, but passes a client-supplied
        # `Forwarded` through untouched.
        Http = {
          useXForwarded = true;
        };
      };

      objects = {
        # The local domain. dnsManagement stays MANUAL — Spaceship is the DNS
        # authority, so records are published by hand. dkimManagement is
        # AUTOMATIC, RSA-only: Stalwart generates and rotates the key and signs
        # outbound; copy the record it reports (Settings › Domains › DKIM
        # Signatures) into Spaceship. Ed25519 is deliberately NOT enabled —
        # Proton and Gmail do not support ed25519-sha256 (RFC 8463) and log a
        # permerror for every message that carries one.
        Domain = {
          reconcile = false;
          match = [ "name" ];
          objects = {
            main = {
              name = domain;
              certificateManagement = { "@type" = "Manual"; };
              dkimManagement = {
                "@type" = "Automatic";
                algorithms = [ "Dkim1RsaSha256" ];
              };
              # dnsManagement is deliberately ABSENT. It is Automatic with a
              # Spaceship DnsServer (publishRecords = dkim + tlsa), configured
              # once in the datastore — the Spaceship API key is a plain string
              # with no file/env variant and cannot live in this public repo.
              # Upsert preserves fields it does not declare, so omitting it here
              # keeps the datastore value; declaring Manual would reset it and
              # DKIM would stop rotating. See the skill reference for the setup.
            };
          };
        };

        # TLS certificate, file-sourced from the security.acme output above.
        # 0.16 removed the %{file:…}% macros the 0.15 config used, so this File
        # PublicText/SecretText is their replacement. Stalwart picks the cert by
        # SAN, so nothing on the Domain needs to link it. matchOn is the SAN
        # set — stable across renewals, as is the file path.
        Certificate = {
          reconcile = false;
          match = [ "subjectAlternativeNames" ];
          objects = {
            mail = {
              certificate = {
                "@type" = "File";
                filePath = "${acmeDir}/fullchain.pem";
              };
              privateKey = {
                "@type" = "File";
                filePath = "${acmeDir}/key.pem";
              };
              subjectAlternativeNames = [ mailHost ];
            };
          };
        };

        # Listeners. The 0.16 protocol enum has no 'submission' variants:
        # SMTP listeners serve both MX and client submission on their ports
        # (587/465 are distinguished by the TLS setup / stage config).
        NetworkListener = {
          # Reconcile (not upsert) so the 0.16 auto-created defaults get purged:
          # https:[::]:443 collides with Caddy, pop3s:995 is unused (never
          # firewalled), and imaps:993 duplicates our imap below. Only the six
          # declared here survive.
          reconcile = true;
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
  # NOTE: /etc/secrets/scaleway.smtp-user is read by NOTHING — 0.16 removed the
  # %{file:…}% macros and authUsername is a plain string with no file variant.
  # Set it once in the WebUI (Settings › MTA › Outbound › Routes › scaleway →
  # Username); provisioning's upsert preserves it.
  # DKIM is now Stalwart's own (dkimManagement = Automatic), and DKIM rotation +
  # TLSA publishing are Automatic too via a Spaceship DnsServer object held in the
  # datastore — its API key is read from /etc/secrets/spaceship.env by a one-time
  # `stalwart-cli create DnsServer` and is never committed. publishRecords is
  # limited to dkim + tlsa, so MX/SPF/DMARC stay under manual control.
}
