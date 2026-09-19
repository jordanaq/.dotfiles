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
      # NESTED attrset form is REQUIRED — the module's yq merge turns each
      # attribute into a literal XML tag, so a dotted key like "ssl.enable" would
      # emit a literal <ssl.enable> tag that coolwsd ignores (verified: it left
      # SSL on and net.listen at "any", producing the 502). Nest to get
      # <ssl><enable> and <net><listen>.
      ssl = {
        # Caddy terminates TLS in front, so Collabora serves plaintext behind it
        # and must know TLS already ended upstream to still emit https links.
        enable      = false;
        termination = true;
      };
      net = {
        # Loopback only. coolwsd accepts the literals "any" / "loopback" here
        # (not an IP address): nothing public touches Collabora except Caddy.
        listen = "loopback";
      };
      # The Host the browser reaches Collabora at (office.<domain>).
      server_name = "https://office.${domain}";
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