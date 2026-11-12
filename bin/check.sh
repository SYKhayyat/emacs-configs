#!/bin/sh
# Prove the agreed settings are actually in effect, in every profile, and that
# the generated files are current. Exits non-zero on the first failure.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
"$root/bin/build.sh" --check
status=0
for profile in hebrew notes ide; do
  emacs -Q --batch \
    -l "$root/configs/$profile/early-init.el" \
    -l "$root/configs/$profile/init.el" \
    -l "$root/test/invariants.el" 2>&1 | grep -E "^(ok|FAIL)" || status=1
done
exit $status
