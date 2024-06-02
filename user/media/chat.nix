{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    discord
    revolt-desktop
    telegram-desktop
  ];
}
