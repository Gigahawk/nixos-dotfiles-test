{
  description = "System Config";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-flake = { url = "github:jordanisaacs/neovim-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils"; };
    st-flake = {
      url = "github:jordanisaacs/st-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    dwm-flake = {
      url = "github:jordanisaacs/dwm-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    flake-utils.url = "github:numtide/flake-utils";
    nur.url = "github:nix-community/NUR";
  };

  outputs = { nixpkgs, home-manager, nur, neovim-flake, st-flake, dwm-flake, ... }@inputs:
  let
    inherit (nixpkgs) lib;

    util = import ./lib {
      inherit system pkgs home-manager lib; inherit overlays;
    };

    scripts = import ./scripts {
      inherit pkgs lib;
    };

    inherit (import ./pkgs {
      inherit pkgs;
    }) myPkgs;

    inherit (import ./overlays {
      inherit system pkgs lib nur neovim-flake st-flake dwm-flake scripts myPkgs;
    }) overlays;

    inherit (util) user;
    inherit (util) host;

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      inherit overlays;
    };

    system = "x86_64-linux";

    laptopConfig = {
      core.enable = true;
      boot = "encrypted-efi";
      laptop = {
        enable = true;
      };
      gnome = {
        enable = true;
        keyring = {
          enable = true;
        };
      };
      connectivity = {
        bluetooth.enable = true;
        sound.enable = true;
        printing.enable = true;
      };
      xserver = {
        enable = true;
        display-manager = {
          type = "startx";
        };
      };
    };
    
    laptopUsers = [{
      name = "jd";
      groups = [ "wheel" "networkmanager" "video" ];
      uid = 1000;
      shell = pkgs.zsh;
    }];

  in {
    installMedia = {
      kde = host.mkISO {
        name = "nixos";
        kernelPackage = pkgs.linuxPackages_latest;
        initrdMods = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" "nvme" "usbhid" ];
        kernelMods = [ "kvm-intel" "kvm-amd" ];
        kernelParams = [ ];
        systemConfig = { };
      };
    };
    homeManagerConfigurations = {
      jd = user.mkHMUser {
        userConfig = {
          desktop = {
            type = "dwm";
            screenlock.enable = true;
          };
          applications.enable = true;
          gpg.enable = true;
          git.enable = true;
          zsh.enable = true;
          office365 = {
            enable = true;
            onedriver.enable = false; # pkg currently broken
          };
        };
        username = "jd";
      };
    };

    nixosConfigurations = {
      laptop = host.mkHost {
        name = "laptop";
        NICs = [ "enp0s31f6" "wlp2s0" ];
        kernelPackage = pkgs.linuxPackages;
        initrdMods = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
        kernelMods = [ "kvm-intel" ];
        kernelParams = [];
        systemConfig = laptopConfig;
        users = laptopUsers;
        cpuCores = 4;
      };

      framework = host.mkHost {
        name = "framework";
        NICs = [ "wlp170s0" ];
        kernelPackage = pkgs.linuxPackages_latest;
        initrdMods = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
        kernelMods = [ "kvm-intel" ];
        kernelParams = [];
        systemConfig = laptopConfig;
        users = laptopUsers;
        cpuCores = 8;
        passthru = {
          hardware.video.hidpi.enable = true;
        };
        stateVersion = "21.11";
      };
    };
  };
}
