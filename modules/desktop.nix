{ config, lib, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
    xkb = {
      layout = "us,gr";
      options = "grp:alt_shift_toggle";
    };
  };

  services.displayManager.sddm = {
    enable = true;
    theme = "where_is_my_sddm_theme";
    extraPackages = [ pkgs.qt6.qt5compat ];
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.i3lock.enable = true;
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
    i3lock-color
    flameshot
    xclip
    fuzzel
    kitty
    keepassxc
    obsidian
    typora
    telegram-desktop
    pavucontrol
    pulseaudio
    (polybar.override { pulseSupport = true; })
    rofi
    xterm
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
