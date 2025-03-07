{ configs, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "jordanaq";
    userEmail = "quinn.jordan@proton.me";
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
      s = "status";
      st = "status";
    };
  };
}
