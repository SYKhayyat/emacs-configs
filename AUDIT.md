# Emacs configs — audit, 2026-11-19

This audit covers correctness and performance for the whole setup: the shared base (`lisp/`, `bin/`, `test/`, `lisp/early.el`), the three profiles (hebrew, notes, ide), and the Nix deployment in `~/config`. It replaces the 2026-11-16 audit, which is still in git history.

Every finding has a severity, evidence, and a proposed fix.

- **P0**: wrong or broken right now.
- **P1**: a real cost you feel, or a trap.
- **P2**: hygiene.

The timings come from throwaway Emacs 30.2 daemons running in a 50×140 tty under `script`, with the real elpa and the real profile init. The GUI (pgtk) redisplay costs more. The *relative* numbers carry over, but confirm in the GUI with `M-x profiler-start` → cpu → type for 30 s → `M-x profiler-report`.

## Verdict

The config itself is in good shape:

- the module split is clean;
- startup GC and file-handler handling are right;
- custom.el loads last;
- `bin/install` fails loudly;
- the bidi changes add nothing per keystroke.

The errors you saw (`transient--set-layout`, `set-local` void) are **not in the config**. They are **stale daemons** still running from the old `~/emacs-configs` tree. That tree's elpa has no transient, keeps orphan packages, and loads the stub compat. Restarting fixes them (B1).

The per-keystroke slowness has three measurable sources, listed by size:

1. Redisplay of long bidi lines. This is inherent and mostly not fixable from config.
2. The footnote-label `post-command-hook`, which rebuilds every label on every typed character. It is fixable, and I measured the fix (H1).
3. Periodic 50–80 ms GC pauses. These are fixable (B4).

Separately, opening the minibuffer has a 0.4 s sort hiding in it (B3).

## Order of work

| # | Item | Effort |
|---|------|--------|
| 1 | Restart all three daemons (B1) | 1 min |
| 2 | Keyed vertico sort (B3) | 5 min |
| 3 | Incremental footnote labels, plus the first-open fix (H1, H2) | 15 min |
| 4 | Idle GC (B4) | 5 min |
| 5 | Native-compile in `bin/install`, and prune (N3, B6) | 15 min |
| 6 | Stale-daemon guard in `launch.sh` (B2) | 10 min |
| 7 | Dev-mode root, so checkout edits are live (N1) | 20 min |
| 8 | Everything P2 | as convenient |

---

## Base (shared by all three profiles)

### B1 — P0 — Running daemons are from the old tree: the source of the void-function errors

**Evidence**

- The daemons were started before the Nix move, from `~/emacs-configs`.
- That tree's `elpa/` has no `transient`. Magit and others reach `transient--set-layout`, which doesn't exist there, so C-x C-f and C-x C-s hit it via hooks and advice.
- `set-local` is a compat function. The old daemon loaded the builtin stub `compat.el`, not the real one that `lisp/core.el:18` now locates.
- The new root `~/.local/share/emacs-configs` is correct. Batch runs of every profile there load cleanly.

**Fix**

1. In each daemon run `M-x save-buffers-kill-emacs`.
2. Relaunch with `emacs-hebrew`, `emacs-notes` or `emacs-ide`.
3. Verify with `M-: (featurep 'transient)` → `t`, and `M-: (symbol-file 'set-local)`, which should be under `.../elpa/compat-*`.

### B2 — P1 — Nothing detects a stale daemon

**Evidence**

- `launch.sh` connects to any server named `emacs-<profile>` that is alive, whatever tree it was started from. That is how B1 survived the migration silently.

**Fix**

- Have `early.el` record `(setq my/config-root ROOT)` and the store path of `lisp/`.
- Have `launch.sh` compare it against the current value before connecting:

  ```sh
  live=$(emacsclient -s "emacs-$p" --eval '(bound-and-true-p my/config-stamp)' 2>/dev/null)
  [ "$live" = "\"$STAMP\"" ] || echo "emacs-$p is running an old config; restart it (M-x save-buffers-kill-emacs)" >&2
  ```

  `STAMP` is the store path baked in by the Nix wrapper. Warn rather than kill, because killing loses unsaved buffers.

### B3 — P1 — Vertico sort costs 378 ms every time M-x opens

**Evidence**

- `lisp/completion.el:4` `my/vertico-sort-folders-first` calls `substring-no-properties` and `downcase` inside the comparison function. That is O(n log n) allocations.
- It is also interpreted, because modules are loaded as source.
- Measured on 5,753 M-x candidates:

  | Variant | ms per sort |
  |---|---|
  | current, interpreted | 378 |
  | current, byte-compiled | 233 |
  | decorate-sort (key computed once), interpreted | 92 |
  | Emacs 30 `sort :key`, interpreted | **20** |
  | Emacs 30 `sort :key`, compiled | **17** |

**Fix** (same order: directories first, then case-insensitive). I checked the output order: `("Ab/" "zz/" "a" "b")`.

```elisp
(defun my/vertico-sort-folders-first (cands)
  (sort cands :key (lambda (c) (cons (not (string-suffix-p "/" c)) (downcase c)))))
```

`sort` with `:key` is new in Emacs 30. It compares the conses with `value<` and computes each key once, in C.

### B4 — P1 — GC pauses of 50–80 ms during typing

**Evidence**

- A full GC in the running hebrew daemon (420 features) takes 83 ms. In ide it takes 51 ms.
- Typing in org conses 35–40 KB per character.
- With `gc-cons-threshold` at 16 MB (`lisp/core.el:24`), that is one visible stutter every ~400–450 characters, landing mid-word.

**Fix:** collect while idle instead of while typing.

```elisp
(setq gc-cons-threshold (* 64 1024 1024) gc-cons-percentage 0.2)
(run-with-idle-timer 4 t #'garbage-collect)
```

You could use the `gcmh` package instead, which does the same thing. Don't go above ~128 MB: each collection then takes longer when it does happen.

### B5 — P1 — All modules run interpreted, including the hot paths

**Evidence**

- This was a deliberate choice (commit af435d1, so edits apply without rebuilds).
- The cost is small for setup code, but it matters for the functions that run per keystroke or per completion: B3 above, and H1.

**Fix**

- Keep loading as source.
- Byte-compile just the hot functions at load time: `(byte-compile 'my/vertico-sort-folders-first)`, and the same for the rtl functions in H1.
- This takes milliseconds at startup and needs no `.elc` files.

### B6 — P1 — `bin/install`: not reproducible, no pruning, refresh every run, a lockfile nobody reads

**Evidence** (`bin/install.el`)

- `package-refresh-contents` runs on every invocation (line 17).
- MELPA packages install at HEAD, so two installs a day apart differ.
- `packages.lock` is written (line 53) but nothing reads it. `lisp/packages.el:3` admits it is informational. The committed lock is also out of date with what is installed.
- Packages removed from the list are never deleted.

**Fix**

- Refresh only when a wanted package is missing from `package-archive-contents`.
- After installing, delete every `package-alist` entry that is neither in `my/packages` nor a dependency (`package--removable-packages` does this calculation).
- Either make the lock real (install from the recorded versions or commits via `package-vc` or a checksum check) or stop committing it and say so. Half-pinning is worse than either, because it suggests a guarantee that doesn't exist.

### B7 — P2 — The old checkout's elpa is out of date and full of orphans

**Evidence**

- `~/emacs-configs/elpa` has 67 package dirs.
- Among them are packages no longer in `lisp/packages.el`: projectile, consult-projectile, helpful, hydra, nix-mode, nov, pdf-tools, envrc, valign, typst-ts-mode, and others.
- It lacks transient (B1).
- Nothing uses this tree any more. The live elpa is `~/.local/share/emacs-configs/elpa`.

**Fix**

- After B1, delete `~/emacs-configs/elpa`, `~/emacs-configs/state`, and the per-profile `eln-cache` dirs in the checkout.
- Add them to `.gitignore` if they aren't already.
- Optionally copy `state/` (savehist, recentf, places) to the new root first. See N5.

### B8 — P2 — savehist saves the kill-ring with text properties

**Evidence**

- `lisp/core.el:61` sets `savehist-additional-variables '(kill-ring)`.
- Kill-ring entries from org or magit carry faces and `display` properties. That makes `savehist` files large, makes every autosave write slow, and can store unreadable objects.

**Fix**

```elisp
(setq savehist-additional-variables '(kill-ring)
      kill-ring-max 60)
(add-hook 'savehist-save-hook
          (lambda () (setq kill-ring (mapcar #'substring-no-properties
                                             (seq-filter #'stringp kill-ring)))))
```

### B9 — P2 — consult previews can load large org files

**Evidence**

- `consult-preview-key '(:debounce 0.2 any)` (`lisp/completion.el:62`).
- Moving through `consult-buffer` or `consult-recent-file` over a large org file runs the full org-mode setup for the preview, including org-modern and the rtl hooks in the hebrew/notes profiles. That is a visible hitch.

**Fix**

- Preview is already lazy for unopened files with `consult-preview-allowed-hooks`. Also add `(setq consult-preview-max-size 2000000)`.
- Use `consult-customize` to set `:preview-key "M-."` for `consult-recent-file`, so files are previewed only on request.

### B10 — P2 — `consult-ripgrep` runs single-threaded

**Evidence**

- `--sort path` (`lisp/completion.el:65`) forces ripgrep to one thread.
- That is unnoticeable in small repos, but slow across `~/Documents`.

**Fix:** drop it, or keep it only for `consult-ripgrep` in project roots.

### B11 — P2 — `dired-listing-switches` assumes GNU ls

**Evidence**

- `lisp/navigation.el:5` uses `--group-directories-first`.
- The repo ships `.cmd` launchers, which suggests Windows use. There, or with BSD ls, dired errors out.

**Fix**

```elisp
(setq dired-listing-switches
      (if (and (executable-find "ls") (not (eq system-type 'windows-nt)))
          "-al --group-directories-first" "-al"))
```

Alternatively set `ls-lisp-dirs-first t` on Windows.

### B12 — P2 — `auto-revert` messages on every revert

**Evidence**

- `global-auto-revert-mode` is on. `auto-revert-verbose` is at its default `t`, which floods the echo area when git operations change many files.

**Fix:** `(setq auto-revert-verbose nil)`.

### B13 — P2 — The three `early-init.el` files are near-identical copies

**Evidence**

- `configs/*/early-init.el` differ only in the profile name. This is old audit item 2.12, still open.

**Fix**

- Reduce each to two lines that set the profile and `(load (expand-file-name "../../lisp/early.el" ...))`.
- Move the module list to a single `lisp/profiles.el`, using an alist from profile to modules.

### B14 — P2 — `bin/check` tests batch only

**Evidence**

- `bin/check` loads each profile in `--batch`. It would not have caught B1 (stale daemon), H2 (labels missing until the first command), or anything that needs redisplay.

**Fix**

- Add a daemon smoke test: start a throwaway daemon with `--fg-daemon=check-$p` and a temporary server dir.
- `emacsclient --eval` a find-file of a fixture org file, run `(redisplay)`, and assert on overlays and features.
- Kill the daemon afterwards.
- Keep `test/invariants.el` for settings.

---

## Profile: hebrew

Module list: core files bidi ui completion editing navigation terminal prose writing footnotes rtl search-hebrew export ai.

### H1 — P1 — The footnote-label hook rebuilds every label on every keystroke

**Evidence**

- `lisp/rtl.el:39` `my/rtl-footnote-labels-follow` runs from `post-command-hook`.
- Its change-signature includes `buffer-chars-modified-tick` (line 40). Any typed character therefore deletes and recreates every label overlay in the visible region (`my/rtl-footnote-labels`, line 24).
- Measured, ms per typed character:

  | File | Current hook | Incremental (fix) | No hook at all |
  |---|---|---|---|
  | fn-long (long bidi paragraphs) | 21.6 | 19.4 | 18.0 |
  | fn-big (many short footnotes) | 9.5 | 9.5 | 8.7 |

  The fix recovers about 60% of the hook's cost on long-line files. The rest is the overlays' own redisplay cost.
- For comparison, on the same file:
  - text-mode is 13.5 ms;
  - org as configured is 16.7 ms;
  - `bidi-inhibit-bpa` makes no difference.

  So redisplay of the bidi text dominates, and org itself adds 2–3 ms.
- I also prototyped a font-lock/jit-lock version. It was correct but 3–4× slower (44–70 ms per character), so I rejected it.

**Fix:** rebuild only when an edit could change labels.

- That means a deletion, a newline, or typing inside or in front of an `[fn:…]` at line start.
- Window scrolling and resizing still trigger a rebuild through the signature.

Prototype (tested: a broken label loses its display, a repaired one gets it back):

```elisp
(defvar-local my/rtl-footnote-dirty t)

(defun my/rtl-footnote-note-change (beg end len)
  (unless my/rtl-footnote-dirty
    (setq my/rtl-footnote-dirty
          (or (> len 0)
              (save-excursion (goto-char beg) (search-forward "\n" end t))
              (save-excursion
                (goto-char beg) (beginning-of-line)
                (and (eq (char-after) ?\[)
                     (or (not (looking-at "\\[fn:[^]\n]*\\]"))
                         (<= beg (match-end 0)))))))))

(defun my/rtl-footnote-labels-follow ()
  (let ((sig (mapcar (lambda (w) (cons w (my/shown-region w)))
                     (get-buffer-window-list nil nil t))))
    (when (or my/rtl-footnote-dirty (not (equal sig my/rtl-footnote-signature)))
      (setq my/rtl-footnote-signature sig
            my/rtl-footnote-dirty nil)
      (my/rtl-footnote-labels))))

(add-hook 'org-mode-hook
          (lambda ()
            (add-hook 'after-change-functions #'my/rtl-footnote-note-change nil t)
            (add-hook 'post-command-hook #'my/rtl-footnote-labels-follow nil t)))
(mapc #'byte-compile '(my/rtl-footnote-note-change my/rtl-footnote-labels-follow
                       my/rtl-footnote-labels my/shown-region))
```

Also use a named function instead of the lambda in `org-mode-hook` (line 49), so it can be removed and is not added twice when the module is reloaded.

### H2 — P1 — Footnote labels are missing until the first command after opening a file

**Evidence**

- Labels are built only from `post-command-hook`. Right after `find-file` there were 0 RLM overlays in the buffer. They appear on the first keypress or scroll.
- A file opened from `emacsclient`, or restored by `desktop` or `activities`, shows raw labels until touched.

**Fix:** also build once when the buffer first gets a window.

```elisp
(add-hook 'window-buffer-change-functions
          (lambda (_) (setq my/rtl-footnote-dirty t) (my/rtl-footnote-labels-follow))
          nil t)
```

Put this inside the same org-mode-hook function.

### H3 — P2 — `my/shown-region` estimates the visible region in logical lines

**Evidence**

- `lisp/rtl.el:16` uses `forward-line (1+ window-body-height)`.
- With `visual-line-mode` (on in all text buffers), one logical line can be many screen lines, so the region covers far more text than is visible. That is more overlays to rebuild.
- It is correct (a superset) but wasteful on long paragraphs.

**Fix:** use `(window-end w t)`, which is exact after redisplay. Fall back to the current estimate only when `window-end` is stale (`(window-end w)` before the first redisplay).

### H4 — note — RTL motion remaps are intentional

`forward-char`/`backward-char` are remapped to `right-char`/`left-char`. That is correct for visual RTL movement. Elisp that calls `forward-char` directly is unaffected, because remaps only apply to keys.

### H5 — note — `search-hebrew.el` is fine

The isearch advice and the orderless dispatcher cost nothing measurable.

---

## Profile: notes

The notes module list is hebrew's minus `rtl` and `search-hebrew`. H1–H3 therefore don't apply, but everything in "Shared by hebrew and notes" below does.

### O1 — P2 — No Hebrew fontset, though notes contain Hebrew

**Evidence**

- `lisp/ui.el:9` sets the Hebrew fontset only in the hebrew profile.
- In notes, Hebrew falls back to font search. That is a different font, and it costs a font lookup the first time each glyph is shown.

**Fix:** set the fontset in every profile. It is cheap.

```elisp
(set-fontset-font t 'hebrew (font-spec :family "Noto Serif Hebrew"))
```

### Shared by hebrew and notes (prose, footnotes, export)

#### P1 — P1 — Export runs the whole org setup twice on the staged copy

**Evidence**

- `lisp/export.el` stages a copy of the file and opens it with `find-file-noselect`. That already runs `org-mode` and every hook: rtl labels, org-modern, olivetti, and so on.
- It then calls `(org-mode)` again at line 89.
- On large files this doubles the export's setup cost and renders overlays nobody sees.

**Fix:** open the staged copy without hooks, then enable org once.

```elisp
(let ((org-mode-hook nil) (auto-mode-alist nil))
  (with-current-buffer (find-file-noselect staged)
    (org-mode)
    ...))
```

Alternatively use `(with-temp-buffer (insert-file-contents staged) (org-mode) ...)`, which is what ox expects anyway.

#### P2 — P2 — org-modern is cut off by file size, not by cost

**Evidence**

- `lisp/prose.el` enables org-modern only below 200 KB. That is a reasonable guard.
- org-modern's unfontify removes **all** `display` properties, while org's own `org-unfontify-region` removes only org's. Nothing here currently relies on display *properties* (the footnote labels use overlays, which are safe). Anyone who later moves labels to text properties would see them wiped.

**Fix:** none needed now. Leave a comment next to the org-modern block recording this constraint.

#### P3 — note — footnotes.el is fine

`org-footnote-auto-adjust nil` is right for hand-ordered footnotes. Dropping org's footnote font-lock keyword (in prose.el) is right, because labels are drawn by rtl.el in hebrew.

---

## Profile: ide

Module list: core files bidi ui completion editing navigation terminal writing ide vcs ai.

### I1 — P1 — `project-remember-projects-under` doesn't do what its comment says

**Evidence**

- `lisp/vcs.el:16` calls `project-remember-projects-under "~/Documents/"` from magit's `:config`.
- The comment says every repo is remembered at startup. In fact:
  - it runs only when magit first loads;
  - it is **non-recursive**, so only direct children of `~/Documents` that are repos are found. ~/Documents has 20 entries.

**Fix:** decide which behaviour you want, then fix the comment either way.

- To remember repos at depth: `(project-remember-projects-under "~/Documents/" t)` on an idle timer after startup. The recursive scan is slow on large trees, which is why it shouldn't be in init.
- Otherwise, drop the call and let `project.el` remember projects as you visit them. That is the default behaviour and costs nothing.

### I2 — P2 — yasnippet: slow first prog buffer, and a snippets dir inside the config

**Evidence**

- `lisp/ide.el:34` calls `yas-reload-all` in `:config`. It runs on the first prog-mode buffer and loads every snippet table, so the first file you open stalls.
- The default `yas-snippet-dirs` includes `configs/ide/snippets` under `user-emacs-directory`. With the Nix layout that dir is a store link or doesn't exist, so a new snippet can't be saved there.

**Fix**

```elisp
(setq yas-snippet-dirs (list (expand-file-name "snippets" my/state-dir)))
```

Then either drop `yas-reload-all` (`yas-minor-mode` loads tables lazily per mode) or run it from an idle timer.

### I3 — note — eglot watched-files advice

The lambda advice declining `workspace/didChangeWatchedFiles` (`lisp/ide.el:23`) is a valid performance choice for large repos. The downside is that servers won't notice files changed outside Emacs, such as on a git checkout, until a restart. Make it a named function so it can be toggled, and document the trade-off.

### I4 — note — the rest of ide.el and vcs.el is fine

corfu with `auto nil`, rust format-on-save, cargo, rainbow-delimiters, slime, magit, diff-hl and git-timemachine are all deferred and fine.

---

## Nix side (`~/config`)

### N1 — P1 — Edits to `~/emacs-configs` don't reach Emacs: a trust problem

**Evidence**

- The runtime root links into the store copy of the `emacsConfigs` flake input.
- An edit in the checkout does nothing until you push, run `just update-emacs`, switch, *and* restart the daemon.
- This is the opposite of what commit af435d1 (load source, so edits apply immediately) was for. It is easy to "fix" something, see no change, and stop trusting the config.

**Fix:** add a dev mode.

- Option 1: an `emacsConfigs.dev = true` option in `modules/home/emacs.nix` that uses `config.lib.file.mkOutOfStoreSymlink "${home}/emacs-configs/lisp"` (and the same for vendor, bin and test) instead of store paths.
- Option 2: switch with `--override-input emacsConfigs path:/home/…/emacs-configs` while iterating.

The first is simpler day to day.

### N2 — P1 — `CHANGES.md` claims the daemons were "repaired in place"

**Evidence**

- The uncommitted entry says this, but the daemons were never restarted (B1). That claim is how the errors looked like a config bug.

**Fix:** reword it to say the daemons must be restarted after the migration, and why.

### N3 — P1 — Empty eln-cache: the first daemon start will native-compile ~49 packages in the background

**Evidence**

- Each profile's `eln-cache` in the new root is 8 KB, i.e. empty. The old ones are 0.6–1.8 MB.
- On the first real start of each daemon, JIT native compilation runs for every package as it loads. That means several minutes of high CPU, with Emacs feeling sluggish meanwhile.
- It happens per profile, because the caches are separate.

**Fix**

- Have `bin/install.el` end with `(native-compile-async package-user-dir 'recursively)`, run in the foreground with a wait loop so it completes inside activation.
- Alternatively start each daemon once after switching and let it finish before relying on it.
- Use one shared eln-cache for elpa instead of three, by setting `native-comp-eln-load-path` to a shared dir first. The packages are identical across profiles.

### N4 — P2 — Activation installs only when `elpa/` is empty

**Evidence**

- `modules/home/emacs.nix` activation runs `emacs-install` only on an empty elpa.
- A package added to `lisp/packages.el` is therefore not installed on switch. It fails at load time with a missing-package error until you run `emacs-install` by hand.

**Fix**

- Run install on every activation, but make it cheap: see B6, no refresh unless something is missing.
- Alternatively compare a hash of `packages.el` against a stamp file in `state/`.

### N5 — P2 — Old state wasn't migrated

**Evidence**

- savehist, recentf and save-place data live in the old `~/emacs-configs/state`. The new root started fresh, so history and recent files are gone after B1's restart.

**Fix:** a one-off `cp -n ~/emacs-configs/state/* ~/.local/share/emacs-configs/state/`, done before deleting the old tree (B7).

---

## Docs

### D1 — P2 — `plan.md` is stale

It still mentions projectile and hydra, and lists as "dropped" packages that are present (crux, dirvish, and others). **Fix:** rewrite it from the current `lisp/packages.el`, or fold it into `DECISIONS.md` and delete it.

### D2 — note — previous AUDIT.md

The previous AUDIT.md said Emacs 31.1, but this setup runs 30.2. It has been replaced by this file. Fixed from it: item 2.3 (custom.el load order) and the `bin/install` exit status. Still open: 2.12, now B13.

---

## Appendix: how the numbers were taken

- **Setup**
  - Throwaway daemons ran under `script` in a 50×140 tty, with the real elpa and the real profile `init.el`.
  - Fixtures were `fn-long.org` (long Hebrew paragraphs with footnotes) and `fn-big.org` (many short footnotes).
- **Typing**: 500 `self-insert-command` iterations, each followed by `post-command-hook` and a forced `redisplay`, timed with `benchmark-run`.
- **Scrolling**: `scroll-up-command` plus redisplay, per page.
- **GC**
  - `(benchmark-run 1 (garbage-collect))` in the live daemons.
  - Allocation per character was taken from `memory-use-counts` deltas.
- **Sort**: `benchmark-run 5` over every `commandp` symbol name.
- **Caveat**: tty redisplay is cheaper than pgtk. Expect the GUI's absolute ms to be higher and the ratios similar.
