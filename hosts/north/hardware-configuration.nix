{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/ee571966-d3bd-4851-8647-98e5e00f4cdb";
      fsType = "ext4";
    };

  fileSystems."/boot/efi" =
    { device = "/dev/disk/by-uuid/F4D6-86F1";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/c0a3259a-3532-481b-87b4-2e8819921a89";
      fsType = "ext4";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/de064734-03ae-491f-b24c-78fc094879a4"; }
      { device = "/dev/disk/by-uuid/b9f6686a-ee65-4313-b09b-847b8b8e4de0"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
