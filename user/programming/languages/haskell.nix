{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ghc
  ];
}
