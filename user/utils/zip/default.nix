{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    unzip
    zip
  ];
}
