# Collabora Online — in-browser office editing for Bulwark's Files (WOPI),
# served at office.<domain>. Caddy terminates TLS and proxies to [::1]:9980
# (net.listen=loopback binds the IPv6 loopback; system/web/caddy.nix). A native
# NixOS service (services.collabora-online): NO container, NO podman. Bulwark
# (webmail.<domain>) is the WOPI host — it mints the access token and serves the
# file over WOPI; this Collabora instance is the editor the browser embeds.
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
      net.listen = "loopback";
      # The Host the browser reaches Collabora at. Host ONLY — no scheme:
      # Collabora prepends https:// itself (from ssl.termination=true). A scheme
      # here makes it emit urlscr="https://https://office..." in /hosting/discovery,
      # which broke Bulwark's WOPI launch (CSP form-action refused it).
      server_name = "office.${domain}";

      num_prespawn_children = 1;
      memproportion = 70.0;
      admin_console.enable = false;

    };

    # Memory cap + WOPI security.
    #  - num_workers=1 limits concurrent document sessions — the single biggest
    #    Collabora RAM lever, and this box is 2 GB.
    #  - storage.wopi.allow restricts which origin may *initiate* WOPI — here the
    #    Bulwark WOPI host at webmail.<domain>. Deliberately in the documented
    #    `--o:` CLI form rather than the freeform `settings`, because allow is a
    #    list-valued option and the module's XML-attribute merge (`@allow`) does
    #    not serialize arrays cleanly.
    extraArgs = [
      "--o:num_workers=1"
    ];
    
    aliasGroups = [
      {
        host = "https://webmail.${domain}:443";
        aliases = [ ];
      }
    ];
  };
}
