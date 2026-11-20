# Self-hosted Firecrawl under rootless Docker.
{ config, pkgs, lib, ... }:

let
  cfgDir = "${config.home.homeDirectory}/.config/firecrawl";
  envFile = "${cfgDir}/.env";
  composeFile = "${cfgDir}/docker-compose.yaml";
  searxProxyHostIp = import ../searx-proxy/host-ip.nix { inherit pkgs; };
  # rootless docker-compose shells out to `docker`, so both must be on PATH.
  # curl is needed by the watchdog probe.
  dockerPath = lib.makeBinPath [ pkgs.docker pkgs.docker-compose pkgs.curl ];

  # `docker compose` talks to the rootless daemon socket explicitly.
  # Rootless-Docker custom bridges die silently (stale veth/gateway -> dead DNS,
  # no NAT out). `docker compose up` won't recreate already-running containers,
  # so always tear down + rebuild with --force-recreate. `down` keeps named
  # volumes (no -v), so data is safe.
  up = pkgs.writeShellScript "firecrawl-up" ''
    set -euo pipefail
    export PATH="${dockerPath}:$PATH"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
    ${lib.getExe pkgs.docker-compose} \
      --env-file ${lib.escapeShellArg envFile} \
      -f ${lib.escapeShellArg composeFile} down || true
    exec ${lib.getExe pkgs.docker-compose} \
      --env-file ${lib.escapeShellArg envFile} \
      -f ${lib.escapeShellArg composeFile} up --force-recreate
  '';

  down = pkgs.writeShellScript "firecrawl-down" ''
    set -euo pipefail
    export PATH="${dockerPath}:$PATH"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
    ${lib.getExe pkgs.docker-compose} \
      --env-file ${lib.escapeShellArg envFile} \
      -f ${lib.escapeShellArg composeFile} down
  '';

  # Watchdog: if the API is listening but the container can no longer resolve
  # public DNS, the Docker bridge is dead (the incident we hit) -> restart the
  # unit, whose `up` now tears down and rebuilds the network. Only fires on a
  # live-but-broken stack; the main unit owns startup when the API is down.
  watchdog = pkgs.writeShellScript "firecrawl-watchdog" ''
    set -euo pipefail
    export PATH="${dockerPath}:$PATH"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
    if ! ${lib.getExe pkgs.curl} -sf -m 5 http://localhost:3002/ >/dev/null 2>&1; then
      exit 0
    fi
    if ! docker exec firecrawl-api-1 getent hosts en.wikipedia.org >/dev/null 2>&1; then
      systemctl --user restart firecrawl.service
    fi
  '';

in {
  # Committed compose (no secrets — uses ${...} interpolation).
  home.file.".config/firecrawl/docker-compose.yaml".source =
    ./docker-compose.yaml;

  # Generate secrets once; never overwrite an existing file (so a
  # `home-manager switch` does not rotate live credentials).
  # Written with printf (no heredoc) to avoid Nix ''-string indentation
  # mangling the heredoc terminator.
  home.activation.firecrawlSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg cfgDir}
    chmod 700 ${lib.escapeShellArg cfgDir}
    host_ip=$(${searxProxyHostIp})
    [ -z "$host_ip" ] && host_ip=127.0.0.1
    if [ ! -f ${lib.escapeShellArg envFile} ]; then
      pg=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
      rbmq=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
      bull=$(head -c 24 /dev/urandom | base64 | tr -d '/+=')
      # Firecrawl's extraction tools use the OpenAI-compatible Nous endpoint.
      # Set OPENAI_API_KEY in the generated .env after first activation.
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
        "MODEL_PROVIDER=openai" \
        "MODEL_NAME=deepseek/deepseek-v4-flash" \
        "MODEL_EMBEDDING_NAME=google/gemini-embedding-2" \
        "OPENAI_BASE_URL=https://inference-api.nousresearch.com/v1" \
        "OPENAI_API_KEY=" \
        > ${lib.escapeShellArg envFile}
      chmod 600 ${lib.escapeShellArg envFile}
    fi
    # Rootless Docker reaches the local SearXNG proxy via the host's LAN IP.
    # Refresh the endpoint on activation and clear the retired Ollama URL.
    sed -i '/^SEARXNG_ENDPOINT=/d; /^OLLAMA_BASE_URL=/d; s/^MODEL_PROVIDER=ollama$/MODEL_PROVIDER=openai/' ${lib.escapeShellArg envFile}
    printf 'SEARXNG_ENDPOINT=http://%s:8889\n' "$host_ip" >> ${lib.escapeShellArg envFile}
  '';

  systemd.user.services.firecrawl = {
    Unit = {
      Description = "Self-hosted Firecrawl (rootless Docker)";
      After = [ "docker.service" "network-online.target" "searx-proxy.service" ];
      Wants = [ "searx-proxy.service" ];
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

  # Watchdog timer: every 5 min, if the API is up but the container's DNS is
  # dead (dead Docker bridge), restart firecrawl.service to rebuild the network.
  systemd.user.services.firecrawl-watchdog = {
    Unit.Description = "Restart firecrawl if its Docker bridge/DNS dies";
    Service = { Type = "oneshot"; ExecStart = watchdog; };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.timers.firecrawl-watchdog = {
    Unit.Description = "Periodic firecrawl bridge/DNS watchdog";
    Timer = { OnBootSec = "2min"; OnUnitActiveSec = "5min"; };
    Install.WantedBy = [ "timers.target" ];
  };
}
