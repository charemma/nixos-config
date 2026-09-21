# Mutagen sync of /code for macbook (nix-darwin).
#
# nix-darwin has no systemd, so the daemon runs as a launchd user agent (same
# pattern as syncthing-darwin.nix). Replaces the former NFS autofs mount.
#
# macOS quirk: the root volume is sealed/read-only, so /code cannot be a plain
# directory. The sync target is a real directory on the Data volume
# (/Users/charemma/code); /code is exposed as a firmlink to it via
# synthetic.conf (same trick the old NFS setup used). The firmlink only appears
# after a reboot, but the sync itself works immediately against the real path.
{ lib, pkgs, ... }:
let
  common = import ./mutagen-code-common.nix;
  mutagen = "${pkgs.mutagen}/bin/mutagen";
  localCode = "/Users/charemma/code";
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
        ${localCode} ${common.hubEndpoint} || true
    fi
  '';
in
{
  environment.systemPackages = [ pkgs.mutagen ];

  # Back /code with a writable dir on the Data volume and expose it at /code via
  # a synthetic.conf firmlink. Migrates any prior plain "code" entry (the old
  # NFS mountpoint) to the firmlink form.
  system.activationScripts.mutagenCode.text = ''
    mkdir -p ${localCode}
    chown charemma:staff ${localCode}
    if ! grep -q 'Users/charemma/code' /etc/synthetic.conf 2>/dev/null; then
      echo "setting up /code firmlink via /etc/synthetic.conf..."
      grep -v '^code' /etc/synthetic.conf 2>/dev/null > /etc/synthetic.conf.tmp || true
      mv /etc/synthetic.conf.tmp /etc/synthetic.conf
      printf 'code\tUsers/charemma/code\n' >> /etc/synthetic.conf
      /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t || true
    fi
  '';

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
