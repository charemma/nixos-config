# desktop.nix -- X11 desktop environment for north (i3 + SDDM)
#
# termfilechooser is a flake input (not in nixpkgs), so it must be passed as an argument.
# The `let` block extracts the package for the current system once so we can reuse it.
{ config, lib, pkgs, termfilechooser, ... }:

let
  # Select the default package for the current system from the flake output.
  # pkgs.system is e.g. "x86_64-linux".
  termfilechooserPkg = termfilechooser.packages.${pkgs.system}.default;
in {
  services.xserver = {
    # Enable the X11 display server.
    enable = true;
    # Use i3 as the window manager (started by the display manager after login).
    windowManager.i3.enable = true;
    xkb = {
      # Two keyboard layouts available: US and Greek.
      layout = "us,gr";
      # alt+space cycles between the two layouts.
      options = "grp:alt_space_toggle";
    };
  };

  services.displayManager.sddm = {
    # SDDM is the login screen / display manager that launches the X session.
    enable = true;
    theme = "where_is_my_sddm_theme";
    # The theme requires Qt 5 compatibility libs which are not bundled with SDDM by default.
    extraPackages = [ pkgs.qt6.qt5compat ];
  };

  # GNOME Keyring stores passwords and SSH keys securely.
  services.gnome.gnome-keyring.enable = true;
  # Unlock the keyring automatically when SDDM logs in.
  security.pam.services.sddm.enableGnomeKeyring = true;
  # Allow i3lock to authenticate via PAM (needed for screen locking to work).
  security.pam.services.i3lock.enable = true;

  # XDG Desktop Portal provides a standardised API for sandboxed apps to access
  # host services (file picker, screen share, etc.) via D-Bus.
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    # GTK portal: handles most portal requests (file open dialogs etc.) for GTK apps.
    pkgs.xdg-desktop-portal-gtk
    # Our custom portal that opens yazi in the terminal instead of a GUI file picker.
    termfilechooserPkg
  ];
  # Tell the portal which backend to use for file chooser requests in i3 sessions.
  xdg.portal.config.i3 = {
    "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
  };

  # Configuration file for the termfilechooser portal.
  # environment.etc writes a file to /etc/ at the given path.
  environment.etc."xdg/xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${termfilechooserPkg}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
    default_dir=$HOME/Downloads
  '';

  services.printing = {
    enable = true;
    # Gutenprint provides drivers for a wide range of printers.
    drivers = [ pkgs.gutenprint ];
    # retry-job retries failed print jobs instead of cancelling them (useful for flaky printers).
    extraConf = "ErrorPolicy retry-job";
  };
  services.avahi = {
    # Avahi implements mDNS/DNS-SD for local network service discovery (e.g. network printers).
    enable = true;
    # nssmdns4 plugs Avahi into NSS so hostnames like printer.local resolve without manual DNS.
    nssmdns4 = true;
    # Open the mDNS port (5353/UDP) in the firewall.
    openFirewall = true;
  };

  services.libinput = {
    # libinput is the input device driver for mice and touchpads.
    enable = true;
    # Natural scrolling: content moves in the direction your fingers move (macOS style).
    mouse.naturalScrolling = true;
    touchpad.naturalScrolling = true;
  };

  # neovim is provided by nixvim (modules/nixvim.nix). The wrapped binary
  # already installs vi/vim aliases and sets EDITOR/VISUAL.

  environment.systemPackages = with pkgs; [
    brave
    feh
    i3lock-color
    flameshot
    xkb-switch-i3
    xclip
    fuzzel
    kitty
    keepassxc
    obsidian
    typora
    libreoffice
    zathura
    inkscape
    telegram-desktop
    caffeine-ng
    pavucontrol
    pulseaudio
    # polybar.override replaces the default derivation attributes.
    # pulseSupport = true compiles polybar with PulseAudio support for the volume module.
    (polybar.override { pulseSupport = true; })
    rofi
    xterm
    # overrideAttrs patches the build phase of the SDDM theme to inject our wallpaper.
    # The sed commands replace placeholders in theme.conf with the actual file path.
    # ${../assets/background-blurred.png} is a Nix path -- it gets copied to the store
    # and the store path is substituted in at build time.
    (where-is-my-sddm-theme.overrideAttrs (old: {
      installPhase = ''
        mkdir -p $out/share/sddm/themes/
        cp -r where_is_my_sddm_theme/ $out/share/sddm/themes/
        chmod +w $out/share/sddm/themes/where_is_my_sddm_theme/theme.conf
        sed -i \
          -e 's|^background=.*|background=${../assets/background-blurred.png}|' \
          -e 's|^backgroundFill=.*|backgroundFill=#2e3440|' \
          -e 's|^backgroundFillMode=.*|backgroundFillMode=fill|' \
          $out/share/sddm/themes/where_is_my_sddm_theme/theme.conf
      '';
    }))
  ];
}
