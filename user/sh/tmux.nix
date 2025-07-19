{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shell = "\${pkgs.fish}/bin/fish}";

    terminal = "tmux-256color";

    historyLimit = 100000;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      catppuccin
    ];

    extraConfig = ''
      # Enable truecolor support
      set-option -ga terminal-overrides ",xterm-256color:Tc"

      # Other useful options
      set-option -g mouse on

      # set-option -g history-limit 10000
      setw -g automatic-rename on

      set -g @catppuccin_flavor "macchiato"
    '';
  };
}
