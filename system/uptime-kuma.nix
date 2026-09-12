# Uptime Kuma — self-hosted status/heartbeat monitor.
#
# Watches the public surface (site, notes, links, webmail, mail TLS ports,
# search, library) and can notify on downtime. Lightweight (~100-150 MB RSS),
# fits the 2 GB Linode fine.
#
# Exposure model: bound to loopback only and fronted by Caddy at
# status.<domain> behind the SAME basic-auth credential as search.<domain>
# (CADDY_AUTH_HASH from /etc/secrets/caddy.env — no new secrets file).
# Deliberately NOT tailscale-only: Kuma's push/heartbeat monitors and the
# notification setup work from anywhere, and the basic-auth gate matches the
# existing pattern. Reaching it privately via Tailscale also works.
#
# First run: create the admin account at https://status.<domain> (the instance
# is unusable until then; registration is only via that first-run setup screen).
{ config, domain, ... }:

{
  services.uptime-kuma = {
    enable = true;
    # Loopback only — Caddy is the only path in.
    settings.HOST = "127.0.0.1";
    settings.PORT = "3001";
  };

  services.caddy.virtualHosts."status.${domain}" = {
    logFormat = ''
      output file /var/log/caddy/access-status.${domain}.log {
        roll_size 10MiB
        roll_keep 5
      }
    '';
    extraConfig = ''
      basic_auth {
        tsiru {$CADDY_AUTH_HASH}
      }
      reverse_proxy 127.0.0.1:3001

      # Kuma uses WebSocket for its live status feed; Caddy proxies WS
      # automatically, nothing extra needed.
    '';
  };
}
