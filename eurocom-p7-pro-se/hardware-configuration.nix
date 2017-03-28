{ config, lib, pkgs, ... }:

{
    
    imports = [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix> ];

    boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];

    fileSystems."/" = { 
        device = "rpool"; 
        fsType = "zfs";
    };

    fileSystems."/tmp" = { 
        device = "rpool/tmp"; 
        fsType = "zfs";
    };

    fileSystems."/boot" = { 
        device = "/dev/disk/by-id/ata-PLEXTOR_PX-G128M6e_P02445180209-part1"; 
        fsType = "vfat";
        options = [ "umask=0022" ];
    };

    swapDevices = [ ];

    nix.maxJobs = 8;

}
