{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    zotero
    obsidian
    (lib.hiPrio (writeShellScriptBin "obsidian" ''
      exec ${obsidian}/bin/obsidian-cli "$@"
    ''))
  ];

  # Keep `obsidian` as the command/IPC CLI used by command rules, but make the
  # graphical desktop launcher invoke Electron directly.
  xdg.desktopEntries.obsidian = {
    name = "Obsidian";
    comment = "Knowledge base";
    exec = "${pkgs.obsidian}/bin/obsidian %U";
    icon = "obsidian";
    categories = [ "Office" ];
    mimeType = [ "x-scheme-handler/obsidian" ];
  };
}
