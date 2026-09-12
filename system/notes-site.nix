# notes-site — build and publish https://notes.<domain> on the box itself.
#
# The site is a Quartz export of the vault's Concepts/ folder. The vault lives
# on the desktop, but its bare git remote lives HERE
# (~/Documents/Obsidian-Vault.git), so the box can clone from a local path and
# needs no credentials: the publish is pull -> build -> rsync into the docroot
# Caddy serves (see ./caddy.nix).
#
# Trigger: notes-publish.timer, every 5 minutes. The script exits early unless
# the vault's HEAD moved, so an idle box pays one `git fetch`.
#
# Publishing therefore follows the vault's PUSH, not the desktop's edits: a note
# you have not pushed to the remote is not published.
{ pkgs, inputs, ... }:

let
  # Pinned Quartz v5 tree (flake input, so the build is reproducible) plus this
  # repo's config file as the single source of truth for the site.
  quartzSrc = inputs.quartz;
  quartzConfig = ./notes-site-quartz.config.yaml;

  publish = pkgs.writeShellApplication {
    name = "notes-publish";
    runtimeInputs = with pkgs; [ bash coreutils findutils git nodejs rsync ];
    text = builtins.readFile ./notes-site-publish.sh;
  };
in
{
  # Build scratch (vault clone + Quartz + node_modules) and the served docroot.
  # `d` only creates what is missing; published files survive a rebuild.
  systemd.tmpfiles.rules = [
    "d /var/lib/notes-build 0755 root root -"
    "d /var/lib/notes-site 0755 root root -"
  ];

  systemd.services.notes-publish = {
    description = "Build + publish the vault's public notes to notes.<domain>";

    # Needs the network for the first `npm ci` (npm registry) and for git.
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${publish}/bin/notes-publish ${quartzSrc} ${quartzConfig}";
      # The first run installs node_modules and builds from scratch.
      TimeoutStartSec = "30min";
      # ProtectHome=read-only below means /root and /home are not usable as a
      # cache, and npm/git both want $HOME. Point them at the scratch dir.
      Environment = [
        "HOME=/var/lib/notes-build"
        "npm_config_cache=/var/lib/notes-build/.npm"
      ];
      # Hardening: it only ever writes under /var/lib; the vault repo is read.
      ProtectHome = "read-only";
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/notes-build" "/var/lib/notes-site" ];
      PrivateTmp = true;
    };
  };

  systemd.timers.notes-publish = {
    description = "Check the vault's git remote for new notes every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      # Catch up after downtime, so a reboot always converges.
      Persistent = true;
    };
  };
}
