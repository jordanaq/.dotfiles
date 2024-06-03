{ config, pkgs, ... }:
let
  hypr-dir = ".config/hypr";
in {
  imports = [
    ./catppuccin.nix
    ./utils/default.nix
    ./waybar/default.nix
  ];

  home.packages = with pkgs; [
    polkit-kde-agent
    xdg-desktop-portal-hyprland
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    xwaylandvideobridge
    tty-clock
    hyprcursor
    catppuccin-cursors
  ];

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  home.file.hypr-conf = {
    source = ./assets/hypr/scripts;
    target = "${hypr-dir}/scripts";
    recursive = true;
  };

  #home.hardware = {
  #  opengl.enable = true;
  #};

  wayland.windowManager.hyprland = {
    enable = true;

    settings = {
      exec-once = [
        "${hypr-dir}/scripts/launch_waybar &"
        "${hypr-dir}/scripts/tools/dynamic &"
      ];

      env = [
        
      ];

      # Appearance
      "general" = {
        "gaps_in" = "3";
        "gaps_out" = "10";
        "border_size" = "3";
        "col.active_border" = "0xfff5c2e7";
        "col.inactive_border" = "0xff45475a";
        # "col.group_border" = "0xff89dceb";
        # "col.group_border_active" = "0xfff9e2af";
        "layout" = "dwindle";
      };

      "dwindle" = {
        "pseudotile" = "1";
        "force_split" = "10";
      };

      "decoration" = {
        # Window Decorations
        "rounding" = "5";
        "drop_shadow" = "true";
        "shadow_range" = "50";
        "shadow_offset" = "-2.0 2.0";
        "shadow_render_power" = "5";
        
        # Blur
        "blur" = {
          "enabled" = "true";
          "size" = "8";
          "passes" = "1";
          "ignore_opacity" = "true";
          "new_optimizations" = "true";
          "xray" = "false";
          "noise" = "0.0117";
          "contrast" = "0.8916";
          "brightness" = "0.8172";
          "vibrancy" = "0.1696";
          "vibrancy_darkness" = "0.0";
          "special" = "false";
          "popups" = "false";
          "popups_ignorealpha" = "0.2";
        };
      };

      "animations" = {
        "enabled" = "true";
        "first_launch_animation" = "true";
        "bezier" = "overshot,0.13,0.99,0.29,1.1";
        "animation" = [
          "windows,1,4,overshot,slide"
          "border,1,10,default"
          "fade,1,10,default"
          "workspaces,1,6,overshot,slidevert"
        ];
      };

      "source" = "~/${hypr-dir}/catppuccin/macchiato.conf";

      "input" = {
        "repeat_rate" = "25";
        "repeat_delay" = "600";
        "sensitivity" = "0.0";
        "accel_profile" = "flat";
        "force_no_accel" = "false";
        "scroll_factor" = "1.0";
        "natural_scroll" = "false";
        "follow_mouse" = "2";

        "touchdevice" = {
          "enabled" = "false";
        };
      };

      "group" = {
        "insert_after_current" = "true";
        "focus_removed_window" = "true";

        "groupbar" = {
          "enabled" = "true";
          "font_size" = "8";
          "gradients" = "true";
          "height" = "14";
          "scrolling" = "true";
        };
      };

      "misc" = {
        "disable_hyprland_logo" = "false";
        "disable_splash_rendering" = "false";
        "animate_manual_resizes" = "true";
        "animate_mouse_windowdragging" = "true";
        "focus_on_activate" = "false";
        "render_ahead_of_time" = "true";
        "render_ahead_safezone" = "1";
        "initial_workspace_tracking" = "1";
      };

      "monitor" = [
        "DP-2, highrr, 0x0, 1"
        ", highrr, auto, 1"
      ];

      "$mod" = "SUPER";

      bind = [
        # Utils
        ", Print, exec, ~/${hypr-dir}/scripts/screenshot"
        "$mod, T, exec, kitty"
        "$mod, space, exec, wofi --show drun"

        # Media
        "$mod, F, exec, firefox"

        # Windows
        "Alt_L, Tab, cyclenext, "
        "$mod, C, killactive, "
        "$mod&Shift, C, exec, hyprctl kill"
        "$mod, Up, movefocus, u"
        "$mod, Down, movefocus, d"
        "$mod, Left, movefocus, l"
        "$mod, Right, movefocus, r"
        "$mod, F11, fullscreen, 1"
        "$mod, F12, fakefullscreen, "
        "$mod, P, pseudo, "
        "$mod, V, togglefloating, "

        # Groups
        "$mod, G, togglegroup"
        "$mod, tab, changegroupactive"

        # Workspaces
        "$mod, mouse_down, workspace, e-1"
        "$mod, mouse_up, workspace, e+1"
      ];# ++ (
      #  builtins.concatLists (
      #    builtins.genList (
      #      x: let
      #        ws = let
      #          c = (x + 1) / 10;
      #        in
      #          builtins.toString (x + 1 - (c * 10));
      #      in [
      #        "$mod, ${ws}, workspace, ${toString (x+1)}"
      #        "$mod SHIFT, ${ws}, movetoworkspace, ${toString(x + 1)}"
      #      ]
      #    )
      #    10
      #  )
      #);

      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
        "$mod, mouse:274, togglefloating"
      ];
    };
  };
}
