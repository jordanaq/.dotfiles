# User wide setup (server edition)

{ config, pkgs, ... }:

{
  imports = [
    ./sh
    ./utils
  ];

  home = {
    username = "tsiru";
    homeDirectory = "/home/tsiru";
    stateVersion = "26.05"; # Read home manager release notes before changing.

    # Packages
    packages = with pkgs; [
      eza
      sqlite
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
