#!/bin/sh
# Export org files to PDF and fail if any of them cannot compile.
#
# Why: the export path was accepted on the strength of "it works on one file".
# That is the failure this script exists to make impossible — the same class of
# bug as a checker that greps for "ok" and ignores everything else. Each real
# sefer that broke it (bare brackets, a trailing backslash, the generated
# footnotes heading) is a fixture here.
#
# Usage:
#   bin/check-export.sh                       the fixtures under test/export/fixtures
#   bin/check-export.sh --corpus DIR [N]      sample N files evenly from DIR (default 20)
#
# A file fails if the org -> typst export errors, or if the .typ does not
# compile. Silent on success; everything printed is a failure.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
fail=0

check_one() { # $1 = org file
  src=$1
  tmpd=$(mktemp -d)
  b=$(basename "$src" .org)
  cp "$src" "$tmpd/$b.org"
  if ! out=$(emacs -Q --batch -l "$root/vendor/ox-typst/ox-typst.el" \
               --eval "(progn (require 'ox-typst) (find-file \"$tmpd/$b.org\") (org-typst-export-to-pdf))" 2>&1); then
    printf 'FAIL %s: org export: %s\n' "$b" \
      "$(printf '%s' "$out" | grep -im1 'error' | tr -d '\r' | cut -c1-120)"
    rm -rf "$tmpd"; fail=1; return 0
  fi
  if ! ( cd "$tmpd" && typst compile "$b.typ" --root "$tmpd" >/dev/null 2>&1 ); then
    printf 'FAIL %s: typst: %s\n' "$b" \
      "$( cd "$tmpd" && typst compile "$b.typ" --root "$tmpd" 2>&1 | grep -m1 '^error' | tr -d '\r' | cut -c1-120)"
    rm -rf "$tmpd"; fail=1; return 0
  fi
  rm -rf "$tmpd"
}

case "${1:-}" in
  --corpus)
    dir=${2:?usage: check-export.sh --corpus DIR [N]}
    n=${3:-20}
    total=$(find "$dir" -name "*.org" -size +5k | wc -l)
    [ "$total" -eq 0 ] && { echo "no org files in $dir" >&2; exit 2; }
    step=$(( total / n )); [ "$step" -lt 1 ] && step=1
    list=$(mktemp)
    find "$dir" -name "*.org" -size +5k | sort | awk -v s=$step 'NR%s==0' | head -n "$n" > "$list"
    while IFS= read -r f; do check_one "$f"; done < "$list"
    rm -f "$list"
    if [ "$fail" -ne 0 ]; then echo "export check failed" >&2; exit 1; fi
    echo "corpus export check: ok"
    ;;
  "")
    for f in "$root"/test/export/fixtures/*.org; do check_one "$f"; done
    if [ "$fail" -ne 0 ]; then echo "export check failed" >&2; exit 1; fi
    echo "export fixtures: ok"
    ;;
  *)
    echo "usage: check-export.sh [--corpus DIR [N]]" >&2; exit 2
    ;;
esac
