# emacs-configs

Three Emacs profiles (hebrew, notes, ide) as thin module lists over one shared
set of modules in `lisp/`. The config owns its packages (package.el, into
`elpa/`), so it needs no Nix and works the same on any OS.

## Setup

    bin/install        # installs the packages in lisp/packages.el; records versions in packages.lock
    bin/launch.sh hebrew [file ...]    # or notes, ide; starts a per-profile daemon

`bin/install.cmd` and `bin/launch.cmd` are the Windows equivalents.
Run `bin/check` for the invariant and export tests.

## Layout

- `configs/<profile>/early-init.el, init.el` — bind the profile, load `lisp/early.el`, then a module list.
- `lisp/` — one job per file. Base: `early core files ui`. Editing: `completion editing navigation hydras`. Prose: `prose writing footnotes rtl search-hebrew export`. Code: `ide vcs typst terminal`. Extras: `reading ai`. `packages.el` is the package list.
- `vendor/ox-typst` — patched Typst exporter (see its SOURCE.md).
- `state/<profile>/` — runtime files (git-ignored). `elpa/` — packages (git-ignored).

## Native dependencies (not installable by package.el)

- jinx (spelling): the enchant library + a C compiler (NixOS: `enchant`, Debian: `libenchant-2-dev`, macOS: `brew install enchant pkgconf`).
- pdf-tools: poppler, autoconf, automake, a C++ compiler; it builds `epdfinfo` on first PDF.
- typst CLI for export/preview; `nil` and `tinymist` for eglot; `rg`, `fd` for consult; `direnv` optional.

See DECISIONS.md for what was chosen and why, FRICTION.md for annoyances, plan.md for the manifesto.
