# emacs-configs

Three Emacs profiles (hebrew: Hebrew notes in Org; notes: English Org/Markdown;
ide: code), each as a thin module list over one shared
set of modules in `lisp/`. The config owns its packages (package.el, into
`elpa/`), so it needs no Nix and works the same on any OS.

## Setup

    bin/install        # installs the packages in lisp/packages.el; removes dropped ones; writes a local version record, packages.lock
    bin/launch.sh hebrew [file ...]    # or notes, ide; starts a per-profile daemon

`bin/install.cmd` and `bin/launch.cmd` are the Windows equivalents.
Run `bin/check` for the invariant and export tests. Press `F7` in Emacs for a searchable list of every key active in the current buffer (built-in, mode and yours), read from the live keymaps.

## Layout

- `configs/<profile>/early-init.el, init.el` — bind the profile and load `lisp/early.el`; the module list per profile is `lisp/profiles.el`.
- `lisp/` — one job per file. Base: `early core files ui`. Editing: `completion editing navigation`; terminal (eat, every profile): `terminal`. Prose: `prose writing footnotes export`; Hebrew only: `rtl search-hebrew`. Code: `ide vcs`. Extras: `ai`. `packages.el` is the package list.
- `vendor/ox-typst` — patched Typst exporter (see its SOURCE.md).
- `state/<profile>/` — runtime files (git-ignored). `elpa/` — packages (git-ignored).

## Native dependencies (not installable by package.el)

- typst CLI for export/preview; `rg`, `fd` for consult.

See DECISIONS.md for what was chosen and why, FRICTION.md for annoyances.
