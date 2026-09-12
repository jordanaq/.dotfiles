# Caddy — auto-TLS reverse proxy in front of SearXNG.
#
# Caddy obtains and renews a Let's Encrypt certificate for
# search.<domain> automatically (HTTP-01 challenge on :80) and enforces
# basic-auth, then proxies to the loopback SearXNG instance.
#
# The basic-auth credential is deliberately NOT stored here — this repo is
# PUBLIC. It lives on the server in /etc/secrets/caddy.env as
# `CADDY_AUTH_HASH=<bcrypt hash>`, wired in via services.caddy.environmentFile
# and referenced below as {$CADDY_AUTH_HASH}. Caddy substitutes {$VAR} from its
# process environment when it adapts the Caddyfile at startup, so the hash never
# enters the nix store or git. (Note `{$…}`, not `{env.…}`.)
#
# Before deploying:
#   1. DNS: A record  search.<domain> -> <LINODE_IP>  (DNS-only / grey cloud,
#      so the ACME HTTP-01 challenge reaches this box directly).
#   2. Create the secrets file on the server (0600):
#        nix run nixpkgs#caddy -- hash-password --plaintext '<password>'
#        sudo install -m 600 /dev/null /etc/secrets/caddy.env
#        printf 'CADDY_AUTH_HASH=%s\n' '<that $2a$14$… hash>' | sudo tee /etc/secrets/caddy.env
#      It MUST exist before `nixos-rebuild switch`: systemd's EnvironmentFile is
#      not optional here, and Caddy refuses to start without it
#      ("username and password cannot be empty or missing").
#   3. Change the password later with: edit /etc/secrets/caddy.env -> restart caddy.
{ domain, ... }:

{
  services.caddy = {
    enable = true;

    # Supplies CADDY_AUTH_HASH to Caddy's process environment (systemd
    # EnvironmentFile, read as root before dropping to the caddy user).
    environmentFile = "/etc/secrets/caddy.env";

    virtualHosts."search.${domain}".extraConfig = ''
      basic_auth {
        tsiru {$CADDY_AUTH_HASH}
      }
      reverse_proxy 127.0.0.1:8888
    '';
  };
}
