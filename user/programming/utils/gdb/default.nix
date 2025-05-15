{ pkgs, ... }:

{
  home.file.".gdbinit".text = ''
    add-auto-load-safe-path /nix/store
  '';

  home.packages = with pkgs; [
    gdb
  ];
}
