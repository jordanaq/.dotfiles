{ config, inputs, lib, pkgs, system, ... }:

let
  hermesPackage = inputs.hermes-agent.packages.${system}.default;
  hermesDesktopPackage = inputs.hermes-agent.packages.${system}.desktop;
in {
  imports = [ ./hindsight ];

  home.packages = [
    hermesPackage
    hermesDesktopPackage
    # Browser automation backend for Hermes' `browser` toolset.
    # `chromium` provides the Nix-wrapped browser binary so agent-browser
    # doesn't have to dynamically load generic-Linux shared libraries that
    # NixOS doesn't have. `agent-browser` is the Node CLI the tool spawns.
    pkgs.chromium
    pkgs.agent-browser
  ];

  # Pin agent-browser to the Nix-wrapped Chromium so it bypasses its own
  # Chrome download (which produces a dynamically-linked binary that cannot
  # run on NixOS). The gateway sets the same path in its environment.
  home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH =
    "${pkgs.chromium}/bin/chromium";

  home.file.".hermes/config.yaml".source = ./config.yaml;

  # Catppuccin Macchiato CLI skin (matches system catppuccin flavor/accent).
  home.file.".hermes/skins/catppuccin-macchiato.yaml".source = ./skins/catppuccin-macchiato.yaml;

  systemd.user.services.hermes-gateway = {
    Unit = {
      Description = "Hermes Agent gateway";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe hermesPackage} gateway run --replace";
      Restart = "on-failure";
      RestartSec = 5;
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
        # Point Hermes' Firecrawl web backend at the self-hosted instance.
        "FIRECRAWL_API_URL=http://localhost:3002"
        # Pin agent-browser to the Nix-wrapped Chromium so it bypasses its
        # own Chrome download (which produces a generic-Linux ELF that
        # cannot run on NixOS). `home.sessionVariables` propagates to
        # interactive shells but NOT to systemd user services, so we set
        # it here explicitly.
        "AGENT_BROWSER_EXECUTABLE_PATH=${pkgs.chromium}/bin/chromium"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };

  xdg.desktopEntries."hermes-desktop" = {
    name = "Hermes Desktop";
    comment = "Hermes desktop client";
    exec = "${lib.getExe hermesDesktopPackage} %U";
    icon = "${hermesDesktopPackage}/share/hermes-desktop/dist/hermes.png";
    terminal = false;
    categories = [ "Development" "Utility" ];
  };
}
