# Stalwart — all-in-one mail server (SMTP/IMAP/JMAP/POP3, CalDAV/CardDAV/WebDAV);
# Bulwark (system/mail/bulwark.nix) is the web client talking to it over JMAP.
#
# VERSION 0.16.21, prebuilt from upstream via the overlay in
# system/mail/stalwart/overlay.nix (nixpkgs still pins 0.15.5). The module +
# provisioning below are vendored from nixpkgs PR #552103 — stock 0.15.5 cannot
# drive 0.16. Drop the vendored module + overlay once nixpkgs ships >= 0.16.
#
# OUTBOUND = AWS SES relay ('ses', MtaRoute below) since 2026-09-15 — MIME-agnostic,
# so PGP/MIME passes (Scaleway TEM bounced it with 501/5.6.0). 'smtp2go' and direct
# 'mx' are kept as dormant fallbacks. TLS: mail.<domain> cert via security.acme
# Spaceship DNS-01, shared with Caddy; Stalwart's HTTP listener is loopback-only.
{ config, lib, pkgs, domain, ... }:

let
  mailHost = "mail.${domain}";
  acmeDir = "/var/lib/acme/${mailHost}";
in
{
  # Vendored 0.16 module replaces nixpkgs' 0.15.5-era one (which emits TOML).
  imports = [
    ./module/default.nix
    ./module/provision.nix
  ];
  disabledModules = [ "services/mail/stalwart.nix" ];

  # Prebuilt 0.16 + CLI, declared here so the overlay lives beside its module.
  nixpkgs.overlays = [ (import ./overlay.nix) ];

  # --- TLS: one cert for the mail hostname via Spaceship DNS-01 (no :80/:443) ---
  # group = tls-mail, so Stalwart and Caddy (the JMAP vhost) both read the key.
  security.acme = {
    acceptTerms = true;
    defaults.email = "postmaster@${domain}";
    certs."${mailHost}" = {
      dnsProvider = "spaceship";
      # lego EnvironmentFile: SPACESHIP_API_KEY + SPACESHIP_API_SECRET (chmod 600).
      environmentFile = "/etc/secrets/spaceship.env";
      group = "tls-mail";
      reloadServices = [ "stalwart" "caddy" ];
    };
  };
  users.groups.tls-mail = { };
  # stateVersion "26.05" selects the modern (post-26.05) defaults — RocksDB
  # storage and the `stalwart` user — not the legacy SQLite / stalwart-mail layout.
  users.users.stalwart.extraGroups = [ "tls-mail" ];
  users.users.caddy.extraGroups = [ "tls-mail" ];

  # --- Stalwart ------------------------------------------------------------
  services.stalwart = {
    enable = true;
    stateVersion = "26.05";
    package = pkgs.stalwart;
    url = "https://${mailHost}";
    # Ports opened explicitly in configuration.nix, not via openFirewall.
    openFirewall = false;

    # 0.16 fallback administrator. The unit passes this PLAINTEXT password to
    # STALWART_RECOVERY_ADMIN verbatim (not 0.15's sha512 hash). Kept out of this
    # public repo in /etc/secrets/stalwart-admin-password (root:stalwart 640).
    admin = {
      enable = true;
      username = "admin";
      passwordFile = "/etc/secrets/stalwart-admin-password";
    };

    # Enable ONLY for the one-time 0.15→0.16 migration so the datastore migrates
    # and export.json can be applied; must otherwise stay false.
    recovery = {
      enable = false;
      port = 8080;
    };

    # 0.16 on-disk config describes ONLY the datastore (RocksDB); every other
    # setting is a JMAP object in the datastore, provisioned below.
    settings = {
      "@type" = "RocksDb";
      path = "/var/lib/stalwart/db";
    };

    # Declarative JMAP provisioning, applied idempotently at boot by
    # `stalwart-cli apply`. Migration does NOT convert listeners/routing, so
    # without these an upgrade would listen on nothing and deliver outbound
    # directly.
    #
    # ⚠ ANY CHANGE BELOW NEEDS `sudo systemctl restart stalwart` to take effect:
    # apply writes the datastore from a separate process, so the running server
    # only picks it up at startup (has bitten us with Http.useXForwarded).
    provision = {
      enable = true;
      url = "http://127.0.0.1:8080";

      singletons = {
        SystemSettings = {
          defaultHostname = mailHost;
          # #main = the Domain object below; required — without it apply fails
          # with `defaultDomainId: required`.
          defaultDomainId = "#main";
        };
        # Local domain stays local (domain-local), everything else → the 'ses'
        # relay. Expression literals, hence the inner quotes.
        MtaOutboundStrategy = {
          route = {
            match = [
              {
                "if" = "rcpt_domain == '${domain}'";
                "then" = "'local'";
              }
            ];
            "else" = "'ses'";
          };
        };

        # Stalwart's own auto-ban — the ONLY defence that sees brute force on the
        # mail protocols (IMAP/SMTP hit Stalwart directly, never Caddy, so the
        # fail2ban jail is blind to them). Keyed on IP AND login name.
        # Conservative on purpose (10 fails/15 min → 1 h ban): a false positive
        # locks the owner out of their own mail.
        Security = {
          authBanRate = {
            count = 10;
            period = 900000;
          };
          authBanPeriod = 3600000;
        };

        # Required behind a proxy: without it Stalwart sees every request as
        # 127.0.0.1, attributes ALL failures to the proxy, and eventually bans it,
        # locking out webmail/JMAP. Reads client IP from `Forwarded`
        # (falling back to X-Forwarded-For); only safe because the mail. vhost in
        # caddy.nix SETS `Forwarded` for the real peer (Caddy rewrites
        # X-Forwarded-For itself but passes a client-supplied `Forwarded` through
        # untouched).
        Http = {
          useXForwarded = true;
        };
      };

      objects = {
        # dnsManagement stays MANUAL — Spaceship is the DNS authority, records are
        # published by hand. dkimManagement is AUTOMATIC, RSA-only (Stalwart signs
        # outbound and rotates; copy its reported DKIM record into Spaceship).
        # Ed25519 deliberately OFF — Proton/Gmail don't support it (RFC 8463).
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
              # dnsManagement deliberately ABSENT: it's Automatic with a
              # Spaceship DnsServer, whose API key is a plain string with no
              # file/env variant and cannot live in this public repo. Upsert
              # preserves undeclared fields; omitting keeps the datastore value,
              # declaring Manual would reset it and stop DKIM rotation.
            };
          };
        };

        # Cert file-sourced from security.acme. 0.16 removed the %{file:…}% macros,
        # so File PublicText/SecretText replaces them. Stalwart picks the cert by
        # SAN, so nothing on Domain links it.
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

        # 0.16 has no 'submission' protocol enum — SMTP listeners serve both MX
        # and submission (TLS stage distinguishes them; 465/587 folding abandoned
        # — external submission is loopback-only via :587, see below).
        NetworkListener = {
          # Reconcile (not upsert) so 0.16's auto-created defaults are purged:
          # https:443 collides with Caddy, pop3s:995 is unused/never opened,
          # imaps:993 duplicates our old imap. Only the three declared survive.
          reconcile = true;
          match = [ "name" ];
          objects = {
            smtp = {
              name = "smtp";
              protocol = "smtp";
              bind = [ "0.0.0.0:25" ];
            };
            # SMTP submission, LOOPBACK-ONLY. The only authenticated submission
            # consumer is Vaultwarden (2FA/hint/admin mail), which connects to
            # 127.0.0.1:587. No internet client uses 465/587 (Bulwark is JMAP-only
            # over :443), so there is no public submission listener and no
            # allowedTCPPorts entry for it. Loopback needs no firewall hole.
            submission = {
              name = "submission";
              protocol = "smtp";
              bind = [ "127.0.0.1:587" ];
            };
            # Deliberately NO `sieve` (4190) listener: pentest F-11 flagged it as
            # config↔reality drift — Linode filters the port upstream, so no
            # internet client could reach it. Nothing here speaks ManageSieve
            # anyway (Bulwark/WebUI use JMAP SieveScript). Stay tailnet-only
            # until Linode unfilters the port.
            http = {
              name = "http";
              protocol = "http";
              bind = [ "127.0.0.1:8080" ];
            };
          };
        };

        # 'smtp2go' & 'mx': dormant fallbacks. 'mx' is deliberately IPv4-only
        # (ipLookupStrategy = v4Only) — the box's global IPv6 has no PTR and mail.<domain>
        # has no AAAA, so sending over v6 would fail FCrDNS and spam-fold.
        # 'ses': active, port 587 STARTTLS. Its authUsername is deliberately NOT
        # set here — it's a credential, so it stays out of this repo and is set
        # once in the WebUI; provisioning's upsert preserves it. Password is
        # file-sourced at runtime.
        MtaRoute = {
          reconcile = false;
          match = [ "name" ];
          objects = {
            smtp2go = {
              "@type" = "Relay";
              name = "smtp2go";
              address = "mail.smtp2go.com";
              port = 465;
              protocol = "smtp";
              implicitTls = true;
              authUsername = "tsiru.pet";
              authSecret = {
                "@type" = "File";
                filePath = "/etc/secrets/smtp2go.smtp-password";
              };
            };
            ses = {
              "@type" = "Relay";
              name = "ses";
              address = "faqamk3iehr7.eig6.mail-manager-smtp.amazonaws.com";
              port = 587;
              protocol = "smtp";
              implicitTls = false; # SES SMTP :587 is STARTTLS, not implicit
              authSecret = {
                "@type" = "File";
                filePath = "/etc/secrets/ses.smtp-password";
              };
            };
            mx = {
              "@type" = "Mx";
              name = "mx";
              ipLookupStrategy = "v4Only";
            };
          };
        };
      };
    };
  };

  # --- Secrets this module requires on the box (0600, made before switch) ------
  #   /etc/secrets/spaceship.env           SPACESHIP_API_KEY=... SPACESHIP_API_SECRET=...
  #   /etc/secrets/smtp2go.smtp-password   SMTP2GO SMTP password (root:stalwart 640)
  #   /etc/secrets/ses.smtp-password       AWS SES SMTP password (root:stalwart 640)
  #   /etc/secrets/stalwart-admin-password PLAINTEXT admin password (0.16)
  # DKIM rotation + TLSA publishing are Automatic via a Spaceship DnsServer held
  # in the datastore (API key from spaceship.env via one-time `stalwart-cli
  # create DnsServer`, never committed); publishRecords is dkim + tlsa only, so
  # MX/SPF/DMARC stay under manual control.
}