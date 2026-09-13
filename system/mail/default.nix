# mail — Stalwart (the mail server) and Bulwark (its webmail client).
{ ... }:

{
  imports = [
    ./stalwart
    ./bulwark.nix
  ];
}
