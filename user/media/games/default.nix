{ pkgs, ... }:

{
  imports = [
    ./lutris
    ./jagex-launcher
    ./duckstation
  ];

  home.packages = with pkgs; [
    bolt-launcher
  ];
}
