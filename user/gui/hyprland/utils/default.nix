{ config, pkgs, ... }:

{
  imports = [
    ./cava.nix
    ./dunst.nix
    ./flameshot.nix
    ./swaylock.nix
    ./wofi.nix
  ];

  programs.jq.enable = true;

  home.packages = with pkgs; [
    wl-clipboard
    ulauncher
    tty-clock
    swww
    grim
    slurp
  ];
}
