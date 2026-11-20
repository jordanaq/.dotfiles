{ config, ... }:

{
  imports = [
    ./ai
    ./bat
    ./btop
    ./flatpak
    ./git
    ./graphics
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
