# olivetti — vendored

| | |
|---|---|
| package | `olivetti` |
| version | 20260524.213 (MELPA); upstream master 2.0.7 differs only in the header |
| upstream | https://github.com/rnkn/olivetti (the MELPA recipe names this repo) |
| license | GPL-3.0-or-later (see the header of `olivetti.el`) |
| files | `olivetti.el` (as published by MELPA), `olivetti-autoloads.el` (generated) |

`git clone` + run must work offline, on Linux, macOS and Windows. This machine
happens to have olivetti installed system-wide through Nix, but `base/packages.org`
empties `package-directory-list` on purpose, so that copy is invisible to the
profiles — and it does not exist at all on the other two platforms. Committing
one 19 KB file is cheaper than making the reading room depend on where Emacs was
installed.

## No local patch

The MELPA snapshot and upstream master 2.0.7 are byte-identical apart from the
`Package-Version`/`Package-Revision` header, so unlike `ox-typst` there is nothing
to carry forward and nothing for a fixture to protect. If a re-vendor ever needs
a fix, it gets an `upstream.patch` beside this file, the same way the exporter's
does.

## The autoloads file

`olivetti.el` autoloads exactly one command, `olivetti-mode`.
`loaddefs-generate` produced `olivetti-autoloads.el`; one line was added to it,
the `load-path` line that `package.el` normally inserts, because `my/autoload`
loads this file from `vendor/` and the `autoload` form has to be able to find
`olivetti.el` next to it:

```elisp
(add-to-list 'load-path (or (and load-file-name
                                 (directory-file-name
                                  (file-name-directory load-file-name)))
                            (car load-path)))
```

Regenerating the file must put that line back.

## Price

Measured on this machine, in the hebrew profile, on the 407 KB sefer:

| step | cost |
|---|---|
| the `my/autoload` card, at startup | 1 ms |
| `(require 'olivetti)` on the first `C-c w` | 12.6 ms |
| `(olivetti-mode 1)`: the margins themselves | 0.1 ms |
| the first redisplay after that | 94.5 ms |
| a later toggle | ~8 ms |

Nothing is paid at startup: the code loads when the command is first invoked.
The 94.5 ms is the screen being laid out again at the new width — it belongs to
the re-layout, not to the package, and it shows up as one late redraw rather
than as lag while typing.

Redisplay on the sefer is unchanged by being centred: 3.4–4.4 / 5.4–7.2 /
3.2–3.7 ms per line scroll / half page / keystroke, against 3.8–4.4 / 5.0–5.7 /
2.4–3.1 ms uncentred (min of three runs, four runs over two sessions).
A split recalculates per window by itself (60-column body: 13 columns of margin
in each half of a split frame, 59 in a full one, restored when the split is
undone).

## Updating

```
emacs -Q --batch --eval '(progn (require (quote package))
  (setq package-user-dir "/tmp/fetch")
  (package-refresh-contents)
  (package-install (quote olivetti)))'
cp /tmp/fetch/olivetti-*/olivetti.el vendor/olivetti/
```

then regenerate the autoloads file as described above. Re-measure the first-load
price if the version changes materially.
