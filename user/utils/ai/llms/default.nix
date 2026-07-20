{ config, inputs, lib, pkgs, system, ... }:

let
  ollama = lib.getExe config.services.ollama.package;
  huggingfaceCli = "${pkgs.python3Packages.huggingface-hub}/bin/hf";
  defaultModel = "holo3.1:35b-a3b";
  host = "127.0.0.1";
  port = 11434;
  searxUrl = "http://127.0.0.1:8888/search";
  hermesPackage = inputs.hermes-agent.packages.${system}.default;

  ollamaRegistryModels = [
    # Research / long reading
    "qwen3.5:9b"
    "huihui_ai/qwen3.5-abliterated:9b"
    "qwen3.6:35b"

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
      mkdir -p "${cacheDir}"
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
    '';

in {
  home.packages = [
    hermesPackage
    inputs.hermes-agent.packages.${system}.desktop
    pkgs.python3Packages.huggingface-hub
  ];

  home.file.".hermes/config.yaml".source = ./hermes-config.yaml;

  programs.opencode = {
    enable = true;

    tools = {
      websearch = ''
        import { tool } from "@opencode-ai/plugin"

        export default tool({
          description: "Search the web using the user's local SearXNG instance",
          args: {
            query: tool.schema.string().describe("Search query"),
            limit: tool.schema.number().optional().describe("Maximum number of results to return"),
          },
          async execute(args) {
            const limit = Math.max(1, Math.min(args.limit ?? 8, 20))
            const body = new URLSearchParams({
              q: args.query,
              format: "json",
              safesearch: "0",
            })

            const response = await fetch("${searxUrl}", {
              method: "POST",
              headers: {
                "accept": "application/json",
                "content-type": "application/x-www-form-urlencoded",
              },
              body,
            })

            if (!response.ok) {
              return `SearXNG search failed: HTTP ''${response.status} ''${response.statusText}`
            }

            const data = await response.json()
            const results = (data.results ?? []).slice(0, limit)

            if (results.length === 0) {
              return `No SearXNG results found for "''${args.query}".`
            }

            return results.map((result, index) => {
              const title = result.title ?? "Untitled"
              const url = result.url ?? ""
              const content = result.content ?? ""
              return `''${index + 1}. ''${title}\n''${url}\n''${content}`
            }).join("\n\n")
          },
        })
      '';
    };
    
    settings = {
      "tools" = {
        "websearch" = true;
        "codesearch" = true;
      };

      "provider" = {
        "ollama" = {
          "npm" = "@ai-sdk/openai-compatible";
          "options" = {
            "baseURL" = "http://localhost:11434/v1";
          };
          "models" = opencodeModelAttrs;
        };
      };
    };
  };

  services.ollama = {
    enable = true;
    port = port;
    host = host;
    package = pkgs.ollama-rocm.override {
      rocmPackages = pkgs.rocmPackages.gfx1201;
    };

    environmentVariables = {
      OLLAMA_MODELS = "${config.home.homeDirectory}/.local/share/ollama/models";
      OLLAMA_CONTEXT_LENGTH = "262144";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_GPU_OVERHEAD = "2147483648";
      OLLAMA_KEEP_ALIVE = "2m";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      OLLAMA_LLM_LIBRARY = "rocm_v7_2";
      # Let the embedding model remain available alongside the active LLM.
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_NUM_PARALLEL = "1";
      # Keep enough VRAM available for the desktop and other GPU workloads.
      LLAMA_ARG_N_GPU_LAYERS = "16";

      # Restrict ROCm discovery to the discrete RX 9070 XT.
      ROCR_VISIBLE_DEVICES = "GPU-fb707245ca77dfde";
    };
  };

  systemd.user.services.hermes-gateway = {
    Unit = {
      Description = "Hermes Agent gateway";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe hermesPackage} gateway run --replace";
      Restart = "on-failure";
      RestartSec = 5;
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
      ];
    };

    Install.WantedBy = [ "default.target" ];
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
        '') ollamaRegistryModels}
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
        "OLLAMA_HOST=${host}:${toString port}"
      ];

      ExecStart = pkgs.writeShellScript "ollama-import-hf-models" ''
        set -euo pipefail

        until ${pkgs.curl}/bin/curl -fsS http://${host}:${toString port}/api/tags >/dev/null; do
          sleep 1
        done

        ${if huggingfaceOllamaModels == [ ] then
          "echo 'No declarative Hugging Face Ollama models configured.'"
        else
          lib.concatMapStringsSep "\n\n" mkHfImportCommands huggingfaceOllamaModels}
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
