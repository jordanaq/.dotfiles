# Stalwart — all-in-one mail + collaboration server (SMTP/IMAP/JMAP/POP3 and
# CalDAV/CardDAV/WebDAV). This IS the mail server; Bulwark (system/mail/bulwark.nix)
# is the web client that talks to it over JMAP.
#
# VERSION: 0.16.21 — prebuilt from the upstream GitHub release via the overlay
# in system/mail/stalwart/overlay.nix (nixpkgs still pins 0.15.5 as of 2026-09).
# 0.16 redesigned the management layer: the on-disk config is now a tiny JSON
# datastore descriptor, and EVERYTHING else (listeners, routing, domains,
# accounts…) lives in the datastore as JMAP objects. The module + provisioning
# below are vendored from open nixpkgs PR #552103 ("nixos/stalwart: update
# module for 0.16+", head 8b05caa6) — the stock 0.15.5 module cannot drive
# 0.16. DROP the vendored module + overlay once nixpkgs ships stalwart >= 0.16.
#
# OUTBOUND = SMTP2GO relay (MtaRoute 'smtp2go' below), for reliable delivery
#   from a young domain. SMTP2GO is MIME-agnostic, so end-to-end encrypted
#   (PGP/MIME) mail passes through — unlike Scaleway TEM, whose fixed MIME
#   allowlist forbids application/octet-stream and application/pgp-encrypted
#   (every encrypted message relayed through it bounced with a 501/5.6.0).
#   Direct-to-MX ('mx'), Scaleway ('scaleway') and SES ('ses') are retained as
#   defined-but-unused fallback routes. 'ses' is the planned relay: AWS SES,
#   out of sandbox since 2026-09-15, region eu-central-1 (Frankfurt); its DNS is
#   fully published and verified — MAIL FROM bounce.tsiru.pet (SPF include
#   amazonses.com + feedback MX) and all three Easy DKIM CNAMEs. Outbound port
#   25 is OPEN from this box (verified 2026-09-13), so direct delivery stays a
#   viable fallback.
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
    ./module/default.nix
    ./module/provision.nix
  ];
  disabledModules = [ "services/mail/stalwart.nix" ];

  # Prebuilt Stalwart 0.16 + CLI (nixpkgs still pins 0.15.5). Declared HERE, not
  # in configuration.nix, so the overlay that defines the package lives beside
  # the module that consumes it. Drop once nixpkgs ships stalwart >= 0.16.
  nixpkgs.overlays = [ (import ./overlay.nix) ];

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
    # (see the OUTBOUND note at the top — direct is now the intended path).
    #
    # ⚠ CHANGING ANYTHING BELOW NEEDS A RESTART TO TAKE EFFECT. Settings live in
    # the datastore, but the running server loads them into memory at startup —
    # it only reloads when a change is made in-process (e.g. via the WebUI).
    # `stalwart-cli apply` writes the datastore from a SEPARATE process, so the
    # live server never notices: the config looks applied (and the unit reports
    # success) while the old settings stay active. This has already bitten us
    # once with `Http.useXForwarded` + the Security auto-ban settings.
    #   After any change here:  sudo systemctl restart stalwart
    # (Automating this was considered and deliberately declined — see the
    # 2026-09-13 pentest remediation notes.)
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
        # Local domain stays local, everything else → the SMTP2GO relay
        # (MtaRoute 'smtp2go' below). History: 'scaleway' (TEM) → 'mx' (direct)
        # on 2026-09-13 → 'smtp2go' now. Same Expression form as 0.15's
        # if_then(rcpt_domain == 'tsiru.pet', 'local', 'smtp2go'). The then/else
        # values are expression literals, hence the inner quotes.
        MtaOutboundStrategy = {
          route = {
            match = [
              {
                "if" = "rcpt_domain == '${domain}'";
                "then" = "'local'";
              }
            ];
            "else" = "'smtp2go'";
          };
        };

        # Auto-banning — Stalwart's own fail2ban. This is the ONLY defence that
        # can see brute force against the mail protocols: IMAP/SMTP on
        # 993/465/587 connect straight to Stalwart and never touch Caddy, so the
        # fail2ban jail (which parses Caddy access logs) is structurally blind
        # to them. Failures are counted across JMAP, IMAP and SMTP and keyed on
        # BOTH the source IP and the login name, so a distributed
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
        # which is why the mail. vhost in system/web/caddy.nix SETS `Forwarded`:
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
            # NOTE: there is deliberately NO `sieve` (ManageSieve, 4190)
            # listener. Pentest F-11 flagged it as config↔reality drift: the
            # box listened and its own firewall allowed 4190, but Linode FILTERS
            # the port upstream, so no internet client could ever reach it
            # (verified 2026-09-13: open from the box to its own public IP,
            # filtered from outside, while 993 works). Nothing in this stack
            # speaks ManageSieve anyway — Bulwark and the WebUI manage Sieve
            # over JMAP (Stalwart exposes SieveScript as a JMAP object) — so the
            # listener only claimed a service that did not exist. Re-adding it
            # is these three lines again, but it will stay tailnet-only until
            # Linode stops filtering the port.
            http = {
              name = "http";
              protocol = "http";
              bind = [ "127.0.0.1:8080" ];
            };
          };
        };

        # Outbound routes.
        #
        # 'smtp2go' is the ACTIVE route: an authenticated SMTP relay
        # (mail.smtp2go.com:465, implicit TLS). Chosen for deliverability from a
        # young domain; MIME-agnostic so PGP/MIME passes. authUsername is a
        # plain string, committed directly — a login name is not a secret (0.16
        # removed %{file:…}% macros, so there is no file variant anyway); the
        # password is read from the file at runtime. SMTP2GO verifies the
        # sending domain via three CNAMEs (dkim / return-path / click-tracking)
        # and needs NO SPF include — its return-path CNAME covers SPF, so the
        # apex SPF is untouched.
        #
        # 'ses' is DORMANT (planned replacement for smtp2go): an authenticated
        # SMTP relay to AWS SES, region eu-central-1 (Frankfurt). Port 587 is
        # STARTTLS (not implicit), hence implicitTls = false. Address is this
        # account's unique SES SMTP host (from the SES SMTP credentials CSV).
        # Like 'scaleway', authUsername is deliberately NOT set here — 0.16 has
        # no file variant for a username, and the SES SMTP username is a
        # credential, so it stays out of this repo and is set once in the WebUI
        # (Settings › MTA › Outbound › Routes › ses → Username). Provisioning's
        # upsert preserves it across applies. The password is file-sourced at
        # runtime from /etc/secrets/ses.smtp-password.
        #
        # 'mx' (direct-to-MX) is DORMANT — retained as a fallback. It is
        # deliberately IPv4-only (ipLookupStrategy = v4Only): the box has a
        # global IPv6 (2600:3c03::2000:3bff:fe72:8527) with NO PTR and no AAAA
        # on mail.<domain>, so sending over v6 would fail FCrDNS and spam-fold.
        # To enable IPv6 later: set the IPv6 rDNS at Linode + add an AAAA for
        # mail.<domain> + an ip6: term in SPF, then switch to v4ThenV6.
        #
        # 'scaleway' (the TEM relay) is DORMANT too. Its secret is NOT in this
        # repo: authSecret reads the file path at runtime. The username
        # (Scaleway project ID) is kept out of the repo — set it once in the
        # WebUI (Settings › MTA › Outbound › Routes → scaleway → authUsername).
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
              # authUsername intentionally omitted — it is a credential, so it
              # is kept out of this repo and set once in the WebUI (see comment
              # above); provisioning's upsert preserves it.
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
  #   /etc/secrets/smtp2go.smtp-password   SMTP2GO SMTP-user password (root:stalwart 640)
  #   /etc/secrets/ses.smtp-password       AWS SES SMTP password (root:stalwart 640)
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
