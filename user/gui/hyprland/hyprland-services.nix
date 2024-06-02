{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland.systemd.extraCommands = [
    "systemctl --user start dunst.service"
    "systemctl --user start flameshot.service"
    "systemctl --user start ulauncher.service"
    "systemctl --user start plasma-polkit-agent.service"
  ];
}
