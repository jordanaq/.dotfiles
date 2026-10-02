{ pkgs, ... }:

{
  home.file.".gdbinit".text = ''
    add-auto-load-safe-path /nix/store
    add-auto-load-safe-path /home/tsiru/Documents/Projects
    add-auto-load-safe-path /home/tsiru/Documents/Projects/*

  '';

  home.packages = with pkgs; [
    gdb
    lldb
  ];
}
