{ pkgs, ... }:

{
  home.packages = with pkgs; [
    black
    conda
    # Use the Nixpkgs default interpreter for its cached notebook dependencies.
    (python3.withPackages (ps: with ps; [
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
