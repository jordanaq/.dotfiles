# OpenCode (editor-side LLM client) configuration.
#
# Owns the `programs.opencode` block including the SearXNG websearch tool and
# the Ollama provider entry that references the model catalog from
# `ollama/models.nix`.
{ config, inputs, lib, pkgs, system, ... }:

let
  common = import ../common.nix { inherit config inputs lib pkgs system; };
  models = import ./ollama/models.nix { inherit config lib; };
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

            const response = await fetch("${common.searxUrl}", {
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
          "models" = models.opencodeModelAttrs;
        };
      };
    };
  };
}
