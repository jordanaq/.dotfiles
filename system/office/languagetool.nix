# LanguageTool grammar/style checker (loopback only) + English n-gram corpus.
#
# Native NixOS service, NOT exposed to the network — only Collabora CODE
# (./default.nix) talks to it. Port lives here as the single source of truth;
# office/default.nix reads config.services.languagetool.port for the WOPI
# integration URL.
{
  lib,
  pkgs,
  ...
}:

let
  # 8081 is already used by calibre-server; keep LanguageTool off it.
  port = 8091;

  # Turn on two extra English writing-aid rules that ship disabled by default.
  languagetoolEnhanced = pkgs.languagetool.overrideAttrs (old: {
    postInstall = ''
      rules="$out/share/org/languagetool/rules/en/grammar.xml"

      sed -i -E \
        '/id="PLAIN_ENGLISH"/ s/default="off"/default="on"/' \
        "$rules"

      sed -i -E \
        '/id="TON_ACADEMIC"/ s/default="off"/default="on"/' \
        "$rules"
    '';
  });
in
{
  services.languagetool = {
    enable = true;
    package = languagetoolEnhanced;

    port = port;

    # Do not expose LanguageTool outside the machine.
    public = false;

    settings = {
      languageModel = "/var/lib/languagetool-ngrams";
    };

    # Single-user server; bound JVM growth while leaving comfortable headroom.
    jvmOptions = [
      "-Xms64m"
      "-Xmx512m"
    ];
  };

  systemd.services.languagetool-ngrams = {
    description = "Install LanguageTool English n-gram corpus";

    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [ "languagetool.service" ];

    path = [
      pkgs.coreutils
      pkgs.curl
      pkgs.unzip
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      # Creates /var/lib/languagetool-ngrams.
      StateDirectory = "languagetool-ngrams";
      StateDirectoryMode = "0755";
    };

    script = ''
      set -euo pipefail

      root=/var/lib/languagetool-ngrams
      marker="$root/.complete"

      if [ -e "$marker" ]; then
        exit 0
      fi

      work="$root/.install"
      archive="$work/ngrams-en.zip"

      rm -rf "$work"
      mkdir -p "$work"

      cleanup() {
        rm -rf "$work"
      }
      trap cleanup EXIT

      curl \
        --fail \
        --location \
        --retry 3 \
        --output "$archive" \
        https://languagetool.org/download/ngram-data/ngrams-en-20150817.zip

      echo \
        "10e548731d9f58189fc36a553f7f685703be30da0d9bb42d1f7b5bf5f8bb232c  $archive" \
        | sha256sum --check -

      mkdir "$work/extracted"
      unzip -q "$archive" -d "$work/extracted"

      test -d "$work/extracted/en/1grams"
      test -d "$work/extracted/en/2grams"
      test -d "$work/extracted/en/3grams"

      rm -rf "$root/en"
      mv "$work/extracted/en" "$root/en"

      chmod -R a+rX "$root/en"
      touch "$marker"
    '';
  };

  systemd.services.languagetool = {
    requires = [ "languagetool-ngrams.service" ];
    after = [ "languagetool-ngrams.service" ];
  };
}