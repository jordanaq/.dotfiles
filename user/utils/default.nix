{ config, ... }:

{
  imports = [
    ./ai
    ./bat
    ./btop
    ./flatpak
    ./git
    ./graphics
    ./harper-web
    ./keepass
    ./kitty
    ./misc
    ./neovim
    ./pandoc
    ./tailscale-systray
    ./texlive
    ./thunar
    ./zip
    ./zoxide
  ];
}
