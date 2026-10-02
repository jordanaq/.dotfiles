{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    glow
    graphviz
    htop
    killall
    libfsm
    xclip
  ];
}
