# notes-site — build and publish https://notes.<domain> on the box itself.
#
# The site is a Quartz export of the vault's Concepts/ folder. The vault lives
# on the desktop, but its bare git remote lives HERE
# (~/Documents/Obsidian-Vault.git), so the box can clone from a local path and
# needs no credentials: the publish is pull -> build -> rsync into the docroot
# Caddy serves (see ./caddy.nix).
#
# Trigger: notes-publish.service is a long-running daemon (Type=simple,
# Restart=always) — ACTIVE from power-on — that republishes every INTERVAL
# seconds (default 300). The publisher exits early unless the vault's HEAD
# moved, so an idle box pays one `git fetch` per interval.
#
# (A oneshot + RemainAfterExit would also read "active", but it would never
# publish again: a start request on an already-active unit is a no-op.)
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

  # The always-on driver; `publish` lands on its PATH via runtimeInputs.
  run = pkgs.writeShellApplication {
    name = "notes-publish-run";
    runtimeInputs = [ publish pkgs.bash pkgs.coreutils ];
    text = builtins.readFile ./notes-site-run.sh;
  };
in
{
  # Build scratch (vault clone + Quartz + node_modules) and the served docroot.
  # Owned by `tsiru` — NOT root — so the vault repo and the clone share the
  # service's user. git refuses to touch a repo owned by someone else
  # ("detected dubious ownership", exit 128) and the only ways around that are a
  # global safe.directory or the blunt `safe.directory=*`; running as the owner
  # removes the problem instead of overriding it. Caddy reads these
  # world-readable (0755 dirs / 0644 files, the default umask).
  systemd.tmpfiles.rules = [
    "d /var/lib/notes-build 0755 tsiru users -"
    "d /var/lib/notes-site 0755 tsiru users -"
  ];

  systemd.services.notes-publish = {
    description = "Build + publish the vault's public notes to notes.<domain>";

    # START AT POWER-ON and stay running.
    wantedBy = [ "multi-user.target" ];

    # Needs the network for the first `npm ci` (npm registry) and for git.
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${run}/bin/notes-publish-run ${quartzSrc} ${quartzConfig}";
      # Long-lived by design: if the loop ever exits (a failed publish), come
      # back automatically.
      Restart = "always";
      RestartSec = 60;
      # Run as the vault's owner: no root needed (it only writes under /var/lib,
      # which tmpfiles hands to this user) and no cross-user git ownership.
      # NOTE: no Group= — the box has NO `tsiru` group (uid 1000, gid 100
      # `users`), and systemd exits 216/GROUP when the group can't be resolved.
      # Omitting it makes systemd use the user's primary group.
      User = "tsiru";
      # Seconds between republish attempts. The vault's HEAD is checked first, so
      # a quiet vault costs one `git fetch` per tick.
      Environment = [
        "INTERVAL=300"
        # ProtectHome=read-only below means /root and /home are not usable as a
        # cache, and npm/git both want $HOME. Point them at the scratch dir.
        "HOME=/var/lib/notes-build"
        "npm_config_cache=/var/lib/notes-build/.npm"
      ];
      # Hardening: writes only under /var/lib; the vault repo is read-only input.
      ProtectHome = "read-only";
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/notes-build" "/var/lib/notes-site" ];
      PrivateTmp = true;
    };
  };
}
