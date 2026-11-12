#!/bin/sh
# Prove the agreed settings are actually in effect, in every profile, and that
# the generated files are current. Exits non-zero on any fault.
#
# A profile must *both* pass its invariants and start silently. Two earlier
# versions of this script were wrong in instructive ways:
#   1. it only looked for "ok", so it passed while a module printed
#      "startup fault: BOOM" — the fault merely scrolled past the grep;
#   2. it then grepped for keywords like error/warning, and a message that
#      says neither still slipped through.
# So the rule is not "no bad words" but "nothing but the expected line": any
# output at all beyond it fails the run.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
status=0

"$root/bin/build.sh" --check || status=1

for profile in hebrew notes ide; do
  out=$(emacs -Q --batch \
          -l "$root/configs/$profile/early-init.el" \
          -l "$root/configs/$profile/init.el" \
          -l "$root/test/invariants.el" 2>&1)

  if ! printf '%s\n' "$out" | grep -q "^ok   $profile"; then
    printf '%s\n' "$out"
    printf 'FAIL %s: invariants did not pass\n' "$profile"
    status=1
    continue
  fi

  # Everything except the expected line and blank lines.
  extra=$(printf '%s\n' "$out" | grep -v "^ok   $profile" | grep -v '^[[:space:]]*$')
  if [ -n "$extra" ]; then
    printf '%s\n' "$extra"
    printf 'FAIL %s: startup was not silent (see above)\n' "$profile"
    status=1
  else
    printf 'ok   %s\n' "$profile"
  fi
done

[ "$status" -eq 0 ] && printf 'clean: generated files current, 3 profiles, no faults\n'
exit $status
