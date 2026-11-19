{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ghc
    haskell-language-server
    # HLS picks this up from PATH for format-on-save / formatting provider.
    fourmolu
  ];

  # Global fourmolu defaults. fourmolu's own default indentation is 4
  # (ormolu's is 2), hence the override.
  # ~/.config/fourmolu.yaml is the global config path — fourmolu also reads a
  # `fourmolu.yaml` from the file's dir or any parent (nearest wins, so a
  # project-local one overrides this), but NOT `.fourmolu.yaml` and NOT
  # ~/.config/fourmolu/fourmolu.yaml.
  xdg.configFile."fourmolu.yaml".text = ''
    # Number of spaces per indentation step
    indentation: 2
  '';
}
