# ox-typst — vendored

| | |
|---|---|
| package | `ox-typst` |
| version | 20260502.1009 (MELPA); upstream master 0.1.0 is identical apart from the header |
| upstream | https://github.com/jmpunkt/ox-typst (the MELPA recipe names this repo) |
| license | GPL-3.0-or-later (see the header of `ox-typst.el`) |
| files | `ox-typst.el`, `ox-typst-autoloads.el` (as published by MELPA) |

`git clone` + run must work offline, on Linux, macOS and Windows. A package
installed into `elpa/` does not survive a clone (that directory is ignored), so
an installed exporter would mean "clone, then remember to install, with network,
before exporting works". At 112 KB and one file, committing it is cheaper than
building and documenting an install path for it.

`bin/install.sh` remains the answer for anything too large or too native to
vendor (stage 4: magit, eglot dependencies, vterm).

## Local patch

Both the MELPA snapshot and upstream master reject material from this
repository's corpus. The vendored copy carries three small fixes on top, and
the fixtures in `test/export/fixtures/` fail closed if a re-vendor drops one.

1. **Escape `[` and `]`** in `org-typst-plain-text`. The escape list skipped
   them, so a stray bracket was read as typst's content delimiter and produced
   `unclosed delimiter`.
2. **Escape backslash first.** A source line ending in `\\` (common in this
   corpus) otherwise escapes the following character — often the closing `]` of
   a list item — again giving `unclosed delimiter`.
3. **Clamp the heading level with `(max 1 level)`.** When every heading in a
   document starts below level 1, the generated Footnotes heading gets relative
   level 0, which typst rejects with `number must be positive`.

A patch for upstream is kept as `upstream.patch` in this directory and was sent
as https://github.com/jmpunkt/ox-typst/pull/62. If upstream merges it, the next
re-vendor drops the local patch and the fixtures prove it.

## Updating

```
emacs -Q --batch --eval '(progn (require (quote package))
  (setq package-user-dir "/tmp/fetch")
  (package-refresh-contents)
  (package-install (quote ox-typst)))'
cp /tmp/fetch/ox-typst-*/ox-typst{,-autoloads}.el vendor/ox-typst/
```

Then update the version above, re-apply `upstream.patch` (it may no longer
apply cleanly, which is the point of keeping it as a patch), run `bin/check.sh`
and `bin/check-export.sh`. The version string in the first line of
`ox-typst-autoloads.el` must match this table.
