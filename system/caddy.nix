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
#      (The hash is safe to commit; the plaintext password is not.)
{ domain, ... }:

{
  services.caddy = {
    enable = true;

    virtualHosts."search.${domain}".extraConfig = ''
      basicauth {
        tsiru $2a$14$REPLACE_WITH_YOUR_GENERATED_HASH
      }
      reverse_proxy 127.0.0.1:8888
    '';
  };
}
