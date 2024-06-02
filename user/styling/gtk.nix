{ config, pkgs, ... }:

{
  home.pointerCurser = {
    gtk.enable = true;
    package = pkgs.catppuccin-cursors.macchiatoPink;
    size = 16;
  };

  gtk = {
    enable = true;
    cursorTheme = pkgs.catppuccin-cursors.macchiatoPink;
  };
}
