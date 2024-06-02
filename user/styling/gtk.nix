{ config, pkgs, ... }:

{
  home.pointerCursor = {
    gtk.enable = true;
    name = "Catppuccin Macchiato";
    package = pkgs.catppuccin-cursors.macchiatoPink;
    size = 16;
  };

  gtk = {
    enable = true;

    catppuccin = {
      size = "standard";
      tweaks = [
        "normal"
      ];
    };

    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus";
    };

    font = {
      name = "Inter";
      size = 11;
    };
  };

  home.packages = with pkgs; [
    pkgs.dconf
  ];
}
