# Configures shells

{ config, pkgs, ... }:

let
  shellAliases = {
    b = "bat";
    c = "clear";
    l = "eza -laG -F=always --icons=always";
    v = "nvim";
    z = "zoxide";
    g = "git";
    m = "make";
    ma = "m all";
    mc = "m clean";
    cg = "cargo";
    cgb = "cg build";
  };
in {
  programs = {
    fish = {
      enable = true;
      shellAliases = shellAliases;

      # `box on|off|status` — toggle the private Tailscale link to tsiru-cloud.
      # Requires services.tailscale.enable (system/tailscale.nix) plus a
      # one-time `sudo tailscale up` login; --operator=tsiru (set there) is what
      # makes every later toggle work without sudo.
      functions.box = {
        description = "Toggle/query the Tailscale link to tsiru-cloud";
        body = ''
          switch "$argv[1]"
              case on up
                  tailscale up
              case off down
                  tailscale down
              case status s ""
                  tailscale status
              case '*'
                  echo "usage: box on | off | status" >&2
                  return 1
          end
        '';
      };
    };
   
    bash = {
      enable = true;
      shellAliases = shellAliases;
    };
  };
}
