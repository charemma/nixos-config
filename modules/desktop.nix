{ config, lib, pkgs, ... }:

{
  programs.i3.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.gnome.gnome-keyring.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  environment.systemPackages = with pkgs; [
    brave
    feh
    fuzzel
    kitty
    flameshot

    # i3/X11 fallback
    i3
    polybar
    rofi
    xterm
  ];
}
