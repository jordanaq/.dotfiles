{ pkgs, ... }:

{
  imports = [
    ./lutris
  ];

  home.packages = with pkgs; [
    bolt-launcher
  ];
}
