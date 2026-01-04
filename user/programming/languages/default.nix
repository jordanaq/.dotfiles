{ config, pkgs, ... }:

{
  imports = [
    ./c.nix
    ./haskell.nix
    ./julia.nix
    ./python.nix
    ./rust.nix
    ./sml.nix
  ];
}
