{ config, pkgs, ... }:
let
  # Build the notebook env on the DEFAULT interpreter (pkgs.python3 — currently
  # 3.14) instead of a pinned python312. Reason (measured 2026-10): in this
  # nixpkgs rev Hydra caches the python3 / python313 package sets but NOT
  # python312, so a python312 env made ~135 packages build from SOURCE — and
  # their pytest suites then ran locally, where several are genuinely broken or
  # flaky against the current interpreter/OpenSSL (terminado test_max_terminals,
  # backrefs test_timeout, anyio test_tls_connectable). Each one aborted
  # `home-manager switch` on whichever failed first, so every retry surfaced a
  # different package:
  #   python312.withPackages(<this list>) → 135 derivations to build
  #   python3.withPackages(<same list>)   →   0 derivations to build (cache hits)
  # If you ever pin an interpreter here again, check the cache first:
  #   nix build --dry-run --impure --expr 'let p = …; in p.python3XX.withPackages …'
  #
  # NOTE: do NOT `pkgs.python3.override { packageOverrides = … }` in a module.
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
  python3 = pkgs.python3;
in
{
  home.packages = with pkgs; [
    black
    conda
    (python3.withPackages (ps: with ps; [
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
