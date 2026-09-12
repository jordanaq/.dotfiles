# notes-site — keep https://notes.tsiru.pet in sync with the vault.
#
# Publishes the vault's Concepts/ folder as a static Quartz site. The BUILD runs
# here on the desktop (the vault lives here and is not on the server); the export
# is rsynced to the box, where Caddy serves it (see cloud-server/system/caddy.nix,
# docroot /var/lib/notes-site — owned by `tsiru` via systemd-tmpfiles, so no sudo).
#
# Why a timer + content hash instead of a systemd .path unit: `.path` watches a
# single path non-recursively, while the vault is a deep tree edited by Obsidian
# (which also churns `.obsidian/`). The timer re-hashes every 5 min and publishes
# only on a real change — one `sha256sum` pass when idle, and no half-written
# publishes while you are mid-typing.
#
# Rebuild to activate:  home-manager switch --flake ~/.dotfiles?submodules=1 -b backup
{ pkgs, ... }:

let
  publish = pkgs.writeShellApplication {
    name = "notes-publish";
    runtimeInputs = with pkgs; [ bash coreutils findutils nodejs rsync openssh ];
    text = builtins.readFile ./publish-notes.sh;
  };
in
{
  systemd.user.services.notes-publish = {
    Unit = {
      Description = "Publish vault Concepts/ notes to notes.tsiru.pet";
      # Publishing mid-session is harmless, but wait for the network.
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${publish}/bin/notes-publish";
      # The first run after a switch has no recorded hash, so it publishes once.
      TimeoutStartSec = "10min";
    };

    # No Install.WantedBy: driven by notes-publish.timer, not at login.
  };

  systemd.user.timers.notes-publish = {
    Unit.Description = "Check the vault for note changes every 5 minutes";

    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      # Catch up if the desktop was off while the vault changed.
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
