{ pkgs, ... }:

{
  xsession = {
    enable = true;
    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;
      extraPackages = haskellPackages: with pkgs; [
        dbus
        monad-logger
        xmonad-contrib
      ];
      config = ./xmonad.hs
    };
  };
}
