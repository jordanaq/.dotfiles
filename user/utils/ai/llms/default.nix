{ config, lib, pkgs, odysseus-nix, system, ... }:

let
  ollama = lib.getExe config.services.ollama.package;
  host = "127.0.0.1";
  port = 11434;

  models = [
    # Coding
    "gemma4:12b"
    "gemma4:latest"
    "qwen3.6:latest"
    "qwen3.6:27b"

    # Chat
    "granite4.1:8b"

    # Embed
    "qwen3-embedding:latest"
  ];

in {
  home.packages = [
    odysseus-nix.packages.${system}.odysseus-dev
  ];

  services.ollama = {
    enable = true;
    port = port;
    host = host;
    acceleration = "rocm";

    environmentVariables = { 
      OLLAMA_MODELS = "${config.home.homeDirectory}/.local/share/ollama/models";
    };
  };

  systemd.user.services.ollama-pull-models = {
    Unit = {
      Description = "Pull Ollama models";
      Requires = [ "ollama.service" ];
      After = [ "ollama.service" "network.target" ];
    };

    Service = {
      Type = "oneshot";
      Environment = [
        "OLLAMA_HOST=${host}:${toString port}"
      ];

      ExecStart = pkgs.writeShellScript "ollama-pull-models" ''
        set -euo pipefail

        until ${pkgs.curl}/bin/curl -fsS http://${host}:${toString port}/api/tags >/dev/null; do
          sleep 1
        done

        ${lib.concatMapStringsSep "\n" (model: ''
          ${ollama} pull ${lib.escapeShellArg model}
        '') models}
        '';
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
