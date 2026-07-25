{ pkgs, ... }:

{
  imports = [
    ./lutris
    ./jagex-launcher
  ];

  home.packages = with pkgs; [
    bolt-launcher
  ];
}
