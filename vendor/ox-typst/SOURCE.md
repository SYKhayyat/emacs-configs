# ox-typst — vendored

| | |
|---|---|
| package | `ox-typst` |
| version | 20260502.1009 |
| upstream | https://melpa.org/packages/ (MELPA), source at https://github.com/treeselect/ox-typst |
| license | GPL-3.0-or-later (see the header of `ox-typst.el`) |
| files | `ox-typst.el`, `ox-typst-autoloads.el` (as published by MELPA) |

`git clone` + run must work offline, on Linux, macOS and Windows. A package
installed into `elpa/` does not survive a clone (that directory is ignored), so
an installed exporter would mean "clone, then remember to install, with network,
before exporting works". At 112 KB and one file, committing it is cheaper than
building and documenting an install path for it.

`bin/install.sh` remains the answer for anything too large or too native to
vendor (stage 4: magit, eglot dependencies, vterm).

## Updating

```
emacs -Q --batch --eval '(progn (require (quote package))
  (setq package-user-dir "/tmp/fetch")
  (package-refresh-contents)
  (package-install (quote ox-typst)))'
cp /tmp/fetch/ox-typst-*/ox-typst{,-autoloads}.el vendor/ox-typst/
```

Then update the version above, run `bin/check.sh`, and re-export one document to
confirm the output. The version string in the first line of
`ox-typst-autoloads.el` must match this table.
