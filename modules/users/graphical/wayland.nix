{ pkgs, config, lib, ... }:
with lib;

# Work in progress.

let
  cfg = config.jd.graphical.wayland;
  systemCfg = config.machineData.systemConfig;
  dwlJD = pkgs.dwlBuilder {
    config.cmds = {
      term = [ "${pkgs.foot}/bin/foot" ];
      menu = [ "${pkgs.bemenu}/bin/bemenu-run" ];
      audioup = [ "${pkgs.scripts.soundTools}/bin/stools" "vol" "up" "5" ];
      audiodown = [ "${pkgs.scripts.soundTools}/bin/stools" "vol" "down" "5" ];
      audiomut = [ "${pkgs.scripts.soundTools}/bin/stools" "vol" "toggle" ];
    };
  };

  waylandStartup = pkgs.writeShellScriptBin "waylandStartup" ''
    if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
      eval $(dbus-launch --exit-with-session --sh-syntax)
    fi

    ## https://bbs.archlinux.org/viewtopic.php?id=224652
    ## Requires --systemd becuase of gnome-keyring error. Unsure how differs from systemctl --user import-environment
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP
    fi

    systemctl --user import-environment PATH

    systemctl --user start dwl-session.target
  '';
in
{
  options.jd.graphical.wayland = {
    enable = mkOption {
      type = types.bool;
      description = "Enable wayland";
    };

    type = mkOption {
      type = types.enum [ "dwl" ];
      description = ''What desktop/wm to use. Options: "dwl"'';
    };

    background = {
      enable = mkOption {
        type = types.bool;
        description = "Enable background [swaybg]";
      };

      pkg = mkOption {
        type = types.package;
        description = "Package to use for swaybg";
      };

      image = mkOption {
        type = types.path;
        description = "Path to image file used for background";
      };

      mode = mkOption {
        type = types.enum [ "stretch" "fill" "fit" "center" "tile" ];
        description = "Scaling mode for background";
      };
    };

    statusbar = {
      enable = mkOption {
        type = types.bool;
        description = "Enable status bar [waybar]";
      };

      pkg = mkOption {
        type = types.package;
        description = "Waybar package";
      };
    };

    screenlock = {
      enable = mkOption {
        type = types.bool;
        description = " Enable screen locking, must enable it on system as well for pamd (swaylock)";
      };

      #timeout = {
      #  script = mkOption {
      #    description = "Script to run on timeout. Default null";
      #    type = with types; nullOr package;
      #    default = null;
      #  };

      #  time = mkOption {
      #    description = "Time in seconds until run timeout script. Default 180.";
      #    type = types.int;
      #    default = 180;
      #  };
      #};

      #lock = {
      #  command = mkOption {
      #    description = "Lock command. Default xsecurelock";
      #    type = types.str;
      #    default = "${pkgs.xsecurelock}/bin/xsecurelock";
      #  };

      #  time = mkOption {
      #    description = "Time in seconds after timeout until lock. Default 180.";
      #    type = types.int;
      #    default = 180;
      #  };
      #};
    };
  };

  config = (mkIf cfg.enable) ({
    assertions = [{
      assertion = systemCfg.graphical.wayland.enable;
      message = "To enable xorg for user, it must be enabled for system";
    }];

    home.packages = with pkgs; mkIf (cfg.type == "dwl") [
      dwlJD
      foot
      bemenu
      wl-clipboard
      libappindicator-gtk3
      (if cfg.background.enable then swaybg else null)
      (assert systemCfg.graphical.wayland.swaylock-pam; (if cfg.screenlock.enable then swaylock else null))
    ];

    home.file =
      {
        ".winitrc" = {
          executable = true;
          text = ''
            # .winitrc autogenerated. Do not edit
            . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"

            # firefox enable wayland
            export MOZ_ENABLE_WAYLAND=1
            export XDG_CURRENT_DESKTOP=sway

            ${dwlJD}/bin/dwl -s "${waylandStartup}/bin/waylandStartup"
            wait $!
            systemctl --user stop dwl-session.target
            systemctl --user stop graphical-session.target
            systemctl --user stop graphical-session-pre.target
          '';
        };

        "${config.xdg.configHome}/foot/foot.ini" = {
          text = ''
            pad=2x2 center
            font=JetBrainsMono Nerd Font Mono
          '';
        };
      };

    systemd.user.targets.dwl-session = {
      Unit = {
        Description = "dwl compositor session";
        Documentation = [ "man:systemd.special(7)" ];
        BindsTo = [ "graphical-session.target" ];
        After = [ "graphical-session-pre.target" ];
      };
    };

    systemd.user.services.swaybg = mkIf cfg.background.enable {
      Unit = {
        Description = "swaybg background service";
        Documentation = [ "man:swabyg(1)" ];
        BindsTo = [ "dwl-session.target" ];
        After = [ "dwl-session.target" ];
      };

      Service = {
        ExecStart = "${cfg.background.pkg}/bin/swaybg --image ${cfg.background.image} --mode ${cfg.background.mode}";
      };

      Install = {
        WantedBy = [ "dwl-session.target" ];
      };
    };

    programs.waybar = mkIf cfg.statusbar.enable {
      enable = true;
      package = cfg.statusbar.pkg;
      settings = [
        ({
          layer = "bottom";

          modules-left = [ ];
          modules-center = [ "clock" ];
          modules-right = [ "cpu" "memory" "temperature" "battery" "backlight" "pulseaudio" "network" "tray" ];

          gtk-layer-shell = true;
          modules = {
            clock = {
              format = "{:%I:%M %p}";
              tooltip = true;
              tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
            };
            cpu = {
              interval = 10;
              format = "{usage}% ";
              tooltip = true;
            };
            memory = {
              interval = 30;
              format = "{used:0.1f}G/{total:0.1f}G ";
              tooltip = true;
            };
            temperature = { };
            battery = {
              bat = "BAT1";
              states = {
                good = 80;
                warning = 30;
                critical = 15;
              };
              format = "{capacity}% {icon}";
              format-charging = "{capacity}% ";
              format-plugged = "{capacity}% ";
              format-alt = "{time} {icon}";
              format-icons = [ "" "" "" "" "" ];
              tooltip = true;
              tooltip-format = "{timeTo}";
            };
            backlight = {
              device = "acpi_video1";
              format = "{percent}% {icon}";
              format-icons = [ "" "" ];
              on-scroll-up = "${pkgs.light}/bin/light -A 4";
              on-scroll-down = "${pkgs.light}/bin/light -U 4";
            };
            pulseaudio = {
              format = "{volume}% {icon} {format_source}";
              format-bluetooth = "{volume}% {icon} {format_source}";
              format-bluetooth-muted = "{volume}%  {format_source}";
              format-muted = "{volume}%  {format_source}";
              format-source = "{volume}% ";
              format-source-muted = "{volume}% ";
              format-icons = {
                "default" = [ "" "" "" ];
              };
              on-scroll-up = "${pkgs.scripts.soundTools}/bin/stools vol up 1";
              on-scroll-down = "${pkgs.scripts.soundTools}/bin/stools vol down 1";
              on-click-right = "${pkgs.scripts.soundTools}/bin/stools vol toggle";
              on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
              tooltip = true;
            };
            network = {
              interval = 60;
              interface = "wlp*";
              format-wifi = "{essid} ({signalStrength}%) ";
              format-ethernet = "{ipaddr}/{cidr} ";
              tooltip-format = "{ifname} via {gwaddr} ";
              format-linked = "{ifname} (No IP) ";
              format-disconnected = "Disconnected ⚠";
              format-alt = "{ifname}: {ipaddr}/{cidr}";
              tooltip = true;
            };
            tray = {
              spacing = 10;
            };
          };
        })
      ];
      style = ''
        * {
          font-size: 18px;
        }
      '';
      systemd.enable = true;
    };
    systemd.user.services.waybar = mkIf cfg.statusbar.enable {
      Unit.BindsTo = lib.mkForce [ "dwl-session.target" ];
      Unit.After = lib.mkForce [ "dwl-session.target" ];
      Install.WantedBy = lib.mkForce [ "dwl-session.target" ];
    };
  });
}


