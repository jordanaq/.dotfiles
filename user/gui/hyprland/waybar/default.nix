{ config, pkgs, ... }:

{
  home.file.waybar_conf = {
    source = ./config;
    target = ".config/hypr/component/waybar/config";
  };
  
  home.file.waybar_style = {
    source = ./style.css;
    target = ".config/hypr/component/waybar/style.css";
  };

  home.packages = with pkgs; [
    waybar-mpris
  ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ./style.css;
  };
}
