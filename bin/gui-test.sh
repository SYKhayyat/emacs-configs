#!/bin/sh
# Launch a profile in a GUI session on a private, off-screen X display.
#
# Why: a GUI launch on the real display puts windows on the user's screen. That
# is unacceptable for a test loop — the Hebrew stage in particular will need many
# GUI launches to look at bidi and font rendering. Xvfb gives a real frame with
# a real font stack and nobody is interrupted.
#
# Linux only (Xvfb is an X server). On macOS and Windows, skip this and test by
# hand. Exits non-zero if the display or Emacs fails.
#
# usage: bin/gui-test.sh <profile> [lisp-file ...]
#   bin/gui-test.sh hebrew /tmp/probe.el
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
profile=${1:?usage: gui-test.sh <profile> [lisp-file ...]}
shift || true

case "$profile" in
  hebrew|notes|ide) ;;
  *) echo "unknown profile: $profile" >&2; exit 2 ;;
esac
command -v Xvfb >/dev/null 2>&1 || { echo "Xvfb not found; run this by hand" >&2; exit 3; }

display=:$(( 90 + $(id -u) % 10 ))
cleanup() { [ -n "${xvfb_pid:-}" ] && kill "$xvfb_pid" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

Xvfb "$display" -screen 0 1400x900x24 >/dev/null 2>&1 &
xvfb_pid=$!
# Xvfb needs a moment before it accepts clients; poll instead of sleeping blind.
i=0
while [ $i -lt 40 ]; do
  DISPLAY="$display" xdpyinfo >/dev/null 2>&1 && break
  i=$((i + 1)); sleep 0.1
done

args=""
for f in "$@"; do args="$args -l $f"; done

# shellcheck disable=SC2086
DISPLAY="$display" emacs --init-directory="$root/configs/$profile" $args
