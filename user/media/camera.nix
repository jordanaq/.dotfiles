{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    droidcam
  ];
}
