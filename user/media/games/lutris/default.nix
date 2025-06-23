{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gamescope
    vulkan-tools
    protontricks
    winetricks
    wineWowPackages.waylandFull
    # wineWow64Packages.waylandFull
  ];

  programs.lutris.enable = true;
}
