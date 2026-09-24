# Mutagen sync of /code for macbook (nix-darwin).
#
# nix-darwin has no systemd, so the daemon runs as a launchd user agent (same
# pattern as syncthing-darwin.nix). Replaces the former NFS autofs mount.
#
# /code must be a REAL directory (not a symlink): Node resolves symlinks in
# process.cwd(), so a symlinked /code would make Claude session paths differ
# from the other hosts. The single-name synthetic.conf entry ("code", no tab
# target) creates a real, writable directory on the Data volume that appears at
# the canonical path /code -- so realpath(/code) stays /code, matching north's
# bind mount. The data lives directly at /code; ~/code is never used.
{ lib, pkgs, ... }:
let
  common = import ./mutagen-code-common.nix;
  mutagen = "${pkgs.mutagen}/bin/mutagen";
  binPath = "${pkgs.mutagen}/bin:${pkgs.openssh}/bin:/usr/bin:/bin";
  ignoreArgs = lib.concatMapStringsSep " " (p: "--ignore=${p}") common.ignores;

  ensureSession = pkgs.writeShellScript "mutagen-ensure-code" ''
    set -u
    for _ in $(seq 1 30); do
      ${mutagen} sync list >/dev/null 2>&1 && break
      sleep 1
    done
    if ! ${mutagen} sync list ${common.sessionName} >/dev/null 2>&1; then
      ${mutagen} sync create \
        --name=${common.sessionName} \
        --sync-mode=two-way-safe \
        ${ignoreArgs} \
        /code ${common.hubEndpoint} || true
    fi
  '';
in
{
  environment.systemPackages = [ pkgs.mutagen ];

  # Ensure /code is the real-dir firmlink form, and tear down the old NFS autofs
  # direct map that used to mount on /code. These edit config files that take
  # effect on the next boot; ownership is fixed up at boot by the daemon below.
  system.activationScripts.mutagenCode.text = ''
    if ! grep -q '^code$' /etc/synthetic.conf 2>/dev/null; then
      grep -v '^code' /etc/synthetic.conf 2>/dev/null > /etc/synthetic.conf.tmp || true
      mv /etc/synthetic.conf.tmp /etc/synthetic.conf 2>/dev/null || true
      printf 'code\n' >> /etc/synthetic.conf
      /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t || true
    fi
    if grep -q '/etc/auto_code' /etc/auto_master 2>/dev/null; then
      grep -v '/etc/auto_code' /etc/auto_master > /etc/auto_master.tmp || true
      mv /etc/auto_master.tmp /etc/auto_master
      /usr/sbin/automount -vc 2>/dev/null || true
    fi
  '';

  # Runs as root at boot: /code (real Data-volume dir) is created root-owned, so
  # hand it to charemma before the user's mutagen agent tries to write it.
  launchd.daemons.mutagen-code-prepare = {
    script = ''
      /bin/mkdir -p /code
      /usr/sbin/chown charemma:staff /code
    '';
    serviceConfig.RunAtLoad = true;
  };

  launchd.user.agents.mutagen-code-daemon = {
    command = "${mutagen} daemon run";
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/charemma/Library/Logs/mutagen.log";
      StandardErrorPath = "/Users/charemma/Library/Logs/mutagen.log";
      EnvironmentVariables.PATH = binPath;
    };
  };

  # Ensures the session exists once the daemon is up (own agent because launchd
  # has no ExecStartPost equivalent; the script waits for the daemon socket).
  launchd.user.agents.mutagen-code-session = {
    command = "${ensureSession}";
    serviceConfig = {
      RunAtLoad = true;
      EnvironmentVariables.PATH = binPath;
    };
  };
}
