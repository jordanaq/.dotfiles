{ pkgs, inputs, ... }:

{
  home.packages = [
    # comfyui-nix pins its env to python312 upstream (its own
    # `pkgs.python312.override { packageOverrides = …; }` replaces ours, so our
    # overlay cannot reach in). Its env is a ~150-290 derivation SOURCE build
    # (no cache: rocmSupport = true makes onnxruntime/torch unclearable).
    #
    # Re-enabled on 2026-11-13, disabled again 2026-11-14: the env's
    # python3.12-openai-3.14.1 builds from source and its test suite fails in the
    # sandbox (3 failed / 3834 passed: test_azure_redirects'
    # test_async_redirect_origin plus both test_mtls_http_client
    # test_mtls_example_presents_full_client_chain cases timing out at 15s under
    # build load) -> python3-3.12.16-env -> comfy-ui -> home-manager-path ->
    # `home-manager switch` dies. Nothing to fix in this file: either wait for a
    # nixpkgs rev where that openai build is cached/not needed, or override it in
    # flake.nix (mind the cache-miss cascade — see the flake overlay comment).
    #
    # inputs.comfyui-nix.packages.${pkgs.stdenv.hostPlatform.system}.rocm
  ];

  # Self-clearing reminder: drop this warning the moment comfy is re-enabled.
  warnings = [
    "${__curPos.file}:${toString __curPos.line}: TODO: comfyui is commented out — its upstream python312 env builds python3.12-openai 3.14.1 from source and that test suite fails (2x mTLS timeout + test_async_redirect_origin), which aborts home-manager switch. Re-check whether that env builds clean, then delete this warning and uncomment the package."
  ];
}
