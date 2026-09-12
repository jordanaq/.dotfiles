# fail2ban — firewall-level banning for the public web frontends.
#
# calibre-web rate-limits logins itself (since 0.6.20); this adds a second,
# network-level layer: repeated 401/403 responses from one IP on the Calibre
# vhosts get that IP banned. Caddy writes one access log per vhost into
# /var/log/caddy (the dir is created by Caddy's systemd LogsDirectory).
#
# NOTE: the filter below matches Caddy's JSON access log. If it ever stops
# matching (e.g. Caddy changes its log format), the site keeps working — you
# just lose the firewall bans (calibre-web's own limiter still applies).
# Sanity-check on the box after deploy with:
#   sudo fail2ban-regex /var/log/caddy/library.log \
#        /etc/fail2ban/filter.d/caddy-calibre.conf
{ ... }:

{
  services.fail2ban = {
    enable = true;

    jails.caddy-calibre = {
      # Passing an attrset generates /etc/fail2ban/filter.d/caddy-calibre.conf.
      filter = {
        Definition = {
          failregex = ''^.*"remote_ip":"<HOST>".*"status":(?:401|403)\b.*$'';
          # NB: match ONLY the timestamp token. A trailing `.*$` here would
          # swallow the rest of the line (fail2ban strips the matched date
          # BEFORE applying the failregex), leaving nothing to match.
          datepattern = ''"ts":{EPOCH}'';
        };
      };

      settings = {
        enabled = true;
        logpath = "/var/log/caddy/*.log";
        maxretry = 5;
        findtime = "10m";
        bantime = "1h";
      };
    };
  };
}
