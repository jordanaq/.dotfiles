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
    # Research / long reading
    "qwen3.5:9b"
    "huihui_ai/qwen3.5-abliterated:9b"

    # Offline agentic coding
    "qwen3-coder-next:latest"

    # Retrieval
    "qwen3-embedding:latest"
  ];

  # Declarative Hugging Face models imported into Ollama at login/startup.
  # For gated/private repos, make sure HUGGINGFACE_HUB_TOKEN is exported in
  # your session environment so the user service can authenticate.
  huggingfaceOllamaModels = [
    {
      ollamaName = "holo3.1:35b-a3b";
      repo = "Hcompany/Holo-3.1-35B-A3B-GGUF";
      file = "q4_k_m.gguf";
      parameters = {
        num_ctx = "262144";
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
    in ''
      if ${ollama} show ${lib.escapeShellArg model.ollamaName} >/dev/null 2>&1; then
        echo "${model.ollamaName} already exists in Ollama, skipping import"
      else
        mkdir -p "${cacheDir}"

        echo "Downloading GGUF model for ${model.repo} into ${cacheDir}..."

        ${huggingfaceCli} download ${lib.escapeShellArg model.repo} --include '*.gguf' --local-dir "${cacheDir}"

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
