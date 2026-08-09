{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    glow
    graphviz
    htop
    killall
    libfsm
    maliit-keyboard
    maliit-framework
    xclip
    xkill
  ];
}
