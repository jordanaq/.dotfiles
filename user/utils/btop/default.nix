{ config, pkgs, ... }:
let
  btop-theme = "catppuccin_macchiato";
in {

  home.file.btop-themes = {
    source = ./assets/btop;
    target = ".config/btop";
    recursive = true;
  };

  programs.btop = {
    enable = true;
    package = pkgs.btop;
    extraConfig = ''
      # btop config (v1.2.9 defaults), catppuccin_macchiato theme
      # Theme: <name>.theme must live in ~/.config/btop/themes/ (provisioned by home.file.btop-themes)

      color_theme = "~/.config/btop/themes/${btop-theme}.theme"

      # False = terminal background transparency
      theme_background = True

      # False converts 24-bit to 256-color
      truecolor = True

      force_tty = False

      # Layout presets: "box:P:G", presets separated by spaces; e.g. "cpu:0:default,mem:0:tty"
      presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty"

      vim_keys = False

      # Ignored in TTY mode
      rounded_corners = True

      # braille|block|tty — braille highest res but needs font support, tty most compatible
      graph_symbol = "braille"
      graph_symbol_cpu = "default"
      graph_symbol_mem = "default"
      graph_symbol_net = "default"
      graph_symbol_proc = "default"

      # Values: cpu mem net proc, whitespace-separated
      shown_boxes = "cpu mem net proc"

      # ms; >=2000 recommended for better graph sample times
      update_ms = 300

      # "cpu lazy" = top over time, "cpu direct" = updates top directly
      proc_sorting = "cpu lazy"
      proc_reversed = False
      proc_tree = False
      proc_colors = True
      proc_gradient = True

      # Cpu % of the core it runs on vs total available power
      proc_per_core = False
      proc_mem_bytes = True
      proc_cpu_graphs = True

      # Use /proc/[pid]/smaps (slow but more accurate)
      proc_info_smaps = False
      proc_left = False

      # Filter kernel processes (htop-like)
      proc_filter_kernel = False

      # Pick from detected attributes in the options menu
      cpu_graph_upper = "total"

      # Pick from detected attributes in the options menu
      cpu_graph_lower = "total"
      cpu_invert_lower = True

      # Disables the lower cpu graph
      cpu_single_graph = False
      cpu_bottom = False
      show_uptime = True
      check_temp = True

      # "Auto" or pick a sensor from the options menu
      cpu_sensor = "Auto"
      show_coretemp = True

      # Remap misread cores: "wrong:correct" space-separated, e.g. "4:0 5:1 6:3"
      cpu_core_map = ""
      temp_scale = "celsius"

      # KB (1000) instead of KiB (1024)
      base_10_sizes = False
      show_cpu_freq = True

      # strftime format; placeholders /host /user /uptime
      clock_format = "%X"

      # False if menus flicker too much
      background_update = True
      custom_cpu_name = ""

      # Full mountpoints, space-separated; prefix "exclude=" to invert the filter
      disks_filter = ""
      mem_graphs = True
      mem_below_net = False

      # Count ZFS ARC in cached and available memory
      zfs_arc_cached = True
      show_swap = True

      # Show swap as a disk, inserted after the first disk
      swap_disk = True
      show_disks = True

      # False includes network/RAM disks
      only_physical = True

      # Read disks from /etc/fstab; disables only_physical
      use_fstab = True

      # True = only ZFS pools (hides datasets)
      zfs_hide_datasets = False
      disk_free_priv = False
      show_io_stat = True
      io_mode = False
      io_graph_combined = False

      # MiB/s cap per mount: "path:speed" space-separated, e.g. "/:20 /mnt/media:100"
      io_graph_speeds = ""

      # Fixed Mebibit values, used only when net_auto = False
      net_download = 100

      net_upload = 100

      # Auto-rescales, overrides the fixed values above
      net_auto = True

      # Syncs download/upload to whichever scale is higher
      net_sync = True

      # Initial network interface
      net_iface = ""
      show_battery = True

      # "Auto" or pick a battery when several are present
      selected_battery = "Auto"

      # ERROR|WARNING|INFO|DEBUG (includes all lower levels)
      log_level = "WARNING"
    '';
  };
}