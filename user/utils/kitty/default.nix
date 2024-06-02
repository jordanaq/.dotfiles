{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "hasklig";
      package = pkgs.hasklig;
      size = 11;
    };

    theme = "Catppuccin-Macchiato";

    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
    };

    shellIntegration = {
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
