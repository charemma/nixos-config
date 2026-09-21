# Shared parameters for the /code Mutagen sync sessions.
#
# aiagent is the always-on hub; north and macbook are spokes that each run a
# two-way-safe session against it (hub-and-spoke, not a mesh). Imported by
# mutagen-code.nix (NixOS spokes) and mutagen-code-darwin.nix (macbook).
{
  # SSH endpoint of the hub, as consumed by "mutagen sync create".
  hubEndpoint = "charemma@aiagent.tail48929d.ts.net:/code";

  # Session name on each spoke's own daemon (names are per-daemon, so reusing
  # the same name on every spoke is fine and keeps session creation idempotent).
  sessionName = "code";

  # gitignore-style patterns excluded from the sync. .git is deliberately NOT
  # ignored -- this is mode A, full byte-identical working copies. But the
  # three hosts run different platforms (x86_64-linux, aarch64-linux,
  # aarch64-darwin), so arch-specific, regenerable build and dependency trees
  # must never travel between them.
  ignores = [
    ".DS_Store"
    ".direnv/"
    "node_modules/"
    "target/"
    ".venv/"
    "__pycache__/"
    "result"
    "result-*"
  ];
}
