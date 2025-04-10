{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zotero
    obsidian
  ];
}
