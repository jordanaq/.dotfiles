{ config, lib, pkgs, odysseus-nix, system, ... }:

let
  ollama = lib.getExe config.services.ollama.package;
  host = "127.0.0.1";
  port = 11434;
  searxUrl = "http://127.0.0.1:8888/search";

  models = [
    # Coding
    "qwen2.5-coder:14b"

    # Research / long reading
    "gemma4:12b"
    "gemma4:e4b"

    # Reasoning
    "gpt-oss:20b"

    # Retrieval
    "qwen3-embedding:latest"
  ];

in {
  home.packages = [
    odysseus-nix.packages.${system}.odysseus-dev
  ];

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
          "models" = {
            "qwen2.5-coder:14b" = {};
             "gemma4:12b" = {};
             "gemma4:e4b" = {};
             "gpt-oss:20b" = {};
             "qwen3-embedding:latest" = {};
          };
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
      OLLAMA_CONTEXT_LENGTH = "32768";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_GPU_OVERHEAD = "2147483648";
      OLLAMA_KEEP_ALIVE = "2m";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      OLLAMA_LLM_LIBRARY = "rocm_v7_2";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
      LLAMA_ARG_N_GPU_LAYERS = "all";

      # Restrict ROCm discovery to the discrete RX 9070 XT.
      ROCR_VISIBLE_DEVICES = "GPU-fb707245ca77dfde";
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
