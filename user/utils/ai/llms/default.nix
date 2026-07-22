# Top-level orchestrator for the llms module.
#
# The configuration has been split into focused submodules:
#
#   common.nix          - shared bindings (paths, ports, package refs)
#   ollama/default.nix  - services.ollama daemon configuration
#   ollama/models.nix   - model catalog + Hugging Face import helper
#   ollama/services.nix - pull/import systemd services + timer
#   gbrain.nix          - gbrain wrapper, hermes gateway, gbrain services
#   opencode.nix        - programs.opencode (editor-side LLM client)
#
# This file simply imports them so `home-manager` sees the merged config.
{ config, inputs, lib, pkgs, system, ... }:

{
  imports = [
    ./ollama/default.nix
    ./ollama/services.nix
    ./gbrain.nix
    ./firecrawl.nix
    ./opencode.nix
  ];
}
