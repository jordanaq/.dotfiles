{ config, pkgs, inputs, ... }:

{
  programs.firefox = {
    enable = true;
    profiles.tsiru = {
      search.engines = {
        "DuckDuckGo" = {
          urls = [{
            template = "https://duckduckgo.com/";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];

            definedAliases = [
              "@ddg"
            ];
          }];
        };

        "MyNixOS" = {
          urls = [{
            template = "https://mynixos.com/search";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [
              "@nix"
            ];
          }];
        };
      };
    };
  };
}
