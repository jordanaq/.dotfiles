{ config, pkgs, ... }:

{
  imports = [
    ./c.nix
    ./elixir.nix
    ./haskell.nix
    ./julia.nix
    ./python.nix
    ./rust.nix
    ./sml.nix
    ./typescript.nix
  ];
}
