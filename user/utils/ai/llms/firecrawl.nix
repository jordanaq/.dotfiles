# Self-hosted Firecrawl (rootless Docker, per-user systemd service).
#
# Mirrors the gbrain.nix pattern: copies the compose into ~/.config/firecrawl,
# generates per-host secrets once into ~/.config/firecrawl/.env (chmod 600),
# and runs the stack as a `firecrawl.service` user unit that Requires the
# rootless `docker.service`.
{ config, pkgs, lib, ... }:

let
  cfgDir = "${config.home.homeDirectory}/.config/firecrawl";
  envFile = "${cfgDir}/.env";
  composeFile = "${cfgDir}/docker-compose.yaml";
  # rootless docker-compose shells out to `docker`, so both must be on PATH.
  dockerPath = lib.makeBinPath [ pkgs.docker pkgs.docker-compose ];

  # `docker compose` talks to the rootless daemon socket explicitly.
  up = pkgs.writeShellScript "firecrawl-up" ''
    set -euo pipefail
    export PATH="${dockerPath}:$PATH"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
    exec ${lib.getExe pkgs.docker-compose} \
      --env-file ${lib.escapeShellArg envFile} \
      -f ${lib.escapeShellArg composeFile} up
  '';

  down = pkgs.writeShellScript "firecrawl-down" ''
    set -euo pipefail
    export PATH="${dockerPath}:$PATH"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
    ${lib.getExe pkgs.docker-compose} \
      --env-file ${lib.escapeShellArg envFile} \
      -f ${lib.escapeShellArg composeFile} down
  '';

in {
  # Committed compose (no secrets — uses ${...} interpolation).
  home.file.".config/firecrawl/docker-compose.yaml".source =
    ./firecrawl/docker-compose.yaml;

  # Generate secrets once; never overwrite an existing file (so a
  # `home-manager switch` does not rotate live credentials).
  # Written with printf (no heredoc) to avoid Nix ''-string indentation
  # mangling the heredoc terminator.
  home.activation.firecrawlSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg cfgDir}
    chmod 700 ${lib.escapeShellArg cfgDir}
    # Host-derived values (not secrets): resolved fresh on every activation so
    # an IP change self-heals instead of leaving a stale endpoint in .env.
    host_ip=$(ip -4 addr show scope global 2>/dev/null | awk '/inet/{print $2}' | head -1 | cut -d/ -f1)
    [ -z "$host_ip" ] && host_ip=127.0.0.1
    if [ ! -f ${lib.escapeShellArg envFile} ]; then
      pg=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
      rbmq=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
      bull=$(head -c 24 /dev/urandom | base64 | tr -d '/+=')
      printf '%s\n' \
        "PORT=3002" \
        "INTERNAL_PORT=3002" \
        "USE_DB_AUTHENTICATION=false" \
        "POSTGRES_USER=firecrawl" \
        "POSTGRES_DB=firecrawl" \
        "POSTGRES_PASSWORD=$pg" \
        "RABBITMQ_USER=firecrawl" \
        "RABBITMQ_PASSWORD=$rbmq" \
        "BULL_AUTH_KEY=$bull" \
        "BLOCK_MEDIA=false" \
        "ALLOW_LOCAL_WEBHOOKS=false" \
        "MAX_CPU=0.8" \
        "MAX_RAM=0.8" \
        # LLM via the Nous Portal (OpenAI-compatible inference API). Firecrawl
        # hardcodes provider="openai" for its extract/summary/query paths, so the
        # LLM rides on OPENAI_BASE_URL. OPENAI_API_KEY is a SECRET: leave it
        # empty here, then set it in this generated .env (chmod 600, git-ignored)
        # after first activation. Home-manager never overwrites an existing .env.
        "MODEL_PROVIDER=openai" \
        # Rolling deepseek-v4-flash (NOT the -0731 snapshot): the 0731 snapshot
        # is served by Novita and rejects structured output, which Firecrawl's
        # LLM extraction requires. The rolling alias supports it (2026-08-12).
        "MODEL_NAME=deepseek/deepseek-v4-flash" \
        "MODEL_EMBEDDING_NAME=google/gemini-embedding-2" \
        "OPENAI_BASE_URL=https://inference-api.nousresearch.com/v1" \
        "OPENAI_API_KEY=" \
        > ${lib.escapeShellArg envFile}
      chmod 600 ${lib.escapeShellArg envFile}
    fi
    # Always refresh the SearXNG endpoint (host-derived) without touching the
    # once-only secrets above, so a LAN IP change self-heals on next switch.
    sed -i '/^SEARXNG_ENDPOINT=/d' ${lib.escapeShellArg envFile} 2>/dev/null || true
    printf 'SEARXNG_ENDPOINT=http://%s:8888\n' "$host_ip" >> ${lib.escapeShellArg envFile}
  '';

  systemd.user.services.firecrawl = {
    Unit = {
      Description = "Self-hosted Firecrawl (rootless Docker)";
      After = [ "docker.service" "network-online.target" ];
      Requires = [ "docker.service" ];
      PartOf = [ "docker.service" ];
    };

    Service = {
      Type = "simple";
      ExecStart = up;
      ExecStop = down;
      Restart = "on-failure";
      RestartSec = 10;
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
