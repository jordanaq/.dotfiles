{ pkgs, ... }:

let
  pname = "duckstation";
  version = "0.1-11826";

  src = pkgs.fetchurl {
    url = "https://github.com/stenzek/duckstation/releases/download/v${version}/DuckStation-x64.AppImage";
    hash = "sha256-xcip3k38EOeUE33Li6uXYMpXjfKqe+jBIVFxvru6WWU=";
  };

  extracted = pkgs.appimageTools.extract { inherit pname version src; };

  libs = pkgs.lib.makeLibraryPath (with pkgs; [
    libglvnd
    libx11
    libxext
    libxrender
    libxi
    libxcursor
    libxrandr
    libxcb
    libxkbcommon
    wayland
    fontconfig
    freetype
    gmp
    libgpg-error
    e2fsprogs
    alsa-lib
    libpulseaudio
    stdenv.cc.cc.lib
  ]);

  # AppImage binaries use /lib64/ld-linux, which NixOS refuses; point it at nix glibc.
  app = pkgs.runCommandLocal "${pname}-app" { nativeBuildInputs = [ pkgs.patchelf ]; } ''
    cp -a ${extracted} $out
    chmod u+w $out/usr/bin/duckstation-qt
    patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $out/usr/bin/duckstation-qt
  '';
in
{
  home.packages = [
    (pkgs.writeShellScriptBin pname ''
      export LD_LIBRARY_PATH="${app}/usr/lib:${libs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      export QT_PLUGIN_PATH="${app}/usr/plugins"
      export XKB_CONFIG_ROOT="${pkgs.xkeyboard-config}/share/X11/xkb"
      export QT_XKB_CONFIG_ROOT="$XKB_CONFIG_ROOT"
      exec ${app}/usr/bin/duckstation-qt "$@"
    '')
  ];

  home.file.".local/share/applications/duckstation.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=DuckStation
    Exec=${pname} %f
    Icon=${app}/usr/share/icons/hicolor/512x512/apps/org.duckstation.DuckStation.png
    Terminal=false
    Comment=PlayStation 1 emulator
    Categories=Game;Emulator;
    MimeType=application/x-iso9660-image;
    StartupWMClass=duckstation-qt
  '';
}
