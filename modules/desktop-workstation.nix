# desktop-workstation.nix -- full workstation desktop layered on the shared
# graphical base (desktop-wm.nix): SDDM login + theme, printing, scanning, XDG
# portals, application fonts and GUI apps. north imports both this and desktop-wm.
#
# termfilechooser is a flake input (not in nixpkgs), so it must be passed as an argument.
# The `let` block extracts the package for the current system once so we can reuse it.
{ config, lib, pkgs, termfilechooser, ... }:

let
  # Select the default package for the current system from the flake output.
  # pkgs.system is e.g. "x86_64-linux".
  termfilechooserPkg = termfilechooser.packages.${pkgs.system}.default;

  # simple-scan post-processing script: OCR the freshly scanned PDF.
  # Configure simple-scan preferences to run "ocr-script" as post-processor.
  # simple-scan args: $1=mime, $2=keep_original, $3=filename, $4..=extra args.
  ocrScript = pkgs.writeShellApplication {
    name = "ocr-script";
    runtimeInputs = with pkgs; [ ocrmypdf libnotify ];
    text = ''
      filename=$3
      keep_original=$2

      if [[ "$keep_original" == "true" ]]; then
        ocr_filename="''${filename%.*}.ocr.''${filename##*.}"
        extra_msg_details="Saved as ''${ocr_filename##*/}.\nOriginal saved as ''${filename##*/}."
      else
        extra_msg_details="Saved as ''${filename##*/}."
      fi

      LOG_FILE=/tmp/ocr.log
      : > "$LOG_FILE"

      # notify-send fails when no notification daemon is running on the session
      # bus. Do not let that kill the script (set -o errexit) so simple-scan
      # reports success when the OCR itself succeeded.
      if ! ocrmypdf --deskew --clean --force-ocr -l deu+ell "$filename" "''${ocr_filename-$filename}" &>> "$LOG_FILE"; then
        notify-send -i scanner "OCR Failed" "See $LOG_FILE" || true
        exit 1
      fi

      notify-send -i scanner "OCR Complete" "$extra_msg_details" || true
    '';
  };
in {
  # X11, i3 and the keyboard layout come from desktop-wm.nix (shared base).

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
    # cups-browsed keeps re-creating a duplicate temporary queue for the HP via
    # mDNS. Since the printer is declared statically below, browsed only adds noise.
    browsed.enable = false;
    # Gutenprint provides drivers for a wide range of printers.
    drivers = [ pkgs.gutenprint ];
    # retry-job retries failed print jobs instead of cancelling them (useful for flaky printers).
    extraConf = "ErrorPolicy retry-job";
  };

  # Declarative printer queue for the HP LaserJet Pro M148fdw at 192.168.1.33
  # (DHCP-reserved). Uses driverless IPP Everywhere, no cups-browsed needed.
  hardware.printers = {
    ensurePrinters = [{
      name = "HP-M148fdw";
      location = "Home";
      deviceUri = "ipp://192.168.1.33/ipp/print";
      model = "everywhere";
    }];
    ensureDefaultPrinter = "HP-M148fdw";
  };

  # dconf provides the GSettings backend GTK apps need to persist settings.
  # Without it, GSettings falls back to the memory backend and the GTK file
  # chooser (rendered by xdg-desktop-portal-gtk) cannot remember its window
  # size: every dialog opens at the portal default and re-imposes that size a
  # second after opening, once the folder listing loads, discarding any manual
  # resize. With dconf enabled the dialog remembers and reopens at the last
  # size, so it no longer snaps back. Under i3 (no GNOME) this is not pulled in
  # automatically, so enable it explicitly.
  programs.dconf.enable = true;

  # SANE backend for scanners. simple-scan below is the GUI.
  hardware.sane.enable = true;

  # Scan our HP M148fdw over eSCL via sane-airscan, not the sane-backends
  # built-in "escl" backend. The built-in backend has long-standing bugs with
  # HP ADF scanning: it starts a job but fails to trigger the feeder transport
  # and aborts immediately without pulling a page. sane-airscan drives the same
  # eSCL protocol reliably (it is what macOS-style AirScan clients use).
  hardware.sane.extraBackends = [ pkgs.sane-airscan ];

  # Disable backends that probe the network for scanners we don't own. Each of
  # these adds 0.3-2s to simple-scan startup while looking for Epson / Kodak /
  # Canon / Konica devices via mDNS or broadcast. Also disable the broken
  # built-in "escl" backend so simple-scan sees only the airscan device (no
  # duplicate entries, no chance of picking the backend that aborts on ADF).
  hardware.sane.disabledDefaultBackends = [
    "escl"
    "net"
    "epsonds"
    "epson2"
    "kodakaio"
    "magicolor"
    "pixma"
    "dell1600n_net"
  ];

  # Pin the eSCL scanner (HP LaserJet Pro M148fdw at 192.168.1.33) and disable
  # mDNS discovery so simple-scan does not spend startup time probing the
  # network. The manual device entry uses the eSCL protocol on the known URL.
  environment.etc."sane.d/airscan.conf".text = ''
    [devices]
    "HP LaserJet Pro M148fdw" = https://192.168.1.33:443/eSCL, eSCL

    [options]
    discovery = disable
  '';

  fonts.packages = with pkgs; [
    corefonts
    dejavu_fonts
    liberation_ttf
    noto-fonts
    noto-fonts-color-emoji
  ];

  # Run AppImages transparently: `programs.appimage.enable` installs the
  # appimage-run wrapper; `binfmt = true` registers a kernel binfmt handler
  # so `./foo.AppImage` executes directly without wrapping.
  programs.appimage = {
    enable = true;
    binfmt = true;
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
    # libinput itself is enabled in desktop-wm.nix; here we add only the
    # workstation's natural-scrolling preference.
    mouse.naturalScrolling = true;
    touchpad.naturalScrolling = true;
  };

  # neovim is provided by nixvim (modules/nixvim.nix). The wrapped binary
  # already installs vi/vim aliases and sets EDITOR/VISUAL.

  environment.systemPackages = with pkgs; [
    brave
    dunst
    feh
    i3lock-color
    flameshot
    xkb-switch-i3
    xclip
    fuzzel
    keepassxc
    ente-auth
    simple-scan
    ocrmypdf
    (tesseract.override { enableLanguages = [ "eng" "deu" "ell" ]; })
    ocrScript
    pdfarranger
    obsidian
    typora
    libreoffice
    gimp
    zathura
    inkscape
    poppler-utils
    telegram-desktop
    caffeine-ng
    pavucontrol
    pulseaudio
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
