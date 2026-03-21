# disko-config.nix -- declarative disk partitioning for the VPS
#
# disko reads this during nixos-anywhere installs to partition and format the disk.
# After install, this also generates the fileSystems entries so you don't need to
# write them manually in configuration.nix.
{
  disko.devices.disk.main = {
    # The block device to partition. /dev/sda is typical for Hetzner cloud VMs.
    device = "/dev/sda";
    type = "disk";
    content = {
      # GPT partition table -- required for UEFI boot (supports EFI System Partition).
      # MBR (msdos) would be the alternative for legacy BIOS.
      type = "gpt";
      partitions = {
        # EFI System Partition: the bootloader lives here.
        # Type EF00 is the GPT type code for an EFI System Partition.
        esp = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";       # EFI requires FAT32
            mountpoint = "/boot";
          };
        };
        # Root partition: takes all remaining space on the disk.
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
