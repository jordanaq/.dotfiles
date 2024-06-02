{ config, pkgs, ... }:

{
  programs.cava = {
    enable = true;
  };

  home.file.cava_conf = {
    source = ./assets/cava/config;
    target = ".config/cava/config";
  };
}
