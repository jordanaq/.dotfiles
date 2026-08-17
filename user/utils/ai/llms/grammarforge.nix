# Self-hosted GrammarForge bridge (rootless Docker, per-user systemd service).
#
# Mirrors the firecrawl.nix pattern: copies the compose into
# ~/.config/grammarforge, generates per-host secrets once into
# ~/.config/grammarforge/.env (chmod 600, git-ignored), and runs the stack as
# a `grammarforge.service` user unit that Requires the rootless docker.service.
#
# LLM tier: points at the Nous Portal (OpenAI-compatible inference API) via
# GF_LLM_BASE_URL / GF_LLM_MODEL / GF_LLM_API_KEY in the generated .env. The
# key is a SECRET (never committed); set it in .env after first activation.
# We intentionally do NOT run a local llama.cpp — the LLM is remote by design.
#
# ONNX models (GECToR + MiniLM, ~435MB) are provisioned into
# ~/.config/grammarforge/models/ by the grammarforgeModels activation step,
# then mounted read-only into the container.
{ config, pkgs, lib, ... }:

let
  cfgDir = "${config.home.homeDirectory}/.config/grammarforge";
  envFile = "${cfgDir}/.env";
  composeFile = "${cfgDir}/docker-compose.yaml";
  # rootless docker-compose shells out to `docker`, so both must be on PATH.
  dockerPath = lib.makeBinPath [ pkgs.docker pkgs.docker-compose ];

  up = pkgs.writeShellScript "grammarforge-up" ''
    set -euo pipefail
    export PATH="${dockerPath}:$PATH"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
    exec ${lib.getExe pkgs.docker-compose} \
      --env-file ${lib.escapeShellArg envFile} \
      -f ${lib.escapeShellArg composeFile} up
  '';

  down = pkgs.writeShellScript "grammarforge-down" ''
    set -euo pipefail
    export PATH="${dockerPath}:$PATH"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
    ${lib.getExe pkgs.docker-compose} \
      --env-file ${lib.escapeShellArg envFile} \
      -f ${lib.escapeShellArg composeFile} down
  '';

  # Provision GECToR + MiniLM ONNX models. These are plain downloads (no export
  # or quantize step). Idempotent: skips files that already exist so a switch
  # never re-downloads ~435MB. The container mounts this dir read-only.
  provision = pkgs.writeShellScript "grammarforge-provision-models" ''
    set -euo pipefail
    models_dir="${cfgDir}/models"
    gector_repo="https://huggingface.co/Meyssa/gector-large-2024/resolve/main"
    minilm_repo="https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main"
    export PATH="${lib.makeBinPath [ pkgs.curl ]}:$PATH"

    mkdir -p "$models_dir/gector" "$models_dir/minilm"

    fetch() { # $1=url $2=dest
      if [ ! -f "$2" ]; then
        curl -fL --retry 5 -C - -o "$2.partial" "$1"
        mv "$2.partial" "$2"
      fi
    }

    fetch "$gector_repo/onnx/model_quantized.onnx" "$models_dir/gector/model.onnx"
    for f in config.json tokenizer.json tokenizer_config.json vocab.json merges.txt special_tokens_map.json; do
      fetch "$gector_repo/$f" "$models_dir/gector/$f"
    done
    fetch "https://raw.githubusercontent.com/grammarly/gector/master/data/verb-form-vocab.txt" \
      "$models_dir/gector/verb-form-vocab.txt"

    # FIX (upstream bug): Meyssa/gector-large-2024 ships id2label.json / labels.txt
    # as SEPARATE files, but hugot's token-classification pipeline requires
    # id2label IN config.json. The project's fetch-models.sh omits these, so
    # GECToR fails to load ("id2label map must be greater than zero"). Fetch the
    # label map and merge it into config.json as the id2label key.
    fetch "$gector_repo/id2label.json" "$models_dir/gector/id2label.json"
    if [ -f "$models_dir/gector/config.json" ] && [ -f "$models_dir/gector/id2label.json" ]; then
      ${pkgs.python3}/bin/python3 - "$models_dir/gector/config.json" "$models_dir/gector/id2label.json" <<'PY'
import json, sys
cfg_path, idl_path = sys.argv[1], sys.argv[2]
cfg = json.load(open(cfg_path))
idl = json.load(open(idl_path))
if "id2label" not in cfg or len(cfg.get("id2label", {})) != len(idl):
    cfg["id2label"] = idl
    json.dump(cfg, open(cfg_path, "w"), indent=2)
PY
    fi

    fetch "$minilm_repo/onnx/model.onnx" "$models_dir/minilm/model.onnx"
    for f in tokenizer.json config.json vocab.txt special_tokens_map.json; do
      fetch "$minilm_repo/$f" "$models_dir/minilm/$f"
    done
  '';
in {
  # Committed compose (no secrets — uses ${...} interpolation from .env).
  home.file.".config/grammarforge/docker-compose.yaml".source =
    ./grammarforge/docker-compose.yaml;

  # Provision the ONNX models on every activation (idempotent; skips existing).
  home.activation.grammarforgeModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg cfgDir}
    chmod 700 ${lib.escapeShellArg cfgDir}
    ${provision}
  '';

  # Generate secrets once; never overwrite an existing file (so a
  # `home-manager switch` does not rotate a live key). GF_LLM_API_KEY is left
  # empty here — populate it in the generated .env (chmod 600, git-ignored)
  # after first activation, mirroring the firecrawl OPENAI_API_KEY convention.
  home.activation.grammarforgeSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg cfgDir}
    chmod 700 ${lib.escapeShellArg cfgDir}
    if [ ! -f ${lib.escapeShellArg envFile} ]; then
      printf '%s\n' \
        "GF_REST_ADDR=:8000" \
        "GF_GRPC_ADDR=:8082" \
        "GF_LLM_BASE_URL=https://inference-api.nousresearch.com/v1" \
        "GF_LLM_MODEL=~deepseek/deepseek-v4-flash-latest" \
        "GF_LLM_FORMAT=chat_instruct" \
        "GF_LLM_API_KEY=" \
        > ${lib.escapeShellArg envFile}
      chmod 600 ${lib.escapeShellArg envFile}
    fi
  '';

  systemd.user.services.grammarforge = {
    Unit = {
      Description = "Self-hosted GrammarForge bridge (rootless Docker)";
      After = [ "docker.service" "network-online.target" ];
      Requires = [ "docker.service" ];
      PartOf = [ "docker.service" ];
    };

    Service = {
      Type = "simple";
      ExecStart = up;
      ExecStop = down;
      Restart = "on-failure";
      RestartSec = 10;
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
