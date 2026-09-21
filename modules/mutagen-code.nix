# Mutagen sync of /code for NixOS spokes (north).
#
# Replaces the former NFS mount of aiagent's /code. Each spoke keeps a local,
# writable copy of /code and syncs it against the aiagent hub over SSH. See
# mutagen-code-common.nix for the shared session parameters and the rationale
# for mode A (full copies, .git included).
#
# Runs as a system service (like services.syncthing) rather than a user service
# so the sync comes up at boot without needing an interactive login. The hub is
# reached as charemma over SSH; charemma's key must be authorised on aiagent and
# aiagent's host key must be known (one-time "ssh charemma@aiagent ..." to seed).
{ lib, pkgs, ... }:
let
  common = import ./mutagen-code-common.nix;
  mutagen = "${pkgs.mutagen}/bin/mutagen";
  ignoreArgs = lib.concatMapStringsSep " " (p: "--ignore=${p}") common.ignores;

  ensureSession = pkgs.writeShellScript "mutagen-ensure-code" ''
    set -u
    # Wait for the daemon to accept commands before touching sessions.
    for _ in $(seq 1 30); do
      ${mutagen} sync list >/dev/null 2>&1 && break
      sleep 1
    done
    # Create the session once; the fixed name keeps this idempotent on restarts.
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

  # Local, writable /code (replaces the former NFS mount).
  systemd.tmpfiles.rules = [ "d /code 0755 charemma charemma -" ];

  systemd.services.mutagen-code = {
    description = "Mutagen sync of /code against the aiagent hub";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # ssh is the transport mutagen uses to reach the hub.
    path = [ pkgs.openssh ];
    serviceConfig = {
      User = "charemma";
      Type = "simple";
      Environment = "HOME=/home/charemma";
      ExecStart = "${mutagen} daemon run";
      ExecStartPost = "${ensureSession}";
      Restart = "always";
      RestartSec = "10";
    };
  };
}
