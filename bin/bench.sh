#!/bin/sh
# Print the price of what is installed, per profile.
#
# Two numbers matter and they are different:
#   * "floor"  — how long Emacs itself takes to start, with no config at all.
#   * "TOTAL"  — from process start to the end of our last module.
# Everything between them is this repository's cost.
#
# Batch mode does not load init files, so the two loaders are passed with -l.
# That skips `emacs-startup-hook' (the GC restore), which changes nothing about
# how long loading takes.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)

floor() {
  best=""
  for _ in 1 2 3; do
    t0=$(date +%s%N)
    emacs -Q --batch --eval nil >/dev/null 2>&1
    t1=$(date +%s%N)
    ms=$(( (t1-t0)/1000000 ))
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms; fi
  done
  echo "$best"
}

echo "floor (emacs -Q --batch, best of 3): $(floor) ms"
for profile in hebrew notes ide; do
  echo
  echo "== profile: $profile"
  MY_BENCH=1 emacs -Q --batch \
    -l "$root/configs/$profile/early-init.el" \
    -l "$root/configs/$profile/init.el" 2>&1
done
