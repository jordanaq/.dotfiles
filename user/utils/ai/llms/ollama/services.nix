# Ollama model pull and Hugging Face import services.
#
# Owns the two oneshot services (`ollama-pull-models`,
# `ollama-import-hf-models`) and the recurring timer for HF imports. The model
# lists and import helper come from `models.nix`.
{ config, lib, pkgs, ... }:

let
  host = "127.0.0.1";
  port = 11434;
  ollama = lib.getExe config.services.ollama.package;
  models = import ./models.nix { inherit config pkgs lib; };
in {
  # Only install the pull/import units + timer while the ollama daemon is
  # enabled. When `services.ollama.enable = false` (e.g. while debugging the
  # GPU crashes) this returns an empty set so nothing tries to run against a
  # daemon that isn't up.
  systemd = lib.mkIf config.services.ollama.enable {
    user.services.ollama-pull-models = {
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
        '') models.ollamaRegistryModels}
      '';
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  user.services.ollama-import-hf-models = {
    Unit = {
      Description = "Import Hugging Face GGUF models into Ollama";
      Requires = [ "ollama.service" ];
      After = [ "ollama.service" "network.target" ];
    };

    Service = {
      Type = "oneshot";
      Environment = [
        "OLLAMA_HOST=${host}:${toString port}"
      ];

      ExecStart = pkgs.writeShellScript "ollama-import-hf-models" ''
        set -euo pipefail

        until ${pkgs.curl}/bin/curl -fsS http://${host}:${toString port}/api/tags >/dev/null; do
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
  user.timers.ollama-import-hf-models = {
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
  };
}
