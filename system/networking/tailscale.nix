# Tailscale — private mesh access to the box; no extra public ports.
# UDP 41641 opened so peers connect DIRECT (WireGuard); if blocked, traffic
# rides DERP relays, slower. Purely additive — nothing depends on it being up.
# One-time interactive login on the box: `sudo tailscale up`, then
# `tailscale ip -4` prints the 100.x.y.z node address.
{ ... }:

{
  services.tailscale = {
    enable = true;
    # Keys don't expire — no re-auth every ~6 months.
    useRoutingFeatures = "none"; # client only: no subnet router / exit node
  };

  # Direct WireGuard transport (UDP); TCP-only firewall otherwise unchanged.
  networking.firewall.allowedUDPPorts = [ 41641 ];
  # Trust tailscale0 so the agent can route to it.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}