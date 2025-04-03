{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    black
    (python313.withPackages (ps: with ps; [
      scipy
      numpy
      pandas
    ]))
  ];
}
