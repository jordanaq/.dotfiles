{ pkgs, ... }:

{
  programs.feh = {
    enable = true;
  };

  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
    };
  };

  home.packages = with pkgs; [
    calibre
    ffmpeg
    kdePackages.kdenlive
    obs-studio
    ocrmypdf
    tesseract
    vlc
  ];

  # Zathura (PDF viewer, mupdf backend) with Catppuccin-themed recolor.
  # Default = Macchiato (dark). Toggle to Latte (light) with `,l` in zathura.
  programs.zathura = {
    enable = true;
    options = {
      # Recolor on by default → dark reading mode.
      recolor = true;
      # Catppuccin Macchiato: text on base.
      recolor-darkcolor = "#cad3f5";
      # Catppuccin Macchiato: base background.
      recolor-lightcolor = "#24273a";
      # Keep original colors in images/photos (don't invert scanned pages).
      recolor-reverse-video = true;
      # Preserve original hue of colored content.
      recolor-keephue = true;
      # Adjust lightness for a cleaner dark look.
      recolor-adjust-lightness = true;
    };
    # Extra raw zathurarc lines (multi-command keymaps via feedkeys).
    extraConfig = ''
      # Swap recolor palette on the fly:
      #   ,d → Catppuccin Macchiato (dark)
      #   ,l → Catppuccin Latte (light)
      map ,d feedkeys ":set recolor-lightcolor \#24273a<Return>:set recolor-darkcolor \#cad3f5<Return>:set recolor true<Return>"
      map ,l feedkeys ":set recolor-lightcolor \#eff1f5<Return>:set recolor-darkcolor \#4c4f69<Return>:set recolor true<Return>"
    '';
  };
}
