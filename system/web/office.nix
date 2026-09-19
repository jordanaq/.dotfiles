# Collabora Online Development Edition (CODE) 26.04 — in-browser office editor
# for Bulwark's Files (WOPI) at office.<domain>.
#
# CODE is packaged from Collabora's official AppImage in ./collabora-code.nix
# (NOT the nixpkgs collabora-online module, which is still 25.04 and lacks the
# AI assistant). Caddy terminates TLS and proxies to [::1]:9980 (CODE binds
# net.listen=loopback = IPv6 loopback). Bulwark (webmail.<domain>) is the WOPI
# host that mints the token and serves the file.
#
# LanguageTool is a native NixOS service on loopback only (NOT :8081 — Calibre
# owns 127.0.0.1:8081, so LanguageTool uses :8091).
#
# AI provider defaults to Nous Portal / DeepSeek V4 Flash Latest. The API key is
# intentionally NOT stored here: enter it once per-user via
# Collabora → AI settings so it never enters the nix store or process argv.
{
  config,
  lib,
  pkgs,
  domain,
  ...
}:

let
  collaboraCode = pkgs.callPackage ./collabora-code.nix { };

  # 8081 is already used by calibre-server; keep LanguageTool off it.
  languagetoolPort = 8091;
in
{
  # ---------------------------------------------
  # Language tool grammar/style checker
  # ---------------------------------------------
  services.languagetool = {
    enable = true;

    port = languagetoolPort;

    # Do not expose LanguageTool outside the machine.
    public = false;

    # Single-user server; bound JVM growth while leaving comfortable headroom.
    jvmOptions = [
      "-Xms64m"
      "-Xmx512m"
    ];
  };

  # ---------------------------------------------
  # Collabora CODE 26.04
  # ---------------------------------------------
  users.groups.cool = { };

  users.users.cool = {
    isSystemUser = true;
    group = "cool";
    home = "/var/lib/cool";
  };

  systemd.services.coolwsd = {
    description = "Collabora Online Development Edition (CODE)";

    wantedBy = [ "multi-user.target" ];

    wants = [ "languagetool.service" ];
    after = [ "network.target" "languagetool.service" ];

    # --use-env-vars makes coolwsd consume the aliasgroup1 env var for the WOPI
    # host allowlist (same mechanism the stock NixOS collabora module uses).
    environment = {
      HOME = "/var/lib/cool";
      aliasgroup1 = "https://webmail.${domain}:443";
    };

    serviceConfig = {
      User = "cool";
      Group = "cool";

      StateDirectory = "cool";
      RuntimeDirectory = "cool";

      WorkingDirectory = "/var/lib/cool";

      ExecStart = [
        "${collaboraCode}/bin/collabora-online-code"
        "--port=9980"
        "--use-env-vars"

        # Caddy owns TLS.
        "--o:ssl.enable=false"
        "--o:ssl.termination=true"

        # Keep CODE private; Caddy is the only public entry point.
        "--o:net.listen=loopback"

        "--o:server_name=office.${domain}"

        # We only need English writing aids.
        "--o:allowed_languages=en_US"

        # Native LanguageTool integration.
        "--o:languagetool.enabled=true"
        "--o:languagetool.base_url=http://127.0.0.1:${toString languagetoolPort}/v2"

        # ---------------------------------------------------------------------
        # AI
        #
        # 26.04 expects a provider base URL which supports /v1/chat/completions,
        # so do NOT append /v1 here.
        # ---------------------------------------------------------------------
        "--o:ai.enabled=true"
        "--o:ai.allow_user_settings=true"
        "--o:ai.api_url=https://inference-api.nousresearch.com"
        "--o:ai.model=~deepseek/deepseek-v4-flash-latest"
        # ai.api_key deliberately unset — see header comment.

        # Single-user server tuning.
        "--o:num_prespawn_children=1"
        "--o:memproportion=40"

        "--o:admin_console.enable=false"
      ];

      KillMode = "mixed";
      KillSignal = "SIGINT";

      Restart = "always";
      RestartSec = "2s";

      TimeoutStopSec = 120;
      LimitNOFILE = "infinity:infinity";
    };
  };
}
