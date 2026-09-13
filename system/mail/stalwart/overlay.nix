# Stalwart 0.16 + its management CLI, fetched as PREBUILT binaries from the
# official GitHub release tarballs (no cargo build).
#
# WHY: nixpkgs still pins stalwart 0.15.5 (2026-09); the 0.16 line is a full
# management-layer redesign (JSON config, JMAP-object provisioning, new CLI
# from the separate stalwartlabs/cli repo). These packages track upstream
# releases directly. DROP THIS OVERLAY once nixpkgs ships stalwart >= 0.16.
#
# Hashes: `nix store prefetch-file <url>` after bumping version.
final: prev: {
  stalwart = final.stdenv.mkDerivation (finalAttrs: {
    pname = "stalwart";
    version = "0.16.21";

    # Single `stalwart` binary in the tarball (webadmin + spam filter are
    # embedded since 0.16).
    src = final.fetchurl {
      url = "https://github.com/stalwartlabs/stalwart/releases/download/v${finalAttrs.version}/stalwart-x86_64-unknown-linux-gnu.tar.gz";
      sha256 = "eb02fb00b2aa320a3ec1fa32560689ad7141033711931b0b0165e4b7145d0003";
    };

    nativeBuildInputs = [ final.autoPatchelfHook ];

    # The release tarball holds a single bare `stalwart` binary (no directory),
    # which trips the unpacker's "no directories" check.
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      tar xzf $src
      install -Dm755 stalwart $out/bin/stalwart
      runHook postInstall
    '';

    # The stalwart-provision unit (system/mail/stalwart/module/provision.nix) reads
    # the apply-plan schema from package.src, so expose the SOURCE here
    # (it carries resources/schema/schema.json.gz). fetchzip: unpacked, with
    # the wrapper dir stripped — the nixpkgs stalwart package does the same.
    passthru.src = final.fetchzip {
      url = "https://github.com/stalwartlabs/stalwart/archive/refs/tags/v${finalAttrs.version}.tar.gz";
      sha256 = "sha256-EZ7cuHToVzs/pubGtvXRzgHjmJ8DV7OrIuXnlmQyy1s=";
    };

    meta = {
      description = "All-in-one mail server (SMTP/IMAP/JMAP/CalDAV/CardDAV) — prebuilt 0.16 release";
      homepage = "https://stalw.art";
      license = final.lib.licenses.agpl3Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = "stalwart";
    };
  });

  stalwart-cli = final.stdenv.mkDerivation (finalAttrs: {
    pname = "stalwart-cli";
    version = "1.0.12";

    src = final.fetchurl {
      url = "https://github.com/stalwartlabs/cli/releases/download/v${finalAttrs.version}/stalwart-cli-x86_64-unknown-linux-gnu.tar.xz";
      sha256 = "e2bb054509aaac311f13ff4f9e09c38c607195de2e9735cf84cfc6ee4776a5a2";
    };

    nativeBuildInputs = [ final.autoPatchelfHook ];
    # binary links libgcc_s.so.1
    buildInputs = [ final.gcc-unwrapped.lib ];

    installPhase = ''
      runHook preInstall
      # unpackPhase already cd'd into the extracted <name>-<version>/ dir
      install -Dm755 stalwart-cli $out/bin/stalwart-cli
      runHook postInstall
    '';

    meta = {
      description = "Stalwart management CLI (JMAP-based, 0.16+)";
      homepage = "https://github.com/stalwartlabs/cli";
      license = final.lib.licenses.agpl3Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = "stalwart-cli";
    };
  });
}
