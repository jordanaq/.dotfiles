{ pkgs, ... }:

{
  programs.texlive = {
    enable = true;
    package = pkgs.texliveFull;
  };
}
