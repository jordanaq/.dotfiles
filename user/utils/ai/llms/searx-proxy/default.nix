# SearXNG remote proxy: tiny local forwarder that adds basic-auth.
# The server's SearXNG (search.tsiru.pet) sits behind Caddy basic_auth; the
# proxy adds the credentials from a local secrets file. It accepts loopback
# clients and the host address used by rootless Firecrawl.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfgDir = "${config.home.homeDirectory}/.config/searx-proxy";
  envFile = "${cfgDir}/secrets.env";
  hostIp = import ./host-ip.nix { inherit pkgs; };

  pkg = pkgs.rustPlatform.buildRustPackage {
    pname = "searx-proxy";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
    };
    cargoLock.lockFile = ./Cargo.lock;
    meta.mainProgram = "searx-proxy";
  };
  start = pkgs.writeShellScript "searx-proxy-start" ''
    export FIRECRAWL_HOST_IP=$(${hostIp})
    exec ${lib.getExe pkg}
  '';
in {
  home.packages = [pkg];

  # Generate the secrets placeholder once; never overwrite (chmod 600,
  # git-ignored — outside the dotfiles repo). User fills in BASIC_PASS by hand.
  home.activation.searxProxySecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${lib.escapeShellArg cfgDir}
    chmod 700 ${lib.escapeShellArg cfgDir}
    if [ ! -f ${lib.escapeShellArg envFile} ]; then
      umask 077
      printf 'BASIC_USER=tsiru\nBASIC_PASS=CHANGE-ME\nUPSTREAM=https://search.tsiru.pet\n' > ${lib.escapeShellArg envFile}
      chmod 600 ${lib.escapeShellArg envFile}
    fi
  '';

  systemd.user.services.searx-proxy = {
    Unit = {
      Description = "Local auth-forwarding proxy to search.tsiru.pet";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${start}";
      EnvironmentFile = envFile;
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };
}
