{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gmp
    gnumake
  ];

  imports = [
    ./gdb
  ];
}
