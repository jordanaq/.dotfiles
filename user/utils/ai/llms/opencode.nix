# OpenCode (editor-side LLM client) configuration.
#
# Owns the `programs.opencode` block including the SearXNG websearch tool and
# the Nous Portal provider entry (OpenAI-compatible, deepseek-v4-flash rolling).
{ lib, ... }:

let
  searxUrl = "http://127.0.0.1:8888/search";

  # Editor LLM via the Nous Portal (OpenAI-compatible inference API). The API
  # key comes from NOUS_API_KEY, exported into the session env from the
  # git-ignored ~/.config/nous/secrets.env (see gbrain.nix) — never in dotfiles.
  # Rolling deepseek-v4-flash (not -0731): the 0731 snapshot is served by
  # Novita and rejects structured output / tool-call JSON that agentic coding
  # relies on (2026-08-12).
  nousModels = {
    "deepseek/deepseek-v4-flash" = { };
  };
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
        "nous" = {
          "npm" = "@ai-sdk/openai-compatible";
          "options" = {
            "baseURL" = "https://inference-api.nousresearch.com/v1";
            "apiKey" = "{env:NOUS_API_KEY}";
          };
          "models" = nousModels;
        };
      };
    };
  };
}
