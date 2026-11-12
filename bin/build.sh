#!/bin/sh
# Tangle + byte-compile the literate config. POSIX twin of bin\build.cmd.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
exec emacs -Q --batch -l "$root/bin/build.el" -- "$@"
