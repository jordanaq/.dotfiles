# Configures shells

{ config, pkgs, ... }:

let
  shellAliases = {
    l = "eza -laG -F=always --icons=always";
    v = "nvim";
  };
in {
  programs = {
    fish = {
      enable = true;
      shellAliases = shellAliases;
    };
   
    bash = {
      enable = true;
      shellAliases = shellAliases;
    };
  };
}
