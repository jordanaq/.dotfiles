# User wide setup

{ config, pkgs, ... }:

{
  imports = [
    ./sh

    ./gui

    ./media

    ./programming

    ./styling

    ./utils
  ];

  home = {
    username = "tsiru";
    homeDirectory = "/home/tsiru";
    stateVersion = "24.05"; # Read home manager release notes before changing.

    # Packages
    packages = with pkgs; [
      eza
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
