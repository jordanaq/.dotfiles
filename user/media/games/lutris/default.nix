{ pkgs, ... }:

{
  pkgs = with pkgs [
    bottles
    lutris
    vulkan-tools
    winetricks
    wineWowPackages.stable
  ];
}
