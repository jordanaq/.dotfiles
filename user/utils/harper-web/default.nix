# Harper grammar checker — web app server + CLI/LSP install.
#
# This module is the single home for Harper tooling outside of Neovim's editor
# config:
#   * `harper` (ships `harper-cli` + `harper-ls`) on the user PATH, so Neovim's
#     `harper_ls` LSP (configured in user/utils/neovim) keeps working via lazy-lsp.
#   * A self-hosted static server for the Harper web app, built from source
#     (see ~/src/harper, `nix develop ~/.dotfiles --command just build-web`).
#     Serves on localhost; no data leaves the machine.

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # CLI + LSP binary. Kept here (not in neovim's extraPackages) so any tool
    # can use harper-ls; Neovim finds it on PATH.
    harper
  ];

  systemd.user.services.harper-web = {
    description = "Self-hosted Harper grammar checker web app";
    wantedBy = [ "default.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8123 --directory /home/tsiru/src/harper/packages/web/build";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
