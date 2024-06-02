{ configs, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "jordanaq";
    userEmail = "quinn.jordan@proton.me";
    aliases = {
      pu = "push";
      co = "checkout";
      cm = "commit";
    };
  };
}
