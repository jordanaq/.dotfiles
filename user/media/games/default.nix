{ pkgs, ... }:

{
  imports = [
    ./lutris
  ];

  home.packages = with pkgs; [
    bolt-launcher
    # runescape # Uses an insecure openssl package xd
  ];
}
