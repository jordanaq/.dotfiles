{ pkgs, inputs, ... }:

{
  home.packages = [
    inputs.comfyui-nix.packages.${pkgs.stdenv.hostPlatform.system}.rocm
  ];
}
