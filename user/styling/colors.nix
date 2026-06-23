{ config, pkgs, catppuccin, ... }:

{
  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "macchiato";
    accent = "pink";
  };
}
