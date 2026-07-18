{ pkgs, lib }:

let
  version = "0.10.2";

  src = pkgs.fetchFromGitHub {
    owner = "open-webui";
    repo = "open-webui";
    tag = "v${version}";
    hash = "sha256-tJ9b5up5FoX5TrmpwMWevyA/o3Ai/lKsHu+nahc2Ttc=";
  };

  frontend = pkgs.buildNpmPackage {
    pname = "open-webui-frontend";
    inherit version src;

    npmDepsHash = "sha256-yw/1n1jBCUtt8wUqJmIkB3W53wsXTKuAFG/EMwcTpx8=";
    npmFlags = [ "--force" ];

    postPatch = ''
      substituteInPlace package.json \
        --replace-fail "npm run pyodide:fetch && vite build" "vite build"
    '';

    env = {
      CYPRESS_INSTALL_BINARY = "0";
      ONNXRUNTIME_NODE_INSTALL_CUDA = "skip";
      NODE_OPTIONS = "--max-old-space-size=8192";
    };

    preBuild = ''
      tar xf ${pkgs.fetchurl {
        url = "https://github.com/pyodide/pyodide/releases/download/0.28.3/pyodide-0.28.3.tar.bz2";
        hash = "sha256-fcqubT8VmGoJ8PnmxHE6DA8kv/DJDHToWoFyPxvGCUA=";
      }} -C static/
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share
      cp -a build $out/share/open-webui

      runHook postInstall
    '';
  };
in
pkgs.open-webui.overrideAttrs (oldAttrs: {
  inherit version src;

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail ', build = "open_webui/frontend"' ""
  '';

  makeWrapperArgs = [
    "--set FRONTEND_BUILD_DIR ${frontend}/share/open-webui"
  ];

  passthru = (oldAttrs.passthru or { }) // {
    inherit frontend;
  };
})
