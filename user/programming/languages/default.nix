{ config, pkgs, ... }:

{
  imports = [
    ./c.nix
    ./haskell.nix
    ./python.nix
    ./rust.nix
  ];
}
