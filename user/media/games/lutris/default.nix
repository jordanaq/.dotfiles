{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gamescope
    vulkan-tools
    protontricks
    winetricks
    wineWow64Packages.waylandFull
    # wineWow64Packages.waylandFull
  ];

  programs.lutris.enable = true;
}
