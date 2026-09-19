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

    packages = with pkgs; [
      eza
      sqlite
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  programs.home-manager.enable = true;
}
