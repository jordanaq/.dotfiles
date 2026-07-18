{ config, pkgs, catppuccin, ... }:

{
  catppuccin = {
    enable = true;
    autoEnable = false;
    flavor = "macchiato";
    accent = "pink";
  };
}
