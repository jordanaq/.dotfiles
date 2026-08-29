# Jagex Launcher (Linux Beta) — wrapped AppImage for NixOS/home-manager
#
# Jagex ships the Linux beta only as a portable AppImage (Electron-based).
# We extract it with appimageTools and run the binary inside a buildFHSEnv
# (bubblewrap FHS) with --no-sandbox so it launches natively on NixOS without
# FUSE and without the recursive-AppImage-in-FHS bug that bites RuneLite.
#
# NOTE: the upstream URL points at "latest", so the binary moves whenever Jagex
# ships an update. The sha256 below pins the exact build we fetched
# (AppImage internal version 0.0.27, dated 2026-07-17). Bump the hash when you
# want a newer beta.
{
  pkgs,
  lib,
  ...
}:

let
  pname = "jagex-launcher";
  version = "0.0.27";

  src = pkgs.fetchurl {
    url = "https://rs-launcher-updates.runescape.com/production/linux/x64/latest/jagex-launcher-beta-linux-x86_64.AppImage";
    sha256 = "b26cd33e2315681437204cd4eb797107ddb42e3640a854c4fee75a279f02f2a9";
  };

  # Extract the type-2 AppImage into the nix store.
  extracted = pkgs.appimageTools.extractType2 { inherit pname src version; };

  # FHS env so Electron + bundled libs find a normal /usr/lib style tree.
  fhsEnv = pkgs.buildFHSEnv {
    name = "jagex-launcher-fhs";
    targetPkgs = pkgs: with pkgs; [
      # core libs Electron expects
      glib
      glibc
      nss
      nspr
      dbus
      gtk3
      atk
      at-spi2-atk
      at-spi2-core
      cups
      libdrm
      libxkbcommon
      libgbm
      mesa
      libGL
      libglvnd
      expat
      zlib
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxrender
      libxscrnsaver
      libxtst
      libxcb
      alsa-lib
      pango
      cairo
      gdk-pixbuf
      fontconfig
      freetype
      # for the chrome-sandbox / --no-sandbox fallback paths
      util-linux
      bash
      # Electron / chromium runtime bits
      libudev-zero
      libsecret
      libpulseaudio
      systemd
    ];
    runScript = "${extracted}/jagex-launcher.bin";
  };
in
{
  home.packages = [
    (pkgs.writeShellScriptBin pname ''
      #!/usr/bin/env bash
      exec ${fhsEnv}/bin/jagex-launcher-fhs --no-sandbox "$@"
    '')
  ];

  # Desktop entry so it shows up in app launchers, with the real Jagex icon.
  # (Written directly via home.file because xdg.desktopEntries isn't emitting
  # files in this setup. Icon points at the PNG extracted from the AppImage.)
  home.file.".local/share/applications/jagex-launcher.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Jagex Launcher (Beta)
    Exec=${pname} %U
    Icon=${extracted}/usr/share/icons/hicolor/512x512/apps/jagex-launcher.png
    Terminal=false
    Comment=Jagex Launcher (Linux Beta) — RuneLite / OSRS
    Categories=Game;
    MimeType=x-scheme-handler/rshub;
    StartupWMClass=Jagex Launcher
  '';
}
