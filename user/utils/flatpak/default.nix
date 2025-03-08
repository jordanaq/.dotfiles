{ pkgs, ... }:

{
  home.packages = with pkgs; [
    flatpak
    gnome.gnome-software
  ];
}
    
