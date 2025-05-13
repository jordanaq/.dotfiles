{ config, pkgs, ... }:
let
  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-full;
      # pdfcol
      # tcolorbox;
      #(setq org-latex-compiler "lualatex")
      #(setq org-preview-latex-default-process 'dvisvgm)
  });
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
