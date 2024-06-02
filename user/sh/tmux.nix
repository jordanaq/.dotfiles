{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shell = "\${pkgs.fish}/bin/fish}";
  };
}
