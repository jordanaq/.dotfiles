# Configures shells

{ config, pkgs, ... }:

let
  shellAliases = {
    b = "bat";
    c = "clear";
    l = "eza -laG -F=always --icons=always";
    v = "nvim";
    z = "zoxide";
    g = "git";
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
