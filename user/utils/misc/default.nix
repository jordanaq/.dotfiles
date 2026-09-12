{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    glow
    killall
  ];
}
