# Tailscale client — private mesh access to tsiru-cloud FROM the desktop.
#
# This is the DESKTOP half. The box's half is system/tailscale.nix on the
# `server` branch (checked out at ~/Documents/Projects/cloud-server).
#
# Deliberately NOT an autoconnect: no authKeyFile, so tailscaled runs at boot
# but stays disconnected until you ask for the link. Toggle it from the tray
# (user/utils/tailscale-systray — `tailscale systray`), or by hand:
#
#   tailscale up      → 100.x route + MagicDNS names live
#   tailscale down    → private route gone; public tsiru.pet still up
#   tailscale status
#
# One-time interactive login (opens an auth URL in the browser):
#   sudo tailscale up
# Login state lives in /var/lib/tailscale, so every later `tailscale up`
# reconnects silently with no browser.
{ ... }:

{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none"; # plain client: no subnet router / exit node

    # Hand the socket to the user so the tray (and plain `tailscale up/down`)
    # needs NO sudo. Runs as root at boot (`tailscaled-set`), and is idempotent.
    extraSetFlags = [ "--operator=tsiru" ];
  };

  # Let tailnet peers reach this desktop too (future box → desktop access).
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Direct WireGuard transport (UDP), so peers connect DIRECT rather than
  # being relayed through DERP. Without it tailscale still works, just slower.
  networking.firewall.allowedUDPPorts = [ 41641 ];
}
