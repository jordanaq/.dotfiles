{ pkgs }:

# Both the proxy and rootless Firecrawl use the first global IPv4 address.
pkgs.writeShellScript "searx-proxy-host-ip" ''
  ${pkgs.iproute2}/bin/ip -4 addr show scope global 2>/dev/null |
    ${pkgs.gawk}/bin/awk '/inet/ { sub(/\/.*/, "", $2); print $2; exit }'
''
