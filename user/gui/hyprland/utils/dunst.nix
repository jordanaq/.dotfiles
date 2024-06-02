{ config, pkgs, ... }:

{
  services.dunst = {
    enable = true;
    iconTheme = {
      name = "papirus";
      package = pkgs.papirus-icon-theme;
      size = "32x32";
    };
  };
}
