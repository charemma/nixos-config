{ config, lib, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    windowManager.i3.enable = true;
    xkb = {
      layout = "us,gr";
      options = "grp:alt_shift_toggle";
    };
  };

  # Niri as Wayland alternative
  programs.niri.enable = true;

  services.gnome.gnome-keyring.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  services.libinput = {
    enable = true;
    mouse.naturalScrolling = true;
    touchpad.naturalScrolling = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  environment.systemPackages = with pkgs; [
    brave
    feh
    flameshot
    fuzzel
    kitty
    keepassxc
    pavucontrol
    pulseaudio
    (polybar.override { pulseSupport = true; })
    rofi
    xterm
  ];
}
