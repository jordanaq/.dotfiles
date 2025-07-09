{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    gcc
    zlib
    zstd
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${
      pkgs.lib.makeLibraryPath [
        pkgs.zlib
        pkgs.zstd
        pkgs.gcc.cc.lib
      ]
    }:$LD_LIBRARY_PATH"
  '';
}
