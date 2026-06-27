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

  home.packages = with pkgs; [
    eslint
    typescript
    typescript-language-server
  ];
}
