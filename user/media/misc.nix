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
    zathura
  ];
}
