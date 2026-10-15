{ pkgs, inputs, ... }:

{
  home.packages = [
    # TODO: comfyui disabled 2026-10 — comfyui-nix pins its env to python312
    # upstream (its own `pkgs.python312.override { packageOverrides = …; }`
    # replaces ours, so we cannot reach in), which makes ~150 packages build
    # from source; several of their test suites fail and abort
    # `home-manager switch`. Add back once that env builds clean (e.g. a
    # vendored copy with `doCheck = false` on its python set).
    # inputs.comfyui-nix.packages.${pkgs.stdenv.hostPlatform.system}.rocm
  ];

  warnings = [
    "${__curPos.file}:${toString __curPos.line}: TODO: comfyui is disabled — its upstream python312 env builds ~150 packages from source and its test failures abort home-manager switch; re-enable when fixed"
  ];
}
