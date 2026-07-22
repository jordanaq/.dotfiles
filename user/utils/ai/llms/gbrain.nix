# GBrain and Hermes agent services.
#
# Owns the `gbrain` wrapper script, the home activation hook for secrets
# permissions, and the four systemd user services: `hermes-gateway`,
# `gbrain-runtime`, `gbrain-hermes-skills`, and `gbrain-autopilot`.
{ config, inputs, lib, pkgs, system, ... }:

let
  common = import ../common.nix { inherit config inputs lib pkgs system; };

  gbrainPackage = pkgs.writeShellScriptBin "gbrain" ''
    set -euo pipefail

    runtime_dir=${lib.escapeShellArg common.gbrainRuntimeDir}
    if [ ! -f "$runtime_dir/src/cli.ts" ]; then
      echo "gbrain runtime is not installed yet. Start systemd user service gbrain-runtime.service or run home-manager switch." >&2
      exit 1
    fi

    export BUN_INSTALL=${lib.escapeShellArg "${config.home.homeDirectory}/.bun"}
    export PATH="${common.gbrainShellPath}:$BUN_INSTALL/bin:$PATH"

    # Local-only secrets: keep API keys outside the dotfiles repo.
    gbrain_secrets_file=${lib.escapeShellArg common.gbrainSecretsFile}
    if [ -f "$gbrain_secrets_file" ]; then
      # shellcheck disable=SC1090
      . "$gbrain_secrets_file"
      export ZEROENTROPY_API_KEY="''${ZEROENTROPY_API_KEY:-}"
    fi

    exec ${lib.getExe pkgs.bun} "$runtime_dir/src/cli.ts" "$@"
  '';
in {
  home.activation.gbrainSecretsPerms = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.home.homeDirectory}/.config/gbrain"
    chmod 700 "${config.home.homeDirectory}/.config/gbrain"
    if [ -f "${common.gbrainSecretsFile}" ]; then
      chmod 600 "${common.gbrainSecretsFile}"
    fi
  '';

  home.packages = [
    gbrainPackage
    common.hermesPackage
    inputs.hermes-agent.packages.${system}.desktop
    pkgs.python3Packages.huggingface-hub
    # Browser automation backend for Hermes' `browser` toolset.
    # `chromium` provides the Nix-wrapped browser binary so agent-browser
    # doesn't have to dynamically load generic-Linux shared libraries that
    # NixOS doesn't have. `agent-browser` is the Node CLI the tool spawns.
    pkgs.chromium
    pkgs.agent-browser
  ];

  # Pin agent-browser to the Nix-wrapped Chromium so it bypasses its own
  # Chrome download (which produces a dynamically-linked binary that cannot
  # run on NixOS). Propagates to login shells and to all systemd user
  # services, including `hermes-gateway`.
  home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH =
    "${pkgs.chromium}/bin/chromium";

  home.file.".hermes/config.yaml".source = ../hermes-config.yaml;

  systemd.user.services.hermes-gateway = {
    Unit = {
      Description = "Hermes Agent gateway";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe common.hermesPackage} gateway run --replace";
      Restart = "on-failure";
      RestartSec = 5;
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.gbrain-runtime = {
    Unit = {
      Description = "Install pinned GBrain runtime for Hermes";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      Environment = [
        "BUN_INSTALL=${config.home.homeDirectory}/.bun"
        "PATH=${common.gbrainShellPath}:${config.home.homeDirectory}/.bun/bin"
        "GBRAIN_RUNTIME_DIR=${common.gbrainRuntimeDir}"
        "GBRAIN_SOURCE=${common.gbrainSource}"
      ];
      ExecStart = pkgs.writeShellScript "gbrain-runtime-install" ''
        set -euo pipefail

        runtime_dir="$GBRAIN_RUNTIME_DIR"
        source_dir="$GBRAIN_SOURCE"
        source_stamp="$runtime_dir/.nix-source"
        wanted_source="$source_dir"
        current_source=""

        if [ -f "$source_stamp" ]; then
          current_source="$(cat "$source_stamp")"
        fi

        if [ ! -f "$runtime_dir/src/cli.ts" ] || [ "$current_source" != "$wanted_source" ]; then
          rm -rf "$runtime_dir"
          mkdir -p "$(dirname "$runtime_dir")"
          cp -R "$source_dir" "$runtime_dir"
          chmod -R u+w "$runtime_dir"
        fi

        if [ ! -d "$runtime_dir/node_modules" ] || [ "$current_source" != "$wanted_source" ]; then
          cd "$runtime_dir"
          ${lib.getExe pkgs.bun} install --frozen-lockfile --ignore-scripts
        fi

        printf '%s\n' "$wanted_source" > "$source_stamp"
      '';
      WorkingDirectory = config.home.homeDirectory;
    };

    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.gbrain-hermes-skills = {
    Unit = {
      Description = "Scaffold GBrain skills into Hermes";
      After = [ "gbrain-runtime.service" ];
      Requires = [ "gbrain-runtime.service" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "gbrain-hermes-skills" ''
        set -euo pipefail

        hermes_home=${lib.escapeShellArg "${config.home.homeDirectory}/.hermes"}
        gbrain_runtime=${lib.escapeShellArg common.gbrainRuntimeDir}
        skills_resolver="$hermes_home/skills/RESOLVER.md"

        if [ -f "$skills_resolver" ]; then
          exit 0
        fi

        mkdir -p "$hermes_home"
        cd "$gbrain_runtime"
        ${lib.getExe gbrainPackage} skillpack scaffold --all --workspace "$hermes_home" --trust
      '';
      WorkingDirectory = config.home.homeDirectory;
    };

    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.gbrain-autopilot = {
    Unit = {
      Description = "GBrain Autopilot";
      Wants = [ "network-online.target" "gbrain-runtime.service" ];
      After = [ "network-online.target" "gbrain-runtime.service" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe gbrainPackage} autopilot --repo ${common.gbrainAutopilotRepo}";
      Restart = "always";
      RestartSec = 30;
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
