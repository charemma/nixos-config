# Wake-on-LAN for hosts on the home LAN. The magic packet is a LAN broadcast,
# so run this from a machine on that LAN (aiagent has wakeonlan installed).
# Adding a host: one MAC constant plus one recipe that calls _wake.

_north_mac := "10:7c:61:45:d8:99"
_boot_timeout_seconds := "120"

_default:
    @just --list wake

# wake north and wait until it answers pings
north: (_wake "north" _north_mac)

_wake host mac:
    #!/usr/bin/env bash
    set -euo pipefail
    wakeonlan {{ mac }} >/dev/null
    echo "magic packet sent to {{ host }} ({{ mac }}), waiting for it to come up"
    deadline=$((SECONDS + {{ _boot_timeout_seconds }}))
    until ping -c1 -W2 {{ host }} >/dev/null 2>&1; do
        if (( SECONDS >= deadline )); then
            echo "{{ host }} did not answer within {{ _boot_timeout_seconds }}s" >&2
            exit 1
        fi
        sleep 2
    done
    echo "{{ host }} is up after ${SECONDS}s"
