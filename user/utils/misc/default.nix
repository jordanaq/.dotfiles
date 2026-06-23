{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    graphviz
    htop
    killall
    maliit-keyboard
    maliit-framework
    xclip
    xkill
  ];
}
