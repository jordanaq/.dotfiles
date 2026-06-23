{ config, pkgs, ... }:

{
  programs.element-desktop = {
    enable = true;
  };

  home.packages = with pkgs; [
    discord
    revolt-desktop
    slack
    telegram-desktop
    zoom-us
  ];
}
