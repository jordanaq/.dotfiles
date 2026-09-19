# web — every public HTTPS service, all fronted by Caddy. Pure aggregator: each child
# is a flat sibling module, or a directory whose own default.nix is the module.
{ ... }:

{
  imports = [
    ./caddy.nix
    ./searx.nix
    ./linkstack.nix
    ./calibre
    ./office.nix
    ./notes-site
    ./vaultwarden
  ];
}
