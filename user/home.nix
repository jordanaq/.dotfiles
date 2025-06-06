# User wide setup

{ config, pkgs, ... }:

{
  imports = [
    ./drivers
    ./gui
    ./media
    ./programming
    ./sh
    ./styling
    ./utils
  ];

  home = {
    username = "tsiru";
    homeDirectory = "/home/tsiru";
    stateVersion = "25.05"; # Read home manager release notes before changing.

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

  home.file.".face".source = ../assets/images/furry/avatar/selver_upscaled.jpg;
}
