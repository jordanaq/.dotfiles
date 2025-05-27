{ pkgs, ... }:

{
  home.packages = with pkgs; [
    mlton
  ];
}
