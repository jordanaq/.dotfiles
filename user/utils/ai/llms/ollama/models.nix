# Declarative model catalog and Hugging Face import helpers.
#
# This file owns:
#   - the list of Ollama registry models to `ollama pull`
#   - the list of Hugging Face GGUF models to download + `ollama create`
#   - the helper that turns one HF model into a shell snippet for the import
#     service
#   - the combined `allOllamaModels` list used by opencode's provider config
{ config, pkgs, lib, ... }:

let
  ollama = lib.getExe config.services.ollama.package;
  huggingfaceCli = "${pkgs.python3Packages.huggingface-hub}/bin/hf";

  ollamaRegistryModels = [
    # Offline agentic coding
    "qwen3-coder-next:latest"

    # Retrieval
    "qwen3-embedding:latest"

    # General local reasoning
    "qwen3.6:27b"
    "qwen3.6:35b"
  ];

  # Declarative Hugging Face models imported into Ollama at login/startup.
  # For gated/private repos, make sure HUGGINGFACE_HUB_TOKEN is exported in
  # your session environment so the user service can authenticate.
  huggingfaceOllamaModels = [
    {
      ollamaName = "infracelestial:27b";
      repo = "bartowski/Mawdistical-S1_Infracelestial-27B-GGUF";
      file = "Mawdistical-S1_Infracelestial-27B-Q4_K_M.gguf";
      parameters = {
        num_ctx = "262144";
      };
    }

    {
      ollamaName = "nightlife:24b";
      repo = "Mawdistical/Mawdistic-NightLife-24b-GGUF";
      file = "Mawdistical_Mawdistic-NightLife-24b-Q4_K_M.gguf";
      parameters = {
        num_ctx = "32768";
      };
    }

    {
      ollamaName = "qwen3.6-abliterated:35b-a3b";
      repo = "HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive";
      file = "Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf";
      parameters = {
        num_ctx = "262144";
      };
    }
  ];

  allOllamaModels =
    ollamaRegistryModels
    ++ map (model: model.ollamaName) huggingfaceOllamaModels;

  opencodeModelAttrs = builtins.listToAttrs (
    map (modelName: {
      name = modelName;
      value = { };
    }) allOllamaModels
  );

  # Build the shell snippet that imports a single HF model into Ollama.
  # Skips models that already exist so the service can continue to the next
  # entry instead of aborting the whole oneshot.
  mkHfImportCommands = model:
    let
      safeRepo = builtins.replaceStrings [ "/" ] [ "__" ] model.repo;
      cacheDir = "${config.home.homeDirectory}/.cache/huggingface/ollama/${safeRepo}";
      parameterLines = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (key: value: "PARAMETER ${key} ${toString value}") (model.parameters or { })
      );
      ggufPathExpr = if model ? file then
        ''
          gguf_path="${cacheDir}/${model.file}"
        ''
      else
        ''
          gguf_path="$(find "${cacheDir}" -maxdepth 1 -type f -name '*.gguf' | head -n 1)"
        '';

      # Download only the pinned GGUF when one is declared; otherwise pull
      # every *.gguf in the repo (legacy fallback for file-less entries).
      includeArg = if model ? file
        then "--include ${lib.escapeShellArg model.file}"
        else "--include ${lib.escapeShellArg "*.gguf"}";
    in ''
      if ${ollama} show ${lib.escapeShellArg model.ollamaName} >/dev/null 2>&1; then
        echo "${model.ollamaName} already exists in Ollama, skipping import"
      else
        mkdir -p "${cacheDir}"

        echo "Downloading GGUF model for ${model.repo} into ${cacheDir}..."

        ${huggingfaceCli} download ${lib.escapeShellArg model.repo} ${includeArg} --local-dir "${cacheDir}"

        ${ggufPathExpr}
        if [ -z "''${gguf_path:-}" ] || [ ! -f "''${gguf_path}" ]; then
          echo "No GGUF file found for ${model.repo} in ${cacheDir}" >&2
          exit 1
        fi

        modelfile="$(mktemp)"
        cat > "''${modelfile}" <<EOF
FROM ''${gguf_path}
${parameterLines}
EOF

        ${ollama} create ${lib.escapeShellArg model.ollamaName} -f "''${modelfile}"
        rm -f "''${modelfile}"
      fi
    '';
in {
  inherit
    ollamaRegistryModels
    huggingfaceOllamaModels
    allOllamaModels
    opencodeModelAttrs
    mkHfImportCommands
    ;
}
