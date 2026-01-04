# User wide setup

{ config, pkgs, ... }:

{
  home.packages = with pkgs; with pkgs.texlivePackages; [
    hasklig
    inter
    lato
    noto-fonts
    hack-font
    opensans
    fontawesome
    nerd-fonts.symbols-only
  ];

  fonts.fontconfig = {
    enable = true;

    defaultFonts.monospace = [
      "hack"
      "NotoSansMono"
      "hasklig"
      "monospace"
    ];

    defaultFonts.sansSerif = [
      "NotoSans"
      "inter"
      "lato"
      "opensans"
    ];
  };
}
