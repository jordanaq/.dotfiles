{ config, pkgs, ... }:
let
  # inline-snapshot (pulled in transitively by plotly -> narwhals) fails 3 of
  # its own formatting-assertion tests in the sandbox on nixpkgs 26.11pre
  # (Sep 2026), which blocks the whole python env. Build it without checks.
  python312 = pkgs.python312.override {
    packageOverrides = _: super: {
      inline-snapshot = super.inline-snapshot.overridePythonAttrs (_: { doCheck = false; });
    };
  };
in
{
  home.packages = with pkgs; [
    black
    conda
    (python312.withPackages (ps: with ps; [
      conda
      ipykernel
      matplotlib
      nbconvert
      notebook
      numpy
      pandas
      pip
      plotly
      scipy
      seaborn
      sympy
      virtualenv
    ]))
  ];
}
