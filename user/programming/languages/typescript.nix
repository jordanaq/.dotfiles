{ pkgs, ... }:

{
  home.packages = with pkgs; [
    eslint
    typescript
    typescript-language-server
  ];

  programs.bun.enable = true;
}
