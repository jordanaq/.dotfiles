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
    #cursorTheme = pkgs.catppuccin-cursors.macchiatoPink;
  };

  home.packages = with pkgs; [
    pkgs.dconf
  ];
}
