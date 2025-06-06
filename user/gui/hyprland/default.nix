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
    jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    noto-fonts-extra
    font-awesome
    material-design-icons
  ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  fonts.fontconfig.enable = true;

  xdg.configFile."hypr".source = ./hypr;
  xdg.configFile.".local/share/fonts/Archcraft.ttf".source = ./hypr/fonts/Archcraft.ttf;

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''
      # unused
    '';
  };
}
