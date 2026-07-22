# Ollama model pull and Hugging Face import services.
#
# Owns the two oneshot services (`ollama-pull-models`,
# `ollama-import-hf-models`) and the recurring timer for HF imports. The model
# lists and import helper come from `models.nix`.
{ config, inputs, lib, pkgs, system, ... }:

let
  common = import ../common.nix { inherit config inputs lib pkgs system; };
  models = import ./models.nix { inherit config lib; };
in {
  systemd.user.services.ollama-pull-models = {
    Unit = {
      Description = "Pull Ollama models";
      Requires = [ "ollama.service" ];
      After = [ "ollama.service" "network.target" ];
    };

    Service = {
      Type = "oneshot";
      Environment = [
        "OLLAMA_HOST=${common.host}:${toString common.port}"
      ];

      ExecStart = pkgs.writeShellScript "ollama-pull-models" ''
        set -euo pipefail

        until ${pkgs.curl}/bin/curl -fsS http://${common.host}:${toString common.port}/api/tags >/dev/null; do
          sleep 1
        done

        ${lib.concatMapStringsSep "\n" (model: ''
          ${common.ollama} pull ${lib.escapeShellArg model}
        '') models.ollamaRegistryModels}
      '';
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.ollama-import-hf-models = {
    Unit = {
      Description = "Import Hugging Face GGUF models into Ollama";
      Requires = [ "ollama.service" ];
      After = [ "ollama.service" "network.target" ];
    };

    Service = {
      Type = "oneshot";
      Environment = [
        "OLLAMA_HOST=${common.host}:${toString common.port}"
      ];

      ExecStart = pkgs.writeShellScript "ollama-import-hf-models" ''
        set -euo pipefail

        until ${pkgs.curl}/bin/curl -fsS http://${common.host}:${toString common.port}/api/tags >/dev/null; do
          sleep 1
        done

        ${
          if models.huggingfaceOllamaModels == [ ] then
            "echo 'No declarative Hugging Face Ollama models configured.'"
          else
            lib.concatMapStringsSep "\n\n" models.mkHfImportCommands models.huggingfaceOllamaModels
        }
      '';
    };
  };

  # Run HF imports shortly after session start and periodically, without
  # blocking `home-manager switch`.
  systemd.user.timers.ollama-import-hf-models = {
    Unit = {
      Description = "Schedule Hugging Face GGUF imports into Ollama";
    };

    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "12h";
      Unit = "ollama-import-hf-models.service";
      Persistent = true;
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
