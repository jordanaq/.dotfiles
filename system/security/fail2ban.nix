# fail2ban — firewall-level banning for the public web frontends.
#
# One jail covers every Caddy-fronted vhost (all write JSON logs to
# /var/log/caddy/access-<host>.log): Caddy basic_auth (search.), Stalwart
# admin/JMAP (mail.), Bulwark (webmail.), Vaultwarden (vault.), calibre-web
# (calibre./library.). A ban is an iptables drop, so it blocks across all ports.
#
# THREE LOAD-BEARING GOTCHAS:
#  1. `backend` MUST be a file backend ("auto"). NixOS's module sets
#    [DEFAULT] backend = systemd; with systemd, fail2ban treats `logpath` as
#    a JOURNAL MATCH — silently discarding the file glob, the jail matches
#    nothing and never bans.
#
#  2. Do NOT expect 401 for a bad login. Only Caddy basic_auth answers 401; the
#     apps answer 400 (Stalwart OAuth token/invalid_grant, Vaultwarden token,
#     Stalwart /api/auth on malformed body).
#
#  3. `failregex` MUST be a single line. The module writes it verbatim and does
#     NOT indent continuation lines, so a multi-line value yields an unindented
#     second line fail2ban reads as an invalid option — silently keeping only
#     the first pattern. Hence the single alternation below.
#
# The `(?:[/?][^"]*)?` tail on the path branch requires a separator/query
# after the prefix, so a benign 404 on e.g. /author/foo does not count.
#
# On-box sanity check after deploy:
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
          # One regex (see note 3): (a) any 401/403 — Caddy basic_auth and the
          # /admin 403s — or (b) a 4xx on a known auth endpoint (how the apps
          # actually report a bad credential).
          failregex = ''^.*"remote_ip":"<HOST>".*(?:"status":(?:401|403)\b|"uri":"/(?:auth|api/auth|identity)(?:[/?][^"]*)?".*"status":4\d\d\b).*$'';
          # Match ONLY the timestamp token. A trailing `.*$` swallows the rest
          # of the line (fail2ban strips the date BEFORE the failregex),
          # leaving nothing to match.
          datepattern = ''"ts":{EPOCH}'';
        };
      };

      settings = {
        enabled = true;
        backend = "auto";
        logpath = "/var/log/caddy/*.log";
        # maxretry 12 over 10min, ban 30m. Deliberately loose: browser retry
        # loops / fumbled passwords can produce a handful of 401s in seconds,
        # and too-tight a threshold locks the owner out of every vhost (15
        # probes from the owner's own IP tripped the old maxretry=6). Still
        # hopeless for brute force, so the lost strictness costs nothing.
        maxretry = 12;
        findtime = "10m";
        bantime = "30m";
        # Never ban our own networks: loopback (Caddy -> itself, box tooling)
        # and the Tailscale CGNAT range (every device reaching the admin
        # surfaces). Without the tailnet entry, fat-fingered logins would lock
        # a laptop out.
        ignoreip = "127.0.0.1/8 ::1 100.64.0.0/10";
      };
    };
  };
}
