# User wide setup

{ config, pkgs, ... }:

{
  home.packages = with pkgs; with pkgs.texlivePackages; [
    hasklig
    inter
    lato
    noto-fonts
    nerdfonts
    opensans
    fontawesome
  ];

  fonts.fontconfig = {
    enable = true;

    defaultFonts.monospace = [
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
