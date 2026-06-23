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
