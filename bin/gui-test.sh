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

# A fixed display number races the previous run's teardown: if the old X server
# is still dying, the new Emacs can attach to it and get stray resize/focus
# events. That produced one unexplained "Beginning of buffer" in *Messages* in
# about one run in three, which is exactly the sort of thing a check must not
# have to explain away. Pick a free number, and wait for the server to exit.
display=""
for n in $(seq 90 120); do
  if [ ! -e "/tmp/.X$n-lock" ] && [ ! -S "/tmp/.X11-unix/X$n" ]; then
    display=":$n"
    break
  fi
done
[ -n "$display" ] || { echo "no free X display in :90-:120" >&2; exit 5; }

cleanup() {
  if [ -n "${xvfb_pid:-}" ]; then
    kill "$xvfb_pid" 2>/dev/null || true
    wait "$xvfb_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

Xvfb "$display" -screen 0 1400x900x24 >/dev/null 2>&1 &
xvfb_pid=$!
# Xvfb needs a moment before it accepts clients; poll instead of sleeping blind.
i=0
while [ $i -lt 40 ]; do
  DISPLAY="$display" xdpyinfo >/dev/null 2>&1 && break
  i=$((i + 1)); sleep 0.1
done

# Refuse, do not warn. A file loaded with -l that lacks a lexical-binding cookie
# makes Emacs print "Warning (files): Missing 'lexical-binding' cookie", which
# means the run has output that is not the configuration's — and a run whose
# output you have to explain cannot be trusted. Warning and continuing is the
# same bug as a checker that greps for "ok" and ignores everything else.
for f in "$@"; do
  if [ "$(head -1 "$f")" = ";; -*- lexical-binding: t; -*-" ]; then continue; fi
  printf 'refusing to run: %s has no lexical-binding cookie\n' "$f" >&2
  printf 'add this as its first line:\n  ;; -*- lexical-binding: t; -*-\n' >&2
  exit 4
done

args=""
for f in "$@"; do args="$args -l $f"; done

# shellcheck disable=SC2086
DISPLAY="$display" emacs --init-directory="$root/configs/$profile" $args
