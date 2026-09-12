# SearXNG remote proxy: tiny local forwarder that adds basic-auth.
# The server's SearXNG (search.tsiru.pet) sits behind Caddy basic_auth; the
# desktop consumers (opencode, Firecrawl) cannot send auth headers. This
# proxy listens loopback-only on :8889 and forwards every request verbatim,
# adding the Authorization header from a git-ignored secrets file.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfgDir = "${config.home.homeDirectory}/.config/searx-proxy";
  envFile = "${cfgDir}/secrets.env";

  # systemd unit needs the binary path; package defined below.
  pkg = pkgs.rustPlatform.buildRustPackage {
    pname = "searx-proxy";
    version = "0.1.0";
    src = ./searx-proxy;
    cargoLock.lockFile = ./searx-proxy/Cargo.lock;
    meta.mainProgram = "searx-proxy";
  };
in {
  home.packages = [pkg];

  # Generate the secrets placeholder once; never overwrite (chmod 600,
  # git-ignored — outside the dotfiles repo). User fills in BASIC_PASS by hand.
  home.activation.searxProxySecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${lib.escapeShellArg cfgDir}
    chmod 700 ${lib.escapeShellArg cfgDir}
    if [ ! -f ${lib.escapeShellArg envFile} ]; then
      umask 077
      printf 'BASIC_USER=tsiru\nBASIC_PASS=CHANGE-ME\nUPSTREAM=https://search.tsiru.pet\nBIND=0.0.0.0:8889\n' > ${lib.escapeShellArg envFile}
      chmod 600 ${lib.escapeShellArg envFile}
    fi
  '';

  systemd.user.services.searx-proxy = {
    Unit = {
      Description = "Loopback auth-forwarding proxy to search.tsiru.pet";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe pkg}";
      EnvironmentFile = envFile;
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };
}
