# desktop-wm.nix -- shared graphical base: X11 + i3 window manager, keyboard
# layout, a terminal (kitty) and the polybar status bar the i3 config launches.
# Every host that runs a desktop imports this. The display manager and any
# desktop applications are layered on top per host: north adds
# desktop-workstation.nix (SDDM + apps), aiagent adds autologin for its KVM
# console. The i3 and polybar configs themselves come from the user's dotfiles.
{ pkgs, ... }:
{
  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
    # US + Greek, alt+space toggles between them -- same on every host.
    xkb = {
      layout = "us,gr";
      options = "grp:alt_space_toggle";
    };
  };

  # Input devices: real ones, or a keyboard/pointer emulated over a KVM.
  services.libinput.enable = true;

  # Fonts the i3 config and polybar need: Hack Nerd Font for the bar/titles and
  # their glyphs, DejaVu for plain text. Application fonts live in the
  # workstation module. The Nerd Fonts attribute differs by nixpkgs vintage:
  # newer trees split it into nerd-fonts.<name>, older ones use nerdfonts with an
  # override -- pick whichever this host's nixpkgs provides.
  fonts.packages = [
    pkgs.dejavu_fonts
    (
      if pkgs ? nerd-fonts
      then pkgs.nerd-fonts.hack
      else pkgs.nerdfonts.override { fonts = [ "Hack" ]; }
    )
  ];

  # kitty is the terminal bound to $mod+Return; polybar is the status bar the i3
  # config launches on start. pulseSupport keeps the workstation's volume module
  # working and is harmless on hosts without audio.
  environment.systemPackages = [
    pkgs.kitty
    (pkgs.polybar.override { pulseSupport = true; })
  ];
}
