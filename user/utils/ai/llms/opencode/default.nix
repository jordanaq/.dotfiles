{
  config,
  lib,
  pkgs,
  ...
}:

let
  searxPlugin = pkgs.writeTextDir "index.ts" (builtins.readFile ./plugins/searxng/index.ts);
in
{
  programs.opencode = {
    enable = true;

    cli.theme = {
      name = "catppuccin-macchiato";
      mode = "dark";
    };

    settings = {
      model = "nous/~deepseek/deepseek-flash-latest";
      plugins = [ "${searxPlugin}" ];

      providers.nous = {
        name = "Nous Portal";
        package = "@opencode/ai/providers/openai-compatible";
        settings = {
          baseURL = "https://inference-api.nousresearch.com/v1";
          apiKey = "{file:~/.config/nous/secrets/nous_api_key}";
        };
        models = {
          "~deepseek/deepseek-flash-latest" = { };
          "z-ai/glm-5.3" = { };
          "z-ai/glm-5.3-flash" = { };
          "tencent/hy4" = { };
          "tencent/hy4-flash" = { };
          "tencent/hy4-flash:free" = { };
          "qwen/qwen4-max:free" = { };
          "xiaomi/mimo-v2.6-pro" = { };
          "minimax/minimax-m3.1-flash" = { };
          "moonshotai/kimi-k2.7-code" = { };
          "anthropic/claude-sonnet-5.5" = { };
        };
      };
    };
  };
}
