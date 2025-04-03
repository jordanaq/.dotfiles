{ config, pkgs, ... }:

{
  imports = [
    ./brave
    ./firefox
    ./zen-browser
  ];
}
