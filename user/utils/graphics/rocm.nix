{ pkgs, ... }:

{
  home.packages = with pkgs.rocmPackages; [
    clr
    rocminfo
    # hipcc
    rocm-smi
  ];
}
