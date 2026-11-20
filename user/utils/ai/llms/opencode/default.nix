{ config, lib, pkgs, ... }:

let
  searxPlugin = pkgs.writeTextDir "index.ts" (builtins.readFile ./plugins/searxng/index.ts);
in
{
  # Export the key from ~/.config/nous/secrets.env at login for GUI and
  # terminal sessions. Run Home Manager after updating the secrets file.
  home.activation.nousSecretsEnv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    nous_dir=${config.home.homeDirectory}/.config/nous
    nous_secrets="$nous_dir/secrets.env"
    envd=${config.home.homeDirectory}/.config/environment.d
    mkdir -p "$nous_dir" "$envd"
    chmod 700 "$nous_dir"
    if [ -f "$nous_secrets" ]; then
      chmod 600 "$nous_secrets"
      key=$(${lib.getExe pkgs.gnused} -n 's/^[[:space:]]*NOUS_API_KEY=[[:space:]]*//p' "$nous_secrets" | head -n1 | tr -d '\r\n')
      if [ -n "$key" ]; then
        umask 077
        printf 'NOUS_API_KEY=%s\n' "$key" > "$envd/10-nous.conf"
      fi
    fi
  '';

  programs.opencode = {
    enable = true;

    settings = {
      model = "nous/~deepseek/deepseek-flash-latest";
      plugins = [ "${searxPlugin}" ];

      providers.nous = {
        name = "Nous Portal";
        env = [ "NOUS_API_KEY" ];
        package = "@opencode/ai/providers/openai-compatible";
        settings = {
          baseURL = "https://inference-api.nousresearch.com/v1";
          apiKey = "{env:NOUS_API_KEY}";
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
