{ pkgs, inputs, ... }:

let
  pname = "zen-browser";
  version = "twilight";
  src = pkgs.fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen-x86_64.AppImage";
    sha256 = "sha256-XnM1EHZxQOBlhtxvAu5j6y+RUDM5c8UPQVkun37u2LU=";
  };

  # zenBrowser = pkgs.appimageTools.wrapType2 rec {
  #   inherit pname version src;
  # };
  zenBrowser = inputs.zen-browser.packages."${pkgs.system}".default;
in {
  home.packages = [
    zenBrowser
  ];
}
