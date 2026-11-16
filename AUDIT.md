# Audit — emacs-configs

2026-11-16. Emacs 31.1 (pgtk), Linux/Wayland, NixOS. No configuration file was
modified for this audit; this document is the only addition.

What I did: read every file in `lisp/`, the three profiles, `bin/`, `test/` and
`vendor/ox-typst`; ran `bin/check`; byte-compiled every module with the real
`load-path`; measured startup, daemon readiness and keystroke cost; and ran
targeted probes for the terminal, export, search and sorting behaviour. Claims
below marked ✅ were reproduced; ⚠️ means by reading the code; ❓ is a decision
for you.

`bin/check` passes today in all three profiles, so everything here is on top of
a green baseline.

---

## 0. Verdict

The skeleton is good: one job per file, profiles are thin lists, packages are
owned by the repo, `package-quickstart` is on, the export works on a staged
copy, and the vendored `ox-typst` patch is documented and tested. The Hebrew
performance findings in `DECISIONS.md` are real and the RTL overlay is cheap
(measured below).

The problems are concentrated in four places:

1. **A hard bug in the terminal**: the first `C-`` / `C-c t t` in a daemon
   errors out and no shell starts.
2. **Silent wrong output**: exporting a narrowed Org buffer exports only the
   narrowed text.
3. **The harness can report success when a test fails**, and the notes profile
   is not actually exercised by the export tests.
4. **Drift between documents and code**: `DECISIONS.md`, `plan.md`, `README.md`
   and `packages.el` describe a configuration that is partly not this one.

Then the smaller items: the `notes` profile is a copy of `hebrew`, several
"lazy" things load at startup, and the buffer/file search list is sorted by
recency, not folder-first alphabetical (your explicit preference — see §5).

---

## 1. Confirmed bugs (fix these first)

### 1.1 The terminal cannot start the first time — hard error ✅

`lisp/terminal.el:18` binds `explicit-shell-file-name` before `shell.el` has
been loaded:

```elisp
(let ((explicit-shell-file-name (cdr choice)) (shell-file-name (cdr choice)))
  (shell (generate-new-buffer-name ...)))
```

`explicit-shell-file-name` is `defvar`ed by `shell.el`, which is not loaded at
that point.  The `let` therefore creates a *lexical* binding, and when `shell`
autoloads `shell.el`, that file's `defvar` signals:

```
*ERROR*: Defining as dynamic an already lexical var: explicit-shell-file-name
```

Reproduced by loading the `ide` profile and calling `my/new-terminal`: no
shell buffer, no process. `my/toggle-terminal` calls the same function, so
`C-`` and `C-c t t` fail on first use in every session.

The byte-compiler already warned about this: `Unused lexical variable
'explicit-shell-file-name'` — the binding really is lexical.

Fix (do not need to be clever): `(require 'shell)` at the top of
`terminal.el` (or bind only `shell-file-name`, which is a C variable and always
special, or add `(defvar explicit-shell-file-name)`). With `(require 'shell)`
first, the same test starts `nu -i` correctly via `shell-file-name`.

### 1.2 Exporting a narrowed buffer silently drops the rest of the file ✅

`lisp/export.el:82` stages the buffer with

```elisp
(buffer-substring-no-properties (point-min) (point-max))
```

and `buffer-substring-no-properties` respects narrowing.  The empty-footnote
check wraps itself in `org-with-wide-buffer`, but the staging copy does not.

Reproduced: a two-heading file, `org-narrow-to-subtree` on the second heading,
then `my/org-typst-export-pdf`.  The PDF contained `1. Second` only; `First`
was gone, with no warning.  This is a data-loss-shaped bug (the source is safe,
but the PDF silently is not the document).

Fix: `(org-with-wide-buffer (buffer-substring-no-properties (point-min)
(point-max)))` for the staging copy (and decide whether `subtreep` should keep
the narrowing, which is a different case).

### 1.3 Async export is broken ✅

`my/org-typst-export-pdf` passes `async` to `org-typst-export-as-typst`, then
immediately reads `org-typst-export-buffer-name` and compiles synchronously.
With `async` non-nil the export has not produced that buffer yet.

Reproduced: `(org-typst-export-to-pdf t)` signals
`(wrong-type-argument stringp nil)` and leaves no PDF.  Default `C-c C-e` does
not pass async, so this is not hit daily, but `org-export-in-background` or any
caller that requests async will fail.  Either implement the async path (compile
in the export process's sentinel) or reject `async` with a `user-error`.

### 1.4 `bin/check` can exit 0 when a test fails ✅

`bin/check:7` and `:11` pipe Emacs into `grep`:

```sh
emacs ... | grep -E "^(ok|FAIL|Error)"
```

The pipeline's status is `grep`'s, not Emacs's.  `set -e` therefore does not
help.  A synthetic test that prints `FAIL ...` and calls `(kill-emacs 1)` makes
the pipeline exit 0; the failure is printed but the script still succeeds.
Anything automated (CI, a pre-commit hook) will treat that as a pass.

Also:

- `bin/check:9` runs `export-in-profile` and `export-footnote-placement` only
  against **hebrew**.  The footnote-placement test explicitly documents and
  supports `notes` too (`test/export-footnote-placement.el` header), but the
  notes branch never runs.
- The tests load modules with `-l`, so `emacs-startup-hook` never runs.
  `test/invariants.el` calls `my/restore-after-init` by hand, but nothing
  verifies that `savehist`, `recentf`, `save-place`, `winner`, `which-key`,
  etc. are actually enabled.

Fix: use `bash` + `set -o pipefail` (or capture `${PIPESTATUS[0]}`), run both
profiles for both export tests, and add a small check that the startup hook's
modes are on after `(run-hooks 'emacs-startup-hook)`.

### 1.5 Hebrew search: vav/yod is one-way, and spaces are literal ✅

`lisp/search-hebrew.el:27-31` builds the orderless regexp as

```
letter [niqqud]* [?] for vav/yod, [niqqud]*
```

which makes a vav/yod **optional**, not interchangeable.  Measured:

| pattern | candidate | matches? |
|---|---|---|
| `דויד` | `דוד` | yes |
| `דוד` | `דויד` | **no** |
| `שלום` | `שלים` | no |

The common case is the failing direction: you type unpointed `דוד`, the sefer
has `דויד`, and it does not match.  If you want both directions, allow an
optional `[יו]` between letters (or normalise both pattern and candidate), not
just make vav/yod optional.

Separately, `my/isearch-niqqud-fun` turns the whole search string into one
regexp, so a space is `regexp-quote " "` — a literal space.  Normal isearch
treats a space as `isearch-lax-whitespace` (any run of whitespace), so a Hebrew
two-word search no longer matches across a line break.  Verified:
`(my/hebrew-niqqud-regexp "שלום עולם")` does not match `"שלום\nעולם"`.

Also, the advice checks only `isearch-regexp`; it ignores
`isearch-regexp-function` (word/symbol search), so `M-s w` with a Hebrew
pattern takes the plain-regexp path and loses word semantics.  Minor, but it is
the same wrapper.

### 1.6 `tinymist` is configured but never started ✅/⚠️

`lisp/ide.el:14` adds `(typst-ts-mode . ("tinymist"))` to
`eglot-server-programs`, but the `eglot` hook (`ide.el:8`) only covers
`python-mode`, `rust-mode` and `nix-mode`.  Nothing calls `eglot-ensure` in a
`typst-ts-mode` buffer (`lisp/typst.el:4-6` only adds `electric-pair`).

So the README's "`tinymist` for eglot" is dead configuration: the server is
never launched.  Either add `(typst-ts-mode . eglot-ensure)` (or a proper
`typst-ts-mode-hook`) or drop the entry and the README claim.  The same
question applies to `typst-ts-mode`'s tree-sitter grammar, which is not
mentioned anywhere.

### 1.7 Two keybindings can destroy work without asking ✅

- `lisp/navigation.el:21` — `my/revert-buffer` is `(revert-buffer t t)`.
  The second argument is `noconfirm`, so `C-c R` **discards unsaved changes
  without a prompt**.  `C-c R` is easy to hit by accident.  Use the
  confirming form (`(revert-buffer nil t)`) or `revert-buffer-quick`.
- `my/kill-other-buffers` (`C-c k`) kills every file-visiting buffer in every
  tab and frame, prompting one by one for modified ones.  With `activities`
  enabled, it also destroys the buffers that belong to *other* activities, so
  resuming them no longer restores the work.  It should be scoped (current
  project, current tab, or "same major mode") or at least confirm once with a
  count.

---

## 2. Design and drift (things that will mislead you later)

### 2.1 `notes` is a copy of `hebrew` ✅

`configs/notes/init.el` and `configs/hebrew/init.el` have identical module
lists:

```
core files ui completion editing navigation hydras
prose writing footnotes rtl search-hebrew export reading ai
```

`notes` therefore gets the Hebrew font (`ui.el` applies it to `hebrew` and
`notes`), the global C-f/C-b remap, niqqud search, RTL footnote labels, Org
export and olivetti.  The only thing that differs is
`org-export-default-language` (`"en"` for notes).  If the intent is "notes =
markdown + English", this profile is not it; if the intent is "same tools,
English export", say so somewhere.  Either way the export tests never exercise
notes (§1.4), so the difference is untested.

### 2.2 Run-time state is per profile, and that includes history ✅

`early.el` puts everything under `state/<profile>/`.  That means each profile
has its own `recentf`, `savehist` (minibuffer history), bookmarks, save-place,
project list, transient history, eshell history and TRAMP persistency.

Consequences you feel every day:

- `C-x b` in `hebrew` will not list files you opened in `ide` (consult-buffer's
  file source is recentf).
- Minibuffer history restarts per profile.
- Bookmarks are per profile.

If that separation is intentional, fine — but it is not documented, and it is
surprising that "recent files" is not shared.  Consider a `state/shared/` for
history/recentf/bookmarks/places and per-profile state only for things that
really differ (activities/window state, auto-save).

### 2.3 `custom.el` is loaded, then overwritten by modules ⚠️

`core.el` loads `custom-file` before the modules.  Every module then uses
`setq` for its settings.  So Customize appears to work, but for any variable a
module owns, the module wins at the next start.  That directly conflicts with
your own rule "one owner per setting" (`plan.md` §0.10).  Either stop loading
`custom-file` for configuration-owned variables, or treat Custom as the owner
and remove the `setq`s.  Right now it is a second owner that loses silently.

### 2.4 `tab-bar-show 0` means "always show" ✅

`navigation.el:3` sets `tab-bar-show 0`.  Emacs's own doc for the variable:

> If 0, always keep the tab bar shown.

`tab-bar-mode` is off at startup (verified), so there is no bar until a tab
command or `activities-tabs-mode` enables it — then it is always visible.  If
you wanted "never show", the value is `nil`.  Given `hydra-tabs` and
`activities`, `0` may be deliberate; just confirm it.

### 2.5 `DECISIONS.md` numbers no longer match this tree ✅

`DECISIONS.md` says daemon startup is hebrew 0.15 s, notes 0.18 s, ide 0.19 s.
Measured on this machine (Emacs 31.1, warm cache):

| measurement | hebrew | notes | ide |
|---|---|---|---|
| `(emacs-init-time)` in daemon | 0.27 s | — | — |
| tty startup, `after-init - before-init` | 0.69–0.70 s | 0.69–0.95 s | 0.74–0.80 s |
| daemon socket appears (first client can connect) | 0.62–0.95 s | — | — |
| `emacs -Q --daemon` baseline socket | 0.18–0.21 s | | |
| features at end of init | 226 | 226 | 244 |

Two separate issues:

1. The 0.15–0.19 s figure is not what this tree does now.  It may have been
   measured before the last modules landed, or on a different machine.
2. `emacs-init-time` measures init, not the time until the first client can
   connect.  There is roughly 0.4–0.7 s of daemon/startup work after init on a
   warm run.  The number in `DECISIONS.md` is the one you *don't* feel; the
   socket number is the one you feel.

Also, `DECISIONS.md` says "Everything lazy by default" — see §3, where hydra,
orderless and wgrep are loaded before you use them.

### 2.6 `plan.md` §5 and the code disagree completely ⚠️

`plan.md`'s triage table says **drop** `projectile`, `consult-projectile`,
`dirvish`, `activities`, `hydra`, `helpful`, `crux`, `move-text`,
`expand-region`, `beginend`, `goto-last-change`, `visual-regexp`, `yasnippet`,
`rainbow-delimiters`, `org-modern`, `valign` — and use `project.el`, `dired`,
`transient`/`repeat-mode`, `tempel`, `completion-preview` instead.

All of those packages are in `lisp/packages.el` and in the modules today:
`vcs.el` (projectile, consult-projectile, git-timemachine), `navigation.el`
(dirvish, activities), `hydras.el` (hydra), `completion.el` (helpful),
`editing.el` (crux, move-text, expand-region, beginend, visual-regexp,
yasnippet), `ide.el` (rainbow-delimiters), `prose.el` (org-modern, valign).

That is not necessarily wrong — you may have changed your mind — but the repo
now has two sources of truth (your rule 10).  Either update `plan.md` §5 or
remove the packages; leaving it as-is means the next reader (human or agent)
will "fix" the config toward the document.

### 2.7 `packages.el` says it tags profiles, but has no tags ⚠️

The header: "Tag after a name = the profiles that use it; no tag = all."  There
are no tags.  Harmless, but it suggests a mechanism that does not exist.

`consult-projectile` is installed and pinned in `packages.lock`, but nothing
requires it, binds it or calls it.  It is dead weight (and pulls projectile at
load if it ever is required).

### 2.8 `bin/install` is not reproducible, and can succeed while broken ⚠️

- `packages.lock` is written but never read.  `bin/install.el` does
  `package-install` for whatever is missing, i.e. the latest MELPA.  A fresh
  clone today does not get the versions in the lock.  If the lock is meant to
  be a reproducibility record, use `package-pinned-packages` (or a snapshot /
  `:vc` pins) and have `bin/install` honour it; otherwise say in the README
  that it is a record, not a pin.
- `package-refresh-contents` runs on every invocation (network every time).
- Failed installs are caught and `message`d, but the script continues and exits
  0. A half-installed `elpa/` then fails at startup.  Exit non-zero if any
  `package-install` failed.
- There is no byte-compilation step (see §3.3).

### 2.9 README native dependencies are incomplete ⚠️

`README.md` lists poppler/autotools/C++ (pdf-tools), typst, `nil`, `tinymist`,
`rg`, `fd`, `direnv`.  The code also assumes:

- **Noto Serif Hebrew** (`ui.el:6`) — silently falls back if missing.
- **Ollama** at `localhost:11434` with `llama3` (`ai.el`).
- A **tree-sitter grammar for Typst** (`typst-ts-mode`), and `rust-analyzer`
  / a Python LSP for the `eglot` hooks.
- **`pdftotext`** (poppler) for `test/export-footnote-placement.el`; the test
  skips without it.
- **`cargo`/`rustfmt`** for `rust-format-on-save` and the `cargo` package.
- **`wl-paste`/`xclip`/`grim`** (Wayland screenshot/paste) for `org-download`.
- **`pwsh`/`nu`** are optional, but `my/terminal--shells` prefers them over
  bash, so the shell you get depends on what is installed.
- **macOS GUI**: launching from Finder does not inherit the shell `PATH`;
  nothing here does `exec-path-from-shell` (or equivalent), so `rg`, `fd`,
  `typst`, `git` and language servers will be missing in a GUI launch.  The
  README says the config works on macOS.

`vendor/ox-typst/SOURCE.md` also refers to `bin/install.sh`,
`bin/check.sh` and `bin/check-export.sh`; the repo has `bin/install` and
`bin/check`.  Documentation drift.

### 2.10 `org-modern`/`valign` vs the manifesto ⚠️

They are enabled for org buffers under 200 KB (`prose.el`).  That is a
reasonable compromise, and it is documented.  But `plan.md` says drop them
("cosmetics on the redisplay path"), and they do run on every redisplay in
medium-sized files.  Decide and record it; the current state is a third
position.

`my/org-pretty` calls `valign-mode` unconditionally, so a tty Emacs prints
`Valign mode has no effect in non-graphical display` for every such buffer.
Gate on `(display-graphic-p)` if tty use matters.

### 2.11 `yasnippet` on `text-mode` means Org buffers get snippets ⚠️

`editing.el:41` hooks `yas-minor-mode` into both `prog-mode` and `text-mode`.
`org-mode` derives from `text-mode`, so YASnippet is active in every sefer, with
the `yasnippet-snippets` collection.  That interacts with Org's own TAB
(`org-cycle`) and with your "never touch the user's text" rule.  If you want
snippets only in code, drop `text-mode` from the hook.

### 2.12 Duplicate profile entry points ⚠️

The three `configs/*/early-init.el` files are byte-identical, and `hebrew` /
`notes` `init.el` lists are identical.  Not a bug, but any change to the
early-init logic has to be made three times.  A tiny shared
`lisp/profile-entry.el` loaded from each file would remove the duplication
(and the risk of one profile drifting).

---

## 3. Performance (measured)

### 3.1 What is good

- **RTL footnote overlay is not a problem.**  On a 336 KB Hebrew Org file in a
  GUI frame with 9 visible footnote definitions: bare edit + redisplay
  5.73 ms/keystroke; with `my/rtl-footnote-labels-follow` 6.21 ms/keystroke.
  In batch (no redisplay) the overlay costs ~0.05 ms/edit.  That is under your
  8 ms budget; the buffer-local hook change did its job.
- **Long-line/keyboard settings** are sane: `scroll-conservatively 101`,
  `read-process-output-max` 1 MB, GC restored after init.  The only global
  `post-command-hook` entry is Emacs's own `eldoc-schedule-timer`; the RTL hook
  is buffer-local.
- **`org` is not loaded at init** (feature check), and `consult`, `magit`,
  `projectile`, `dirvish`, `activities`, `pdf-tools`, `org-modern`, `valign`
  are deferred correctly.

### 3.2 What is not

| item | measurement / fact |
|---|---|
| features at end of init | 226 (hebrew/notes), 244 (ide); `plan.md` §7 target was < 150 |
| `hydra` at init | loaded just by loading `lisp/hydras.el`; the comment "hydra is lazy" (`hydras.el:29`) is false |
| `orderless` at init | loaded by `use-package orderless :custom ...` (no deferral keyword) |
| `wgrep` at init | loaded by `use-package wgrep :custom ...` (no deferral keyword); it is only useful after a grep |
| `beginend` | loaded during `emacs-startup-hook`; adds to the first-client wait |
| startup-hook block (savehist, recentf, winner, which-key, editorconfig, …) | ~0.09 s in batch |
| modules | 20 files loaded as source; no `.elc` |
| `my/load-modules` | `load "lisp/%s.el"` — see 3.3 |

Rule to apply: in `use-package`, a package is loaded at init unless it has one
of `:defer`, `:commands`, `:bind`, `:hook`, `:mode`, `:magic`, `:after` (or is
`:demand`ed).  `:custom` does **not** defer.  `wgrep` and `orderless` are the
two places this bites; `vertico` and `marginalia` are loaded on purpose
(`:init (mode 1)`).

Hydra: `use-package hydra :commands defhydra :config (defhydra ...)` still
loads hydra at startup (verified with `(featurep 'hydra)` after loading
`hydras.el`).  The `defhydra` forms need the macro at expansion time.  If you
care, define them inside `(with-eval-after-load 'hydra ...)` and load hydra
from the two key commands; otherwise accept the cost and fix the comment.

### 3.3 Byte-compiling would not even be used today ✅

`my/load-modules` calls `(load ".../core.el")`.  Verified in a clean Emacs:

- `(load "/tmp/x.el")` with a newer `x.elc` present loads **`x.el`** (source).
- `(load "/tmp/x")` loads **`x.elc`**.

So if you add a build step that produces `lisp/*.elc`, the current loader will
ignore every one of them.  Either drop the `.el` from the `format` string (and
let `load` choose `.elc`, with `load-prefer-newer`), or don't bother compiling.

Byte-compiling the modules also surfaces the terminal bug (§1.1) and a pile of
free-variable warnings that are currently invisible.  Add a compile step to
`bin/check` with `byte-compile-error-on-warn` for `lisp/*.el` (after loading
the profile, so the package macros are available).

### 3.4 Things to measure before changing

- `org-src-fontify-natively`, `org-pretty-entities`, `org-modern`/`valign` on
  a 150–200 KB Org file with many tables/src blocks: batch numbers do not
  include redisplay.
- `beginend` and `yasnippet` in Org: they add hooks to modes you use daily.
- `global-auto-revert-mode` with `auto-revert-verbose` default `t`: it messages
  on every external change; set `auto-revert-verbose nil` if that is noise.

---

## 4. Missing features I would expect (built-in first)

These are offerings, not demands.  Each is small unless noted.

### Minibuffer, files, buffers

- **Sorting**: your preference — see §5; currently not implemented at all.
- `recentf-exclude` is nil by default here (verified).  Add `elpa/`, `state/`,
  `temporary-file-directory`, and the export temp names (`.export-`,
  `.typst-`) or recentf will collect them; the export's staged buffer is opened
  with `find-file-noselect`, so it can land in recentf.
- `savehist` only persists the minibuffer histories; `savehist-additional-variables`
  is nil and `history-length` is 100.  Consider adding `kill-ring` and raising
  the length.
- `ibuffer` exists, but `ibuffer-sorting-mode` is left at its default; if you
  want the same folder-first/alphabetical rule there, set it explicitly.
- `C-x C-f` is still the built-in `find-file`; there is no `consult-find`/
  `project-find-file` binding.  `M-s f` (fd) and `M-s r` (ripgrep) exist, but
  the file-open path is the standard one.
- `dired-x` is not enabled: `C-x C-j` (`dired-jump`), `wdired`, and
  `dired-omit-mode` are all built in and one line each.  `dirvish` is the only
  file browser; `dired` itself is unconfigured beyond `dired-listing-switches`
  (which dirvish may not use).

### Projects and code

- **Pick one project system.**  `C-c p` is projectile (`vcs.el`), while
  `my/project-in-new-tab` calls `project-switch-project` (project.el).
  `consult-projectile` is installed but unused.  The `plan.md` decision was
  project.el; the code is projectile.  Whichever wins, bind the same keys
  (`C-x p` / `C-c p`) to it and delete the other.
- `typst-ts-mode` + `tinymist` is not wired (§1.6); the tree-sitter grammar is
  not documented or located.
- No tree-sitter setup at all: no `major-mode-remap-alist`, no
  `treesit-extra-load-path`, so Emacs 31's built-in `*-ts-mode`s are not used
  for any language.
- No `flymake` for non-eglot buffers (eglot turns it on where it is active;
  there is no linting for plain scripts).
- No `compile`/`recompile`/`project-compile` binding in the `ide` profile.
  `my/typst-compile` is the only build command.
- No `display-line-numbers-mode` in `prog-mode` (usually the first thing an
  IDE profile turns on).
- `corfu` is `prog-mode` only, with no `cape`; prose buffers get no in-buffer
  completion.  `completion-preview-mode` is built in (30+) and cheap; it is
  not enabled anywhere.
- `eglot` has no keymap configuration beyond the package defaults; that is
  fine, but `flymake` diagnostics need a keybinding or `M-n`/`M-p` on
  diagnostics.

### Prose and reading

- No `auto-fill-mode`/`fill-column` for prose; `visual-line-mode` wraps the
  display but the source lines are unbounded.  Decide which you want for Org.
- Spelling is deliberately absent (`DECISIONS.md`); leave it.
- `pdf-tools` has no `pdf-view-use-scaling`, no annotation setup and no
  `pdf-view-restore`/place saving; on a HiDPI display the default may be
  blurry or slow.
- `nov` is loaded but has no `nov-text-width`/`nov-variable-pitch` settings.
- `doc-view`/`djvu` are not configured for non-PDF reading.

### Environment and platform

- No `exec-path-from-shell` (or equivalent) for a GUI Emacs on macOS; the
  README claims macOS support but a Finder launch will not find `rg`/`fd`/
  `typst`/language servers.
- `envrc` is `ide` only; the `hebrew`/`notes` profiles run `typst` from
  `export.el` with the global `PATH`.  If typst lives in a dev shell, export
  from those profiles will fail.
- `bin/check` has no Windows equivalent (`bin/check.cmd`), though the README
  says the Windows launchers exist.  `bin/launch.cmd` also does not validate
  the profile name the way `launch.sh` does.
- `delete-by-moving-to-trash` needs a working `move-file-to-trash` backend
  (`gio`/`trash`); not checked or documented.

---

## 5. Your buffer/file list: folder-first, then alphabetical

**Current behaviour: not implemented anywhere.**  Verified:

- `vertico-sort-function` is the Vertico default,
  `vertico-sort-history-length-alpha`.  That sorts by minibuffer history first,
  then by candidate length, then alphabetically — i.e. "recent/short first",
  not alphabetical.
- `consult-buffer` uses Consult's default `:sort t`, so it is exactly that
  Vertico sort (within each source group: Buffers, Files, Bookmarks, …).
- `consult-fd`, `consult-find` and `consult-ripgrep` pass `:sort nil`, which
  sets `display-sort-function` to `identity`: their results keep the order the
  external tool emits.  `fd` and `find` emit filesystem traversal order;
  `rg` groups by file but does not guarantee alphabetical.
- `C-x C-f` (`find-file`) also goes through Vertico's default sorter, so its
  candidates are not alphabetical either.

So the list you see today is recency/length-driven, with no folder grouping.

A minimal, stat-free sorter that does what you asked for (directories ending in
`/` first, then case-insensitive alphabetical, which groups paths by folder):

```elisp
(defun my/vertico-sort-folders-first (cands)
  "Sort CANDS alphabetically, directories before files.
A candidate ending in \"/\" is a directory; this is how `read-file-name'
presents them, so no `file-directory-p' stat is done per candidate."
  (sort (copy-sequence cands)
        (lambda (a b)
          (let* ((a (substring-no-properties a))
                 (b (substring-no-properties b))
                 (da (string-suffix-p "/" a))
                 (db (string-suffix-p "/" b)))
            (cond ((and da (not db)) t)
                  ((and db (not da)) nil)
                  (t (string-lessp (downcase a) (downcase b))))))))

(setq vertico-sort-function #'my/vertico-sort-folders-first)
```

Caveats:

- This changes sorting for *all* completions: `M-x` becomes alphabetical
  instead of history-first.  That is probably what you want, but it is a
  deliberate loss of recency ranking.
- `consult-fd`/`consult-find`/`consult-ripgrep` explicitly opt out of sorting
  (`:sort nil`), so the variable above does not affect them.  For ripgrep, add
  `--sort path` to `consult-ripgrep-args` (rg supports it; it disables
  parallelism, so it is slower).  `fd` has no sort flag; if you want sorted fd
  results you need a small wrapper around `consult--read` or a post-filter.
  Vertico has `vertico-sort-override-function` (verified present), which can be
  bound around a command to override its table's `:sort nil`.
- Directory detection by trailing `/` works for `C-x C-f` and for buffers, but
  not for `fd` output, which prints directories without a trailing slash.  For
  fd, the sorter will at least group by path alphabetically; true
  directories-first there needs a stat or a wrapper.
- If you also want this in `ibuffer`, set `ibuffer-sorting-mode` to
  `'alphabetic` (and `ibuffer-sorting-reversep` to nil).

The proposed function was tested on a mixed list and produced
`("dir/" "docs/" "src/" "a.el" "README" ...)` — directories first, then files,
case-insensitive.

---

## 6. Code quality and structure

- **`my/load-modules`**: uses `load` with a hard-coded `.el` suffix (so
  `.elc` is ignored), has no `provide`, and reloading a module duplicates its
  hooks (e.g. `rtl`'s `post-command-hook`, `core`'s `emacs-startup-hook`).  For
  a config this small, `require` + a `provide` at the end of each module would
  be safer.
- **No module-completeness check.**  `plan.md` mentioned an invariant that every
  file in `lisp/` is listed by some profile.  It is gone.  A new file can sit
  unused forever (or a typo in a module name silently changes a profile) with
  nothing failing.
- **Anonymous lambdas in global keys and hooks**: `C-c W`, `C-c T`, `envrc`'s
  `after-init` hook, `ibuffer-mode`'s filter-group hook, `rtl`'s Org hook.
  They work, but `C-h k` shows a lambda and you cannot `remove-hook` them by
  name.  Name the ones you might want to remove.
- **Missing docstrings** on `my/kill-current-buffer`, `my/kill-other-buffers`
  (has one), `my/revert-buffer`, `my/split-below-and-follow`,
  `my/split-right-and-follow`, `my/typst-compile`, `my/typst-watch`,
  `my/typst-view`.  Small, but these are commands.
- **`my/org-drop-footnote-highlighting`** identifies the keyword with
  `(string-match-p "org-activate-footnote-links" (format "%S" kw))`.  It works
  today and the test suite does not cover it; if Org ever changes the keyword
  representation, it silently stops removing the expensive keyword.  Assert
  that something was removed, or filter on the actual symbol.
- **`org-export-headline-levels` and `org-export-default-language` are set
  before `ox.el` is loaded** (`export.el`).  This works because `setq` creates
  the variable, but it is fragile; a `with-eval-after-load 'ox` (or `:custom`
  after loading ox) would be honest about the dependency.
- **`my/rtl`** still uses the older `global-set-key` form for its remaps;
  `keymap-global-set` is the form the rest of the config uses.
- **`my/org-pretty`** uses `(buffer-size)` (characters) against
  `my/pretty-max-size` (200 KiB); that is the intended metric, but note it is
  not the file size on disk.  Fine; just be aware for UTF-8 files.
- **`test/invariants.el`** checks a good set of settings, but not the ones most
  likely to regress: the Org footnote keyword filter, the terminal, the
  search-hebrew regexp, the sort function, or the export's narrow/copy
  behaviour.
- **`test/export-in-profile.el`** and `export-footnote-placement.el` are
  genuinely good tests: they assert shape (one PDF, no strays, geometry at the
  page bottom) rather than the existence of a function.  Keep them; add the
  missing cases (narrowed buffer, async, notes profile, terminal, sort).

---

## 7. Answers to your two side questions

### 7.1 Should you use `cooked` for the terminal?

`cooked` (github.com/vodik/cooked) is a comint-derived terminal emulator with a
Rust native core.  The Rust side owns the pty and does terminal-state parsing,
pacing the Emacs side at a fixed frame rate; the Emacs side stays a comint
buffer, so your `C-c` bindings and kill ring work.  That is the "fast" claim.
It is **not** running Emacs Lisp on another thread — Emacs Lisp threads are
cooperative and share the main loop; the win is a separate native process doing
the VT work, not a preemptive Emacs.

The "smart" claim is real and specific: it reads the kernel line discipline
(canonical/echo) and OSC 133 prompt marks, so it knows when Emacs should own the
line (shell prompt), when to ask for a password in the minibuffer (getpass), and
when a full-screen program owns the keyboard.  That also gives it per-command
records and `next-error` scoping, which `vterm`/`eat` cannot do structurally.

Costs and constraints, from its README:

- Emacs 29.1+ **with dynamic module support**, Rust 1.85+ (edition 2024),
  Linux and macOS only — no Windows.
- The native module builds with `cargo` on first use (about a minute) and
  rebuilds when the Rust sources are newer.  That is a native dependency and a
  toolchain requirement, not a pure package.
- It is new (created August 2026, a handful of commits) and self-described as
  "almost 100% vibe coded"; not in MELPA, so it does not fit your
  `packages.el` + `bin/install` flow without `:vc`/straight.
- That conflicts with two of your own decisions: the repo is meant to be pure
  package.el, and you dropped `jinx` specifically because it was a native
  dependency.

Your current terminal is `shell` (comint), which is **not a terminal emulator**:
it is line-oriented and cannot run `htop`, `vim`, `tmux`, or `ssh` password
prompts properly.  If your use is `git`, `nix build`, `typst`, `rg` and other
line commands, `shell` is the cheapest and fastest choice and you should keep
it.  If you need a real terminal now:

- **`eat`** (NonGNU ELPA): pure Elisp, no compiler, works on Windows, much
  faster than `term`, not as fast as native.  This is the conservative pick and
  the only one that matches "no native dependencies".
- **`vterm`**: mature, C module, fast, needs a build (cmake + libvterm).
- **`cooked`**: the most interesting design and the best comint integration, but
  the youngest and the most native.  Revisit it when it has stabilized, or if
  the ssh-password/next-error features are worth the toolchain to you.

Whatever you choose, fix `terminal.el:18` first (§1.1); it cannot start a shell
today on first use.

### 7.2 `emacs-init-time` is a function, not a variable

That is the void-variable error.  In Emacs 31:

```
(fboundp 'emacs-init-time) => t
(boundp 'emacs-init-time)   => nil
```

Call `(emacs-init-time)` (it returns a string and also messages it), or
`(emacs-init-time "%f")`.  For a value you can compute with, use:

```elisp
(float-time (time-subtract after-init-time before-init-time))
```

The latter is what a launch script or test should record, plus the time until
the daemon socket answers — the two numbers differ by ~0.4–0.7 s here (§2.5).

---

## 8. Suggested order of work

**P0 — correctness and trust**

1. `terminal.el`: `(require 'shell)` (or stop binding
   `explicit-shell-file-name`).  Verify `C-`` starts a shell on a fresh daemon.
2. `export.el`: widen when staging (or make narrowing explicit in the
   docstring).  Add a test that narrows and checks the whole document.
3. `bin/check`: pipefail + run the notes export test + a startup-hook check.
4. Decide what `notes` is; update its module list or document that it is
   hebrew-with-English-export.
5. Reconcile `DECISIONS.md` numbers, `plan.md` §5 and the package list.  One
   source of truth.

**P1 — the things you feel**

6. Sorting: §5.  This is your explicit preference and it is currently absent.
7. `search-hebrew`: two-way vav/yod and lax spaces; a test with `דוד`/`דויד`.
8. `typst-ts-mode`: wire `eglot-ensure` (and document the grammar) or remove
   the dead `tinymist` entry.
9. `revert-buffer` / `kill-other-buffers` confirmation and scope.
10. `bin/install`: honour `packages.lock` or relabel it as informational; exit
    non-zero on failed installs; document missing native deps.

**P2 — polish and features**

11. Byte-compile + loader fix (§3.3), or explicitly accept interpreted startup.
12. Laziness: `wgrep`, `orderless`, `hydra`, `beginend`; or update the
    "everything lazy" claim.
13. Missing features from §4 that you actually miss: pick at most five.
14. Tests for terminal, sort, search, narrow export; `bin/check` in CI.

---

## Appendix — how the numbers were obtained

- `bin/check` (all profiles) — passes.
- Startup: `emacs --init-directory=configs/<profile> --daemon=...`, poll for
  `/run/user/1000/emacs/<server>`, and write `(emacs-init-time)` to a file;
  repeat with `-Q` for the baseline.  TTY numbers from
  `script -qec "emacs --init-directory=... --eval '...'"`.
- Keystrokes: 336 KB Hebrew Org file, GUI frame, `benchmark-run` around
  `insert`/`delete-char` with and without `my/rtl-footnote-labels-follow`, plus
  `redisplay`.
- Terminal: batch load of the `ide` profile, then `(my/new-terminal)`; error
  text reproduced, and with `(require 'shell)` first the process started as
  `nu -i`.
- Export: temp Org files with a footnote section, narrowing, and
  `pdftotext` on the result; async call with `(org-typst-export-to-pdf t)`.
- Search: direct calls to `my/orderless-hebrew` and
  `my/hebrew-niqqud-regexp` with pointed/unpointed strings.
- Sorting: inspected `vertico-sort-function`,
  `consult--multi`'s `:sort t` and `consult--find`'s `:sort nil`; tested the
  proposed sorter on a mixed list.
- Byte-compilation: `emacs -Q --batch -l configs/<profile>/early-init.el
  --eval '(package-activate-all)' -f batch-byte-compile lisp/*.el`.

Nothing in the repository was changed except this file.
