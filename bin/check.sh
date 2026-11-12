#!/bin/sh
# Prove the agreed settings are actually in effect, in every profile, in both a
# batch and a GUI run, and that the generated files are current.
#
# The rule this script exists to enforce: a run must be SILENT. Two earlier
# versions were wrong in instructive ways, and both were "warn and continue":
#   1. it only looked for "ok", so it passed while a module printed
#      "startup fault: BOOM" — the fault merely scrolled past the grep;
#   2. it then grepped for error/warning keywords, and a message containing
#      neither went straight through.
# So there is no keyword list here. The only permitted output is the expected
# line, and the only permitted GUI output is none at all.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
status=0
profiles="hebrew notes ide"

fail() { printf 'FAIL %s\n' "$1"; status=1; }

"$root/bin/build.sh" --check || status=1

# ---- batch ---------------------------------------------------------------
for profile in $profiles; do
  out=$(emacs -Q --batch \
          -l "$root/configs/$profile/early-init.el" \
          -l "$root/configs/$profile/init.el" \
          -l "$root/test/invariants.el" 2>&1)

  if ! printf '%s\n' "$out" | grep -q "^ok   $profile"; then
    printf '%s\n' "$out"
    fail "$profile: invariants did not pass"
    continue
  fi

  extra=$(printf '%s\n' "$out" | grep -v "^ok   $profile" | grep -v '^[[:space:]]*$')
  if [ -n "$extra" ]; then
    printf '%s\n' "$extra"
    fail "$profile: batch startup was not silent"
  else
    printf 'ok   %s (batch)\n' "$profile"
  fi
done

# ---- GUI, on a private display so nothing appears on the real screen ------
if command -v Xvfb >/dev/null 2>&1; then
  for profile in $profiles; do
    sample=$(mktemp)
    out=$(MY_PROBE_OUT="$sample" timeout 90 \
            "$root/bin/gui-test.sh" "$profile" "$root/test/probe.el" 2>&1)
    rc=$?

    if [ "$rc" -ne 0 ]; then
      printf '%s\n' "$out"
      rm -f "$sample"
      fail "$profile: GUI run exited $rc"
      continue
    fi

    if [ -n "$(printf '%s' "$out" | tr -d '[:space:]')" ]; then
      printf '%s\n' "$out"
      rm -f "$sample"
      fail "$profile: GUI run was not silent"
      continue
    fi

    # `message' output in a GUI session goes to the echo area, never to stderr,
    # so stderr silence alone proved nothing: an injected (message "noise")
    # passed this check. The messages log is the only witness.
    # Emacs's courtesy hint is the single permitted line, because Emacs can only
    # be told to skip it by literal text in the user's init file (see
    # base/early-init.org); everything else in that log is a fault.
    left=$(grep -v '^For information about GNU Emacs and the GNU system, type C-h C-a\.$' \
             "$sample.messages" 2>/dev/null | grep -v '^[[:space:]]*$')
    if [ -n "$left" ]; then
      printf '%s\n' "$left"
      rm -f "$sample" "$sample.messages"
      fail "$profile: GUI session printed messages"
      continue
    fi

    bad=""
    grep -qx "profile=$profile" "$sample" || bad="$bad profile-name"
    grep -qx "graphic=t" "$sample"        || bad="$bad no-real-frame"
    grep -qx "gc=16777216" "$sample"      || bad="$bad gc-not-restored"
    grep -qx "handlers=5" "$sample"       || bad="$bad handlers-not-restored"
    grep -qx "delsel=t" "$sample"         || bad="$bad delete-selection"
    grep -qx "so-long=t" "$sample"        || bad="$bad so-long"
    grep -qx "which-key=t" "$sample"      || bad="$bad which-key"

    if [ -n "$bad" ]; then
      printf '%s\n' "$(cat "$sample")"
      fail "$profile: GUI sample wrong:$bad"
    else
      printf 'ok   %s (gui)\n' "$profile"
    fi
    rm -f "$sample" "$sample.messages"
  done
else
  printf 'skip gui: Xvfb not available (macOS/Windows: test by hand)\n'
fi

[ "$status" -eq 0 ] && printf 'clean: 3 profiles, batch and gui, no unexpected output\n'
exit $status
