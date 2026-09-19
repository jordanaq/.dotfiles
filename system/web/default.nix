# web — every public HTTPS service, all fronted by Caddy.
#
# Grouped the same way `user/` groups its modules: this file is a pure
# aggregator; each child is either a flat sibling module or a directory whose
# own `default.nix` is the module.
{ ... }:

{
  imports = [
    ./caddy.nix
    ./searx.nix
    ./linkstack.nix
    ./calibre
    ./nextcloud
    ./notes-site
    ./vaultwarden
  ];
}
