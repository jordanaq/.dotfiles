{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
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
