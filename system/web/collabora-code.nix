# Collabora Online Development Edition (CODE) 26.04 — packaged from Collabora's
# official AppImage so we get the 26.04 engine (with the AI assistant) without
# maintaining a huge LibreOffice/Collabora source derivation (Nixpkgs's native
# collabora-online is still 25.04 and hasn't completed the engine/ monorepo
# transition).
#
# Nextcloud's "Built-in CODE Server" release 26.4.303 bundles CODE cp-26.04.3-3.
# The AppImage is a standalone coolwsd executable accepting normal server args.
#
# Hash verified 2026-09-19 against the downloaded 26.4.303 asset:
#   sha256 = e288f29ba5c3e9ded06df78045184a41caa6573f5dcd47742df091e9ecb961a7
# (== SRI nix hash below).
{
  lib,
  fetchurl,
  runCommand,
  gnutar,
  gzip,
  findutils,
  appimageTools,
  pkgs,
}:

let
  version = "26.04.3-3";

  bundle = fetchurl {
    url = "https://github.com/CollaboraOnline/richdocumentscode/releases/download/26.4.303/richdocumentscode.tar.gz";
    hash = "sha256-4ojym6XD6d7QbfeARRhKQcqmVz9dzUd0LfCR6ey5Yac=";
  };

  # Pull the Collabora_Online.AppImage out of the Nextcloud-app release tarball.
  appImage = runCommand "collabora-online-code-${version}.AppImage"
    {
      nativeBuildInputs = [ gnutar gzip findutils ];
    }
    ''
      mkdir source
      tar -xzf ${bundle} -C source

      appimage="$(
        find source \
          -type f \
          -name Collabora_Online.AppImage \
          -print \
          -quit
      )"

      if [ -z "$appimage" ]; then
        echo "Collabora_Online.AppImage not found in release bundle" >&2
        exit 1
      fi

      cp "$appimage" "$out"
      chmod +x "$out"
    '';

  contents = appimageTools.extract {
    pname = "collabora-online-code";
    inherit version;
    src = appImage;
  };
in

appimageTools.wrapAppImage {
  pname = "collabora-online-code";
  inherit version contents;

  # The AppImage is mostly self-contained; iproute2 is useful because CODE's
  # deployment scripts inspect local networking.
  extraPkgs = p: [ p.iproute2 ];

  meta = {
    description = "Collabora Online Development Edition (CODE)";
    homepage = "https://www.collaboraonline.com/code/";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "collabora-online-code";
  };
}
