{ pkgs, ... }:

{
  home.packages = with pkgs.rocmPackages; [
    clinfo
    rocminfo
    hipcc
    rocm-smi
  ];
}
