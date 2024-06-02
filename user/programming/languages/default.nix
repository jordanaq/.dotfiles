{ config, pkgs, ... }:

{
  imports = [
    ./c.nix
    ./python.nix
    ./rust.nix
  ];
}
