# notes-site — build and publish https://notes.<domain> (Quartz export of the vault's Concepts/).
#
# Build-publish state model: pull -> build -> rsync into Caddy's docroot. The vault's
# bare git remote lives on this box, so cloning needs no credentials. A note is
# published only once PUSHED to that remote (publish follows push, not edits).
# Trigger: notes-publish.service is a long-running daemon (NOT oneshot — starting an
# already-active oneshot unit is a no-op) that republishes every INTERVAL sec
# (default 300), paying one `git fetch` only when the vault HEAD moved.
{ pkgs, inputs, ... }:

let
  # Pinned Quartz v5 flake input + repo config: single source of truth for the site.
  quartzSrc = inputs.quartz;
  quartzConfig = ./quartz.config.yaml;
  # Landing page: Concepts/ has no index.md, so `/` 404s without it. Build clone only.
  notesIndex = ./index.md;

  publish = pkgs.writeShellApplication {
    name = "notes-publish";
    runtimeInputs = with pkgs; [ bash coreutils findutils git nodejs rsync ];
    text = builtins.readFile ./publish.sh;
  };

  # Always-on driver; `publish` lands on its PATH via runtimeInputs.
  run = pkgs.writeShellApplication {
    name = "notes-publish-run";
    runtimeInputs = [ publish pkgs.bash pkgs.coreutils ];
    text = builtins.readFile ./run.sh;
  };
in
{
  # Build scratch + served docroot, owned by tsiru (not root): service and vault repo
  # share the owner, avoiding git's "dubious ownership" failure. Caddy reads world-readable.
  systemd.tmpfiles.rules = [
    "d /var/lib/notes-build 0755 tsiru users -"
    "d /var/lib/notes-site 0755 tsiru users -"
  ];

  systemd.services.notes-publish = {
    description = "Build + publish the vault's public notes to notes.<domain>";

    # Start at power-on and stay running.
    wantedBy = [ "multi-user.target" ];

    # Network needed for the first `npm ci` (npm registry) and for git.
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${run}/bin/notes-publish-run ${quartzSrc} ${quartzConfig} ${notesIndex}";
      # Restart if the loop ever exits (failed publish).
      Restart = "always";
      RestartSec = 60;
      # No root needed, and no cross-user git ownership. NO Group= (box has no `tsiru`
      # group; systemd exits 216/GROUP) — systemd uses the user's primary group.
      User = "tsiru";
      # Seconds between republish attempts; quiet vault costs one `git fetch` per tick.
      Environment = [
        "INTERVAL=300"
        # ProtectHome=read-only blocks /root,/home as cache; point npm/git $HOME at scratch.
        "HOME=/var/lib/notes-build"
        "npm_config_cache=/var/lib/notes-build/.npm"
      ];
      # Hardening: ProtectHome + ProtectSystem; writes only under /var/lib.
      ProtectHome = "read-only";
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/notes-build" "/var/lib/notes-site" ];
      PrivateTmp = true;
    };
  };
}
