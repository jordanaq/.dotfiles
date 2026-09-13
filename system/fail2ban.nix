# fail2ban — firewall-level banning for the public web frontends.
#
# All vhosts write JSON access logs to /var/log/caddy/access-<host>.log, so a
# single jail covers every Caddy-fronted gate: Caddy basic_auth (search.),
# Stalwart's admin/JMAP (mail.), Bulwark (webmail.), Vaultwarden (vault.) and
# calibre-web's own login (calibre./library.). A ban is an iptables drop, so it
# blocks that source across ALL ports, not just :443.
#
# THREE THINGS TO KNOW BEFORE EDITING:
#
# 1. `backend` MUST be a file backend ("auto"). NixOS's fail2ban module sets
#    [DEFAULT] backend = systemd, and with the systemd backend fail2ban treats
#    `logpath` as a JOURNAL MATCH — it silently discards the file glob
#    (fail2ban/client/jailreader.py: `if backend.startswith("systemd"): continue`).
#    The jail then matches nothing and never bans (this was pentest F-15).
#
# 2. The filter MUST NOT expect 401 for bad credentials on every vhost. Only
#    Caddy basic_auth answers 401. The applications answer 400 on a bad login:
#    Stalwart's OAuth token endpoint returns 400/invalid_grant, Vaultwarden's
#    token endpoint 400, and Stalwart's /api/auth 400 on a malformed body.
#
# 3. `failregex` MUST BE A SINGLE LINE. The module writes the value verbatim
#    under `failregex = ...` and does NOT indent continuation lines, so a
#    multi-line value produces an unindented second line that fail2ban parses
#    as an unrelated (invalid) option — silently keeping only the first
#    pattern. Verified: with two lines, only the 401 rule matched. Hence the
#    alternation below instead of a second rule.
#
# The `(?:[/?][^"]*)?` tail on the path branch requires a separator or query
# after the prefix, so a benign 404 on e.g. /author/foo does not count.
#
# Sanity-check on the box after deploy with:
#   sudo fail2ban-client status caddy-auth
#   sudo fail2ban-regex /var/log/caddy/access-calibre.tsiru.pet.log \
#        /etc/fail2ban/filter.d/caddy-auth.conf
{ ... }:

{
  services.fail2ban = {
    enable = true;

    jails.caddy-auth = {
      # Passing an attrset generates /etc/fail2ban/filter.d/caddy-auth.conf.
      filter = {
        Definition = {
          # One regex (see note 3): (a) any 401/403 — covers Caddy basic_auth
          # and the /admin 403s — or (b) a 4xx on a known auth endpoint, which
          # is how the applications actually report a bad credential.
          failregex = ''^.*"remote_ip":"<HOST>".*(?:"status":(?:401|403)\b|"uri":"/(?:auth|api/auth|identity)(?:[/?][^"]*)?".*"status":4\d\d\b).*$'';
          # NB: match ONLY the timestamp token. A trailing `.*$` here would
          # swallow the rest of the line (fail2ban strips the matched date
          # BEFORE applying the failregex), leaving nothing to match.
          datepattern = ''"ts":{EPOCH}'';
        };
      };

      settings = {
        enabled = true;
        backend = "auto";
        logpath = "/var/log/caddy/*.log";
        maxretry = 6;
        findtime = "10m";
        bantime = "1h";
        # Never ban our own networks: loopback (Caddy -> itself, and the box's
        # own tooling) and the Tailscale CGNAT range (every device of Tsiru's
        # that can reach the box's admin surfaces). Without the tailnet entry a
        # few fat-fingered logins from a laptop would lock that laptop out.
        ignoreip = "127.0.0.1/8 ::1 100.64.0.0/10";
      };
    };
  };
}
