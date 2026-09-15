{ config, pkgs, ... }:
let
  # scheme-full. `pkgs.texlive.combine` is deprecated (removal in nixpkgs 27.05);
  # the equivalent pre-combined set is the top-level texliveFull.
  tex = pkgs.texliveFull;
in
{
  # programs.texlive = {
  #   enable = true;
  #   packageSet = pkgs.texlive.scheme-full;
  # };
  home.packages = with pkgs; [
    tex
  ];
}
