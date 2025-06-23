{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    droidcam
    v4l-utils
    android-tools
  ];
}
