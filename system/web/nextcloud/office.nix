# Collabora Online — Nextcloud's built-in "Nextcloud Office" editing, served at
# office.<domain>. Caddy terminates TLS and proxies 127.0.0.1:9980
# (system/web/caddy.nix). This is a native NixOS service
# (services.collabora-online): NO container, NO podman — the light path vs the
# OnlyOffice/EuroOffice container this replaced, and the standard "Nextcloud
# Office" pairing (the Nextcloud `richdocuments` app is the browser-side
# client, declared in system/web/nextcloud/default.nix).
{ domain, ... }:

{
  services.collabora-online = {
    enable = true;
    # Port defaults to 9980, which is exactly what the office.<domain> vhost in
    # caddy.nix already reverse-proxies to — no port/Caddy change needed.

    settings = {
      # Caddy terminates TLS in front, so Collabora must serve plaintext behind
      # it, and must know TLS already ended upstream so it still emits https
      # links (and the browser doesn't get a mixed-content editor).
      "ssl.enable"      = false;
      "ssl.termination" = true;

      # Loopback only: nothing public touches Collabora except the Caddy proxy.
      "net.listen"      = "127.0.0.1";

      # The Host the browser reaches Collabora at (office.<domain>).
      "server_name"     = "https://office.${domain}";
    };

    # Memory cap + WOPI security.
    #  - num_workers=1 limits concurrent document sessions — the single biggest
    #    Collabora RAM lever, and this box is 2 GB.
    #  - storage.wopi.allow restricts which origin may *initiate* WOPI (only the
    #    Nextcloud instance). Deliberately in the documented `--o:` CLI form
    #    rather than the freeform `settings`, because allow is a list-valued
    #    option and the module's XML-attribute merge (`@allow`) does not
    #    serialize arrays cleanly.
    extraArgs = [
      "--o:num_workers=1"
      "--o:storage.wopi.allow[0]=https://cloud.${domain}"
    ];
  };
}