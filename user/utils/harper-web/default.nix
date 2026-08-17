# Harper grammar checker — web app server + CLI/LSP install.
#
# This module is the single home for Harper tooling outside of Neovim's editor
# config:
#   * `harper` (ships `harper-cli` + `harper-ls`) on the user PATH, so Neovim's
#     `harper_ls` LSP (configured in user/utils/neovim) keeps working via lazy-lsp.
#   * A self-hosted server for the Harper web app, built from source
#     (see ~/src/harper, `nix develop ~/.dotfiles --command just build-web`).
#     Serves on localhost; no data leaves the machine.
#
# Note: the web app is a SvelteKit build using @sveltejs/adapter-node, so the
# build output is a Node server (build/index.js), NOT plain static files.
# The ~/src/harper checkout tracks `master`.
# Rebuild: cd ~/src/harper && git pull --rebase && nix develop ~/.dotfiles --command just build-web

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # CLI + LSP binary. Kept here (not in neovim's extraPackages) so any tool
    # can use harper-ls; Neovim finds it on PATH.
    harper
  ];

  systemd.user.services.harper-web = {
    Unit = {
      Description = "Self-hosted Harper grammar checker web app";
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      # adapter-node SvelteKit server; HOST=127.0.0.1 keeps it loopback-only.
      Environment = [
        "PORT=8123"
        "HOST=127.0.0.1"
      ];
      WorkingDirectory = "/home/tsiru/src/harper/packages/web/build";
      ExecStart = "${pkgs.nodejs}/bin/node index.js";
      Restart = "on-failure";
      RestartSec = 3;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
