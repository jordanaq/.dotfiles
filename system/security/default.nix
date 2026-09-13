# security — host hardening that sits outside any one service.
{ ... }:

{
  imports = [
    ./fail2ban.nix
  ];
}
