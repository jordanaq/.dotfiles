{ pkgs, inputs, system, ... }:


let
  # hyprland = inputs.hyprland;
  hyprland-plugins = inputs.hyprland-plugins;
in {
  home.packages = with pkgs; [
    swaybg
    swayidle
    swaylock
    wlroots
    wl-clipboard
    waybar
    wofi
    foot
    mako
    jq
    grim
    slurp
    wf-recorder
    # light
    yad
    geany
    mpv
    mpd
    mpc
    viewnior
    imagemagick
    polkit
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
    kdePackages.qtwayland
    playerctl
    pastel
    pywal
    kitty
    rofi
    pulsemixer

    # fonts
    icomoon-feather
    jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome
    material-design-icons
  ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  fonts.fontconfig.enable = true;

  xdg.configFile."hypr".source = ./hypr;
  xdg.configFile.".local/share/fonts/Archcraft.ttf".source = ./hypr/fonts/Archcraft.ttf;

  wayland.windowManager.hyprland = {
    enable = true;
    # package = hyprland.packages.${system}.hyprland;

    configType = "hyprlang";

    plugins = with hyprland-plugins.packages.${system}; [
      csgo-vulkan-fix
    ];

    extraConfig = ''
      # unused
    '';
  };

  # GNOME polkit authentication agent, tied to the graphical session.
  # The hypr startup script used to call /usr/lib/xfce-polkit/xfce-polkit,
  # an Archcraft path that does not exist on NixOS, so Hyprland sessions had
  # no polkit agent at all and every privileged prompt would fail. Running it
  # as a unit instead means it starts and stops with graphical-session.target
  # (activated by UWSM) rather than being fired blind from a shell script.
  systemd.user.services.polkit-gnome = {
    Unit = {
      Description = "GNOME PolicyKit authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.portal = {
    enable = true;
    config.common = {
      default = [ "hyprland" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal
      xdg-desktop-portal-gtk
    ];
  };
}
