{ config, pkgs, ... }:

let
  zenBrowser = pkgs.stdenv.mkDerivation rec {
    pname = "zen-browser";
    version = "latest";

    src = pkgs.fetchFromGitHub {
      owner = "zen-browser";
      repo = "desktop";
      rev = "1.8.2b";
      sha256 = "";
    };
  };
in {
  programs.zen-browser = {
    enable = true;
    package = zenBrowser;
  }
}
