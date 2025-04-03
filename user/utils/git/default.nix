{ configs, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "jordanaq";
    userEmail = "quinn.jordan@protonmail.ch";
    aliases = {
      a = "add";
      ca = "commit -a";
      cam = "commit -am";
      ch = "checkout";
      co = "commit";
      cm = "commit -m";
      com = "commit -m";
      d = "diff";
      pl = "pull";
      ps = "push";
      ro = "restore";
      s = "status";
      st = "status";
    };
  };
}
