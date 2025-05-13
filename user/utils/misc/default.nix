{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    killall
    htop
    maliit-keyboard
    maliit-framework
    xclip
    xorg.xkill
  ];
}
