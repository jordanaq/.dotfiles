# Caddy — auto-TLS reverse proxy in front of SearXNG.
#
# Caddy obtains and renews a Let's Encrypt certificate for
# search.<domain> automatically (HTTP-01 challenge on :80) and enforces
# basic-auth, then proxies to the loopback SearXNG instance.
#
# Before deploying:
#   1. DNS: A record  search.tsiru.cat -> <LINODE_IP>  (DNS-only / grey cloud,
#      so the ACME HTTP-01 challenge reaches this box directly).
#   2. Generate the auth hash and paste it below:
#        nix run nixpkgs#caddy -- hash-password --plaintext '<your-password>'
#      Only the bcrypt HASH is committed, never the plaintext. bcrypt is salted
#      and deliberately slow (cost 14), so this is safe ONLY with a strong,
#      unique, generated password — this repo is PUBLIC, so a weak password
#      would make the committed hash an offline cracking target.
#      Change it with: edit this file -> rebuild -> push.
{ domain, ... }:

{
  services.caddy = {
    enable = true;

    virtualHosts."search.${domain}".extraConfig = ''
      basic_auth {
        tsiru $2a$14$REPLACE_WITH_YOUR_GENERATED_HASH
      }
      reverse_proxy 127.0.0.1:8888
    '';
  };
}
