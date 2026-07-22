# Shared bindings for the llms module.
#
# This file holds the cross-cutting values (paths, ports, package references)
# that more than one submodule needs. Keeping them here avoids circular imports
# and gives each submodule a single, stable place to read shared state from.
#
# Note: this file is NOT imported by sibling submodules via `import`, because
# Nix store copies flatten the directory layout and break relative imports.
# Instead, each submodule inlines the bindings it needs (duplication is small
# and keeps every file self-contained and debuggable).
{ config, inputs, lib, pkgs, system, ... }:

let
  host = "127.0.0.1";
  port = 11434;
in {
  inherit host port;

  ollama = lib.getExe config.services.ollama.package;
  huggingfaceCli = "${pkgs.python3Packages.huggingface-hub}/bin/hf";

  searxUrl = "http://${host}:8888/search";

  hermesPackage = inputs.hermes-agent.packages.${system}.default;

  gbrainSource = inputs.gbrain-src;
  gbrainRuntimeDir = "${config.home.homeDirectory}/.local/share/gbrain/runtime";
  gbrainSecretsFile = "${config.home.homeDirectory}/.config/gbrain/secrets.env";
  gbrainAutopilotRepo = "${config.home.homeDirectory}/brain";

  gbrainShellPath = lib.makeBinPath [
    pkgs.bun
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
  ];
}
