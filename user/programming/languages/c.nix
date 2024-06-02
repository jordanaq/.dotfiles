{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gcc_multi
  ];
}
