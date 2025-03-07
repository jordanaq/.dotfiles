{ pkgs, ... }:

let
  pname = "zen-browser";
  version = "twilight";
  src = pkgs.fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen-x86_64.AppImage";
    sha256 = "sha256-03H7mYhBt7PrtCm6xiDmfBCLZ3ZCxEJKw+U6lolM/Fg=";
  };

  zenBrowser = pkgs.appimageTools.wrapType2 rec {
    inherit pname version src;
  };
in {
  home.packages = [
    zenBrowser
  ];
}
