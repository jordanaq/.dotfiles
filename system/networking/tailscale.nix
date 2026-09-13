# Tailscale — private mesh access to the box, no extra open ports.
#
# This gives the desktop (and phone) a direct private IP into tsiru-cloud for
# admin work, without exposing anything new to the public internet. Tailscale
# speaks WireGuard over UDP 41641 (opened below so peer connections are DIRECT
# rather than relayed through DERP); if the firewall blocks it, traffic still
# works via Tailscale's relays, just slower.
#
# One-time login (interactive, on the box — opens an auth URL):
#   sudo tailscale up
# Then `tailscale ip -4` prints the node's 100.x.y.z address.
#
# Nothing here depends on Tailscale being up: it is purely additive access.
{ ... }:

{
  services.tailscale = {
    enable = true;
    # Keys don't expire — a personal tailnet node shouldn't need re-auth
    # every ~6 months.
    useRoutingFeatures = "none"; # client only: no subnet router / exit node
  };

  # Direct WireGuard transport (UDP). TCP-only firewall otherwise unchanged.
  networking.firewall.allowedUDPPorts = [ 41641 ];
  # Trust the tailscale interface enough for the agent to route to it.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
