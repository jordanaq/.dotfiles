{ configs, pkgs, ... }:

{
  programs.git = {
    enable = true;

    lfs.enable = true;

    settings = {
      user.name = "jordanaq";
      user.email = "quinn.jordan@protonmail.ch";

      alias = {
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
        smu = "submodule update --init --recursive";
        st = "status";
      };
    };
  };
}
