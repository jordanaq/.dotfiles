# OpenCode (editor-side LLM client) configuration.
#
# Owns the `programs.opencode` block including the SearXNG websearch tool and
# the Ollama provider entry. The model list mirrors the one in
# `ollama/models.nix`; keep both in sync.
{ lib, ... }:

let
  searxUrl = "http://127.0.0.1:8888/search";

  allOllamaModels = [
    "qwen3.5:9b"
    "huihui_ai/qwen3.5-abliterated:9b"
    "qwen3.6:35b"
    "qwen3-coder-next:latest"
    "qwen3-embedding:latest"
    "holo3.1:35b-a3b"
    "qwen3.6-abliterated:35b-a3b"
  ];

  opencodeModelAttrs = builtins.listToAttrs (
    map (modelName: {
      name = modelName;
      value = { };
    }) allOllamaModels
  );
in {
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
}
