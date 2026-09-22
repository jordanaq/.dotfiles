# Collabora Online Development Edition (CODE) 26.04 — in-browser office editor
# for Bulwark's Files (WOPI) at office.<domain>.
#
# CODE is packaged from Collabora's official AppImage in ./collabora-code.nix
# (NOT the nixpkgs collabora-online module, which is still 25.04 and lacks the
# AI assistant). Caddy terminates TLS and proxies [::1]:9983 (the AppImage's
# AppRun hardcodes --port=9983; net.listen=loopback = IPv6 loopback). Bulwark
# (webmail.<domain>) is the WOPI host that mints the token and serves the file.
#
# LanguageTool lives in ./languagetool.nix (native NixOS service, listens on
# all interfaces but confined to the tailnet by the firewall — only Collabora
# and tailnet peers reach it); the port it binds is read here from
# config.services.languagetool.port.
#
# AI provider defaults to Nous Portal / DeepSeek V4 Flash Latest. The API key is
# intentionally NOT stored here (or in git / the nix store): the coolwsd unit
# reads it at runtime from /etc/secrets/coolwsd.env as COLLABORA_AI_API_KEY
# (systemd EnvironmentFile → ${...} expansion in ExecStart). This replaces the
# earlier WOPI-UserPrivateInfo injection, which required patching Bulwark's
# prebuilt turbopack chunk (fragile — reverted 2026-09-19).
{
  config,
  lib,
  pkgs,
  domain,
  ...
}:

let
  collaboraCode = pkgs.callPackage ./collabora-code.nix { };

  # Nous Portal's OpenAI-compatible endpoint. Must be admitted to Collabora's
  # outbound host allowlist (net.lok_allow / net.post_allow) or the AI sidebar
  # fails with "Target host is not in the allowed host list".
  aiEndpointHost = "inference-api.nousresearch.com";

  # 8081 is already used by calibre-server; the LanguageTool module chose 8091
  # there (./languagetool.nix) — read it back so this URL can't drift.
  languagetoolPort = config.services.languagetool.port;
in
{
  imports = [
    ./languagetool.nix
  ];

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
      # AI API key lives ONLY here (0600), never git/nix-store. Feed it to the
      # --o:ai.api_key arg below via ${} expansion. The leading "-" makes a
      # MISSING file non-fatal (systemd would otherwise refuse to start the
      # unit — crash-loop "Failed to load environment files"). Office must run
      # even before the secret exists; AI stays unconfigured until it does.
      EnvironmentFile = [ "-/etc/secrets/coolwsd.env" ];

      User = "cool";
      Group = "cool";

      StateDirectory = "cool";
      RuntimeDirectory = "cool";

      WorkingDirectory = "/var/lib/cool";

      # This nixpkgs rev does NOT join an ExecStart LIST into one command (that's
      # a newer-Nixpkgs behaviour); a list here emits repeated ExecStart= lines,
      # which systemd rejects ("bad unit file setting" — max one ExecStart= per
      # unit). So build a single escaped string from the arg list.
      ExecStart = lib.concatStringsSep " " (map lib.escapeShellArg [
        "${collaboraCode}/bin/collabora-online-code"
        # NOTE: no --port here. The CODE AppImage's AppRun launcher passes its
        # OWN --port=9983 (it's built as Nextcloud-embedded CODE, not a 9980
        # standalone); adding --port here makes coolwsd exit with
        # "Option must not be given more than once: port". So the listener is
        # 9983 → Caddy proxies office.<domain> to [::1]:9983.
        "--use-env-vars"

        # Caddy owns TLS.
        "--o:ssl.enable=false"
        "--o:ssl.termination=true"

        # Keep CODE private; Caddy is the only public entry point.
        "--o:net.listen=loopback"

        # The AppImage forces net.proxy_prefix=true; that breaks the plain
        # Caddy reverse_proxy (URLs come out double-prefixed). Override to false.
        "--o:net.proxy_prefix=false"

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

        # Admit the AI provider's host to the engine's OUTBOUND host allowlist.
        # Without this the AI sidebar errors "Target host is not in the allowed
        # host list". Appended at index 14 (lok_allow) / 13 (post_allow) to ADD
        # to the stock defaults (14/13 entries) without clobbering loopback and
        # the private ranges that LanguageTool/localhost rely on.
        "--o:net.lok_allow.host[14]=${aiEndpointHost}"
        "--o:net.post_allow.host[13]=${aiEndpointHost}"
        # Key from /etc/secrets/coolwsd.env via systemd EnvironmentFile (${}
        # expansion happens in systemd before shell/exec, so it stays out of the
        # nix store AND out of git). File: COLLABORA_AI_API_KEY=<sk-...>
        "--o:ai.api_key=\${COLLABORA_AI_API_KEY}"

        # Single-user server tuning.
        "--o:num_prespawn_children=1"
        "--o:memproportion=40"

        "--o:admin_console.enable=false"
      ]);

      KillMode = "mixed";
      KillSignal = "SIGINT";

      Restart = "always";
      RestartSec = "2s";

      TimeoutStopSec = 120;
      LimitNOFILE = "infinity:infinity";
    };
  };
}