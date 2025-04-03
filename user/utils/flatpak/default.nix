{ pkgs, ... }:

{
  home.packages = with pkgs; [
    flatpak
    gnome-software
  ];
}
    
