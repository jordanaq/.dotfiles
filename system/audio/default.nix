{ config, pkgs, ... }:

{
  services.pipewire = {
    enable = false;
    wireplumber.enable = true;
  };
}
