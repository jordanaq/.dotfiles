{ config, pkgs, ... }:
let
  # NOTE: do NOT `pkgs.python312.override { packageOverrides = … }` in a module.
  # Python's `override` REPLACES `packageOverrides` wholesale rather than
  # composing, so a local override here silently discards the flake overlay's
  # entries (CPU torch pin, jupyter-server + portalocker test skips). Doing that
  # is what made the notebook env build an unpatched jupyter-server, whose
  # test_disconnect_resolves_orphaned_kernel_info_future times out
  # deterministically in the sandbox and killed `home-manager switch`.
  # Add python package overrides in flake.nix, next to the others — and only
  # when the package's unmodified build is uncached (an override changes the
  # drv hash and can force unrelated packages, e.g. openai via inline-snapshot,
  # to rebuild from source).
  python312 = pkgs.python312;
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
