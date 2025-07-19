{ config, ... }:

{
  imports = [
    ./bat
    ./flatpak
    ./git
    ./keepass
    ./kitty
    ./misc
    ./neovim
    ./pandoc
    ./texlive
    ./thunar
    ./zip
    ./zoxide
  ];
}
