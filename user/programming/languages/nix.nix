{ pkgs, ... }:

{
  # nixfmt (RFC-style, v1.x) — also the formatter jnoortheen.nix-ide shells out to
  # on format-on-save; without a binary on the store path it fails with
  # "spawn nixfmt ENOENT".
  home.packages = with pkgs; [
    nixfmt
  ];
}
