# Tailscale systray — the tray toggle for the private link to tsiru-cloud.
#
# `tailscale systray` is the OFFICIAL Linux tray client (beta, v1.88+): connect /
# disconnect, account switching, exit-node selection. It is only a front-end to
# the same `tailscaled` daemon, installed by system/tailscale.nix — so nothing
# here works until that module is switched in AND `sudo tailscale up` has been
# run once on this machine (that one-time step is also what the tray needs, since
# it talks to the daemon socket as the `--operator` user).
#
# The icon appears in waybar's tray module, already enabled in
# user/gui/hyprland/hypr/waybar/config ("tray" in modules-center).
# Optional extra flags: --theme dark|dark:nobg|light|light:nobg

{ pkgs, ... }:

{
  systemd.user.services.tailscale-systray = {
    Unit = {
      Description = "Tailscale systray (tray toggle for the tsiru-cloud link)";
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      # Absolute store path on purpose: this must be the SAME build as the system
      # daemon (services.tailscale.package defaults to pkgs.tailscale), and the
      # user manager's PATH isn't guaranteed to carry /run/current-system/sw/bin.
      ExecStart = "${pkgs.tailscale}/bin/tailscale systray";
      Restart = "on-failure";
      RestartSec = 3;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
