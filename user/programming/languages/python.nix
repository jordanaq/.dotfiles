{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    black
    conda
    (python312.withPackages (ps: with ps; [
      conda
      ipykernel
      matplotlib
      nbconvert
      notebook
      numpy
      pandas
      pip
      plotly
      scipy
      seaborn
      sympy
      virtualenv
    ]))
  ];
}
