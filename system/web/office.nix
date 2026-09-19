# Collabora Online — in-browser office editor for Bulwark's Files (WOPI) at
# office.<domain>. Native NixOS service (no container); Caddy terminates TLS and
# proxies to [::1]:9980 (net.listen=loopback = IPv6 loopback). Bulwark
# (webmail.<domain>) is the WOPI host that mints the token and serves the file.
{ domain, ... }:

{
  services.collabora-online = {
    enable = true;
    # Port 9980 matches the office.<domain> vhost in caddy.nix — no change needed.

    settings = {
      # NESTED attrset is REQUIRED: the module's yq merge turns each attr into
      # a literal XML tag, so dotted keys like "ssl.enable" emit <ssl.enable>
      # and are ignored (left SSL on + net.listen "any", producing the 502).
      ssl = {
        # TLS terminated by Caddy upstream; Collabora serves plaintext but must
        # know TLS ended so it still emits https links.
        enable      = false;
        termination = true;
      };
      net.listen = "loopback";
      # Host ONLY — no scheme: Collabora prepends https:// itself (termination).
      # A scheme yields https://https://... and breaks Bulwark's WOPI launch.
      server_name = "office.${domain}";

      num_prespawn_children = 1;
      memproportion = 40.0;
      admin_console.enable = false;

    };
  };

  # WOPI host allowlist. IMPORTANT: this is a TOP-LEVEL module option
  # (services.collabora-online.aliasGroups, a sibling of `settings`), NOT a
  # member of `settings` — under `settings` it renders to a bogus
  # <aliasGroups> XML tag, is dropped by the yq merge, and Collabora falls
  # back to `mode="first"` (trusts whichever host connects FIRST). Declared
  # here it becomes the `aliasgroup1` environment variable, which coolwsd
  # reads via --use-env-vars: only webmail.tsiru.pet may be the WOPI host.
  services.collabora-online.aliasGroups = [
    {
      host = "https://webmail.${domain}:443";
      aliases = [ ];
    }
  ];
}
