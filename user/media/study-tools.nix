{ pkgs, lib, inputs, system, ... }:

let
  # jabref comes from the pinned `nixpkgs-jabref` flake input, NOT from this
  # flake's nixpkgs — see the long comment on that input in flake.nix. Short
  # version: the tracked nixpkgs rev ships a jabref whose Gradle build cannot
  # resolve kotlin-stdlib, and has no prebuilt binary, so it never installs.
  # The pinned rev fixes the build (PR #560905) and ships JavaFX 25, which also
  # fixes the ToolBarSkin NPE (OpenJFX JDK-8364088).
  jabrefPinned = inputs.nixpkgs-jabref.legacyPackages.${system}.jabref;
in
{
  home.packages = with pkgs; [
    zotero
    obsidian
    jabrefPinned
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
