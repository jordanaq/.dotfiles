{ config, inputs, lib, pkgs, ... }:

let
  gbrainSource = inputs.gbrain-src;
  gbrainRuntimeDir = "${config.home.homeDirectory}/.local/share/gbrain/runtime";
  gbrainSecretsFile = "${config.home.homeDirectory}/.config/gbrain/secrets.env";
  gbrainAutopilotRepo = "${config.home.homeDirectory}/brain";
  gbrainShellPath = lib.makeBinPath [
    pkgs.bun
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
  ];

  gbrainPackage = pkgs.writeShellScriptBin "gbrain" ''
    set -euo pipefail

    runtime_dir=${lib.escapeShellArg gbrainRuntimeDir}
    if [ ! -f "$runtime_dir/src/cli.ts" ]; then
      echo "gbrain runtime is not installed yet. Start systemd user service gbrain-runtime.service or run home-manager switch." >&2
      exit 1
    fi

    export BUN_INSTALL=${lib.escapeShellArg "${config.home.homeDirectory}/.bun"}
    export PATH="${gbrainShellPath}:$BUN_INSTALL/bin:$PATH"

    # Local-only secrets: keep API keys outside the dotfiles repo.
    gbrain_secrets_file=${lib.escapeShellArg gbrainSecretsFile}
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
    if [ -f "${gbrainSecretsFile}" ]; then
      chmod 600 "${gbrainSecretsFile}"
    fi
  '';

  home.packages = [
    gbrainPackage
    pkgs.python3Packages.huggingface-hub
  ];

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
        "PATH=${gbrainShellPath}:${config.home.homeDirectory}/.bun/bin"
        "GBRAIN_RUNTIME_DIR=${gbrainRuntimeDir}"
        "GBRAIN_SOURCE=${gbrainSource}"
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
        gbrain_runtime=${lib.escapeShellArg gbrainRuntimeDir}
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
      ExecStart = "${lib.getExe gbrainPackage} autopilot --repo ${gbrainAutopilotRepo}";
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
