#!/bin/sh
# Launch a profile, daemon-first.
#
# Why a daemon: org-mode loads its own modules the first time an org buffer is
# created. Measured on this machine, the 340 KB sefer: 1.47-1.54 s for the first
# open of a session and 0.1-0.5 s for every open after it (the module chain
# alone is ~492 ms; the rest is reading the file and setting it up). A resident
# daemon pays that once at startup instead of once per launch, and every later
# file arrives through emacsclient in ~45 ms.
#
# One implementation for all three profiles. The per-profile launchers are thin
# wrappers, so this logic cannot drift between them.
#
# usage: bin/launch.sh <profile> [file ...]
set -eu
# The tree to run from. Default: this checkout, which is what a clone on any
# machine has. Nix sets EMACS_CONFIG_ROOT to a writable runtime tree instead,
# because a store copy of this repo cannot hold elpa/ or state/.
root=${EMACS_CONFIG_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
profile=${1:?usage: launch.sh <profile> [file ...]}
shift || true

case "$profile" in
  hebrew|notes|ide) ;;
  *) echo "unknown profile: $profile" >&2; exit 2 ;;
esac

command -v emacsclient >/dev/null 2>&1 || {
  echo "emacsclient not found; cannot use the daemon" >&2; exit 3; }

# A per-profile server name: three profiles must be able to run at once without
# one of them answering for another.
server="emacs-$profile"

if emacsclient -s "$server" --eval t >/dev/null 2>&1; then
  exec emacsclient -s "$server" -c "$@"
fi

# Not running, or not answering. Start it and wait for it to answer rather than
# sleeping a guessed interval: a daemon that failed to start must not leave us
# waiting, and a daemon that starts slowly must not be reported as failed.
emacs --init-directory="$root/configs/$profile" --daemon="$server" || {
  echo "daemon for $profile failed to start" >&2; exit 4; }

i=0
while [ $i -lt 300 ]; do
  if emacsclient -s "$server" --eval t >/dev/null 2>&1; then
    exec emacsclient -s "$server" -c "$@"
  fi
  i=$((i + 1))
  sleep 0.1
done

echo "daemon for $profile started but never answered" >&2
exit 5
