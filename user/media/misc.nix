{ pkgs, ... }:

{
  programs.feh = {
    enable = true;
  };

  home.packages = with pkgs; [
    # CLI media/OCR tooling — portable to WSL.
    ffmpeg
    ocrmypdf
    tesseract
  ];

  # GUI media apps from main (thunderbird, calibre, kdenlive, obs-studio, vlc)
  # and the zathura PDF viewer (programs.zathura) are deliberately NOT
  # installed on the WSL branch.
}