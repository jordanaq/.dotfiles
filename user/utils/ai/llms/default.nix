{ config, lib, pkgs, ... }:

let
  ollama = lib.getExe config.services.ollama.package;
  host = "127.0.0.1";
  port = 11434;

  models = [
    "kimi-k2.7-code"
    "deepseek-v4-pro"
    "deepseek-v4-flash"
    "gemma4:12b"
    "gemma4:31b"
  ];

in {
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
      Requries = [ "ollama.service" ];
      After = [ "ollama.services" "network.target" ];
    };

    Service = {
      Type = "oneshot";
      Environment = [
        "OLLAMA_HOST=${host}:${port}"
      ];

      ExecStart = pkgs.writeShellScript "ollama-pull-models" ''
        set -euo pipefail

        until ${pkgs.curl}/bin/curl -fsS http://127.0.0.1:11434/api/tags >/dev/null; do
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
