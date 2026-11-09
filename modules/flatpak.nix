# flatpak.nix -- declarative Flatpak apps via nix-flatpak.
#
# For apps that are no longer (or never were) in nixpkgs. Brave was dropped
# from nixpkgs because nobody could ship its security fixes in time; the
# Flathub build is updated by Brave directly.
#
# nix-flatpak installs and removes the listed apps on activation and runs a
# periodic update, so this list stays the single source of truth.
{ ... }:

{
  services.flatpak = {
    enable = true;
    remotes = [{
      name = "flathub";
      location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    }];
    packages = [
      "com.brave.Browser"
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
