# Hermes Desktop client.
#
# Owns the desktop package and the XDG launcher entry.
# The Hermes gateway service and GBrain integration live in gbrain.nix.
{ inputs, lib, system, ... }:

let
  hermesDesktopPackage = inputs.hermes-agent.packages.${system}.desktop;
in {
  home.packages = [ hermesDesktopPackage ];

  xdg.desktopEntries."hermes-desktop" = {
    name = "Hermes Desktop";
    comment = "Hermes desktop client";
    exec = "${lib.getExe hermesDesktopPackage} %U";
    icon = "${hermesDesktopPackage}/share/hermes-desktop/dist/hermes.png";
    terminal = false;
    categories = [ "Development" "Utility" ];
  };
}
