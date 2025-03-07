{ config, pkgs, ... }:

{
  imports = [
    ./firefox
    ./zen-browser
  ];
}
