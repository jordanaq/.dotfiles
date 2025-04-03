{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    discord
    premid
    revolt-desktop
    slack
    telegram-desktop
    zoom-us
  ];
}
