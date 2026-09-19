# Uptime Kuma — self-hosted status/heartbeat monitor; PRIVATE: loopback-only,
# NOT in Caddy. Reach over the tailnet (persistent across reboots):
#   sudo tailscale serve --bg --https=8443 http://127.0.0.1:3001
#   -> https://tsiru-cloud.<tailnet>.ts.net:8443  (ts.net cert, tailnet-only)
# ⚠️ Do NOT use --https=443: Tailscale binds the tailnet addr on :443, which
# collides with Caddy's :443 WILDCARD -> "bind: address already in use", every
# public site down. Use 8443 (or 10000); the URL just carries the port.
# First run: create the admin account at that URL.
{ config, lib, ... }:

{
  services.uptime-kuma = {
    enable = true;
    # Loopback only — in via `tailscale serve` (above) or
    # `ssh -L 3001:127.0.0.1:3001 tsiru.pet`.
    settings.HOST = "127.0.0.1";
    settings.PORT = "3001";
  };

  # No Caddy vhost: public status.${domain} (basic-auth gated) removed 2026-09-12
  # in favour of tailnet-only. If a public status is ever wanted, expose a
  # separate read-only status page — not this admin dashboard.
}