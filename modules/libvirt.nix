# libvirt.nix -- KVM/QEMU virtual machines via libvirt
#
# Enables libvirtd and virt-manager for local VMs (e.g. Whonix Gateway and
# Workstation). charemma joins the libvirtd group so virsh/virt-manager work
# against qemu:///system without sudo.
{ config, lib, pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
    # TPM emulation and UEFI firmware are available by default; swtpm adds
    # software TPM support for guests that want it.
    qemu.swtpm.enable = true;
  };

  programs.virt-manager.enable = true;

  charemma.extraGroups = [ "libvirtd" ];
}
