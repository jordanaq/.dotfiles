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

  # Relay launcher: forwards the host LAN IP (:8888/:11434) to the real
  # 127.0.0.1 services so the Firecrawl container can reach them under
  # rootless Docker (--disable-host-loopback). It also rewrites Ollama's
  # /chat -> /api/chat path, which Firecrawl's AI SDK omits.
  relayUp = pkgs.writeShellScript "firecrawl-relay-up" ''
    exec ${lib.getExe pkgs.python3} ${lib.escapeShellArg cfgDir}/relay.py
  '';
in {
  # Committed compose (no secrets — uses ${...} interpolation).
  home.file.".config/firecrawl/docker-compose.yaml".source =
    ./firecrawl/docker-compose.yaml;

  # Committed TCP relay that lets the Firecrawl container reach host services
  # bound to 127.0.0.1 (SearXNG/Ollama) via the host LAN IP. Managed as a
  # systemd user unit (firecrawl-relay.service) below.
  home.file.".config/firecrawl/relay.py".source =
    ./firecrawl/relay.py;

  # Generate secrets once; never overwrite an existing file (so a
  # `home-manager switch` does not rotate live credentials).
  # Written with printf (no heredoc) to avoid Nix ''-string indentation
  # mangling the heredoc terminator.
  home.activation.firecrawlSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg cfgDir}
    chmod 700 ${lib.escapeShellArg cfgDir}
    if [ ! -f ${lib.escapeShellArg envFile} ]; then
      pg=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
      rbmq=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
      bull=$(head -c 24 /dev/urandom | base64 | tr -d '/+=')
      # Under rootless Docker with --disable-host-loopback, containers reach
      # host-bound services via the host's LAN IP, not host.docker.internal /
      # the docker0 bridge. Resolve it once at activation time.
      host_ip=$(ip -4 addr show scope global 2>/dev/null | awk '/inet/{print $2}' | head -1 | cut -d/ -f1)
      [ -z "$host_ip" ] && host_ip=127.0.0.1
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
        # Local Ollama (bound 0.0.0.0) is reachable directly, but Firecrawl's
        # AI SDK posts to /chat (Ollama needs /api/chat). The relay owns a
        # distinct LAN port (11435 -> 127.0.0.1:11434) to rewrite the path.
        OLLAMA_BASE_URL=http://$host_ip:11435
        "MODEL_PROVIDER=ollama" \
        "MODEL_NAME=qwen3.6:35b-a3b" \
        "MODEL_EMBEDDING_NAME=qwen3-embedding:latest" \
        # Firecrawl hardcodes provider="openai" for its extract/summary/query
        # paths, so OLLAMA_BASE_URL alone is ignored for those. Ollama 0.30.5
        # serves the OpenAI-compatible /v1/responses + /v1/chat/completions
        # natively, so point the openai provider straight at it.
        "OPENAI_BASE_URL=http://$host_ip:11434/v1" \
        "OPENAI_API_KEY=ollama" \
        > ${lib.escapeShellArg envFile}
      chmod 600 ${lib.escapeShellArg envFile}
    fi
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

  # TCP relay (LAN IP -> 127.0.0.1) so Firecrawl reaches SearXNG/Ollama.
  # Lifecycle-bound to the Firecrawl stack.
  systemd.user.services.firecrawl-relay = {
    Unit = {
      Description = "Firecrawl host-service relay (rootless Docker)";
      After = [ "firecrawl.service" "docker.service" "network-online.target" ];
      Requires = [ "firecrawl.service" ];
      PartOf = [ "firecrawl.service" ];
    };

    Service = {
      Type = "simple";
      ExecStart = relayUp;
      Restart = "on-failure";
      RestartSec = 5;
      WorkingDirectory = cfgDir;
      Environment = [ "HOME=${config.home.homeDirectory}" ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
