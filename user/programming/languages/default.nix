{ config, pkgs, ... }:

{
  imports = [
    ./c.nix
    ./elixir.nix
    ./haskell.nix
    ./julia.nix
    ./nix.nix
    ./python.nix
    ./rust.nix
    ./sml.nix
    ./typescript.nix
  ];
}
