
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    harfbuzz
  ];

  imports = [
    ./rocm.nix
  ];
}
