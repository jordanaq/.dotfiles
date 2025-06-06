{ pkgs, ... }:

{
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
    grim
    slurp
    wf-recorder
    light
    yad
    geany
    mpv
    mpd
    mpc
    viewnior
    imagemagick
    polkit
    xdg-desktop-portal-wlr
    playerctl
    pastel
    pywal
    kitty
    rofi
    pulsemixer

    # fonts
    icomoon-feather
    nerd-fonts.symbols-only
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
  ];

  home.file.".config/hypr" = {
    source = ./hypr;
    recursive = true;
  };

  home.file.".local/share/fonts/Archcraft.ttf".source = ./fonts/Archcraft.ttf;

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''
      # unused
    '';
  };
}
