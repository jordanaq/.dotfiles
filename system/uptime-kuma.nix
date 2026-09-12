# Uptime Kuma — self-hosted status/heartbeat monitor.
#
# PRIVATE by design: listens on loopback only and is NOT in Caddy. Reach it
# over the tailnet via `tailscale serve` (persistent across reboots):
#
#   sudo tailscale serve --bg --https=443 http://127.0.0.1:3001
#
#   -> https://tsiru-cloud.<tailnet>.ts.net  (valid ts.net cert, tailnet-only)
#
# First run: create the admin account at that URL (first-run setup screen).
{ config, lib, ... }:

{
  services.uptime-kuma = {
    enable = true;
    # Loopback only — the ONLY paths in are tailscale serve (above) or an SSH
    # tunnel: `ssh -L 3001:127.0.0.1:3001 tsiru.pet`.
    settings.HOST = "127.0.0.1";
    settings.PORT = "3001";
  };

  # No Caddy vhost: the earlier public `status.${domain}` vhost (basic-auth
  # gated) was removed 2026-09-12 in favour of tailnet-only access. If you
  # ever want a public status PAGE later, expose a separate read-only
  # status page — not this admin dashboard.
}
