{ pkgs, ... }:

{
  programs.feh = {
    enable = true;
  };

  home.packages = with pkgs; [
    obs-studio
    vlc
    zathura
  ];
}
