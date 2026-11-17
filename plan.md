# plan.md — critique and the way forward

Written 2026-11-15 after reading `~/emacs-configs` (the new 5-stage repo, 32
commits) and `~/emacs-config` (= `emacs-config-deprecated`, the Nix-deployed
config you use every day), and after measuring the old one. Where this file
gives a number, it was measured on this machine today.

---

## 0. The manifesto

Yours, in your words, then the additions I am proposing (marked ✚). Everything
below this section is judged against it.

1. **Emacs can do anything. That does not mean it should do everything.**
   Include only what is needed.
2. **Emacs can do anything. Is there anything Emacs can do that we are
   ignoring?** Look at what is built in before reaching for a package, and
   before deciding something can't be done.
3. **Never sacrifice speed or lightness for cosmetics.**
4. **Emacs may be older than your grandfather, but it should move faster.** It
   is the greatest piece of software ever written, and it should compete with
   any other editor on speed, features and weight.

Proposed additions:

5. ✚ **Built-in first.** A package goes in only when it clearly beats the
   built-in, and you can say in one sentence how. (`project.el` over projectile,
   `eglot` over lsp-mode, `undo-redo` over undo-tree, `modus-themes` over
   doom-themes.)
6. ✚ **Lazy by default.** Nothing loads before you use it. Startup loads
   settings, never features. Use `:hook`, `:commands`, `:bind` and autoloads,
   never a top-level `require`.
7. ✚ **Measure what you feel, not everything you can.** Profile when something
   feels slow (`M-x profiler-start`). Don't write up a price for a setting that
   costs under a millisecond. Section 2 gives the budget.
8. ✚ **Use it daily, or it isn't done.** A stage is finished when you have
   written in it for a week, not when a test harness says so.
9. ✚ **Trust what the community already knows.** Thirty years of Emacs use
   have settled most questions. Where a well-known answer exists (vertico, GC
   during init, `so-long`), take it and move on. Re-derive only what is
   specific to you: Hebrew, footnote-heavy sefarim, Typst.
10. ✚ **One owner per setting.** Each variable is set in exactly one place.
    (The old config's PLAN found five cases where two modules fought over one
    setting.)
11. ✚ **Never touch the user's text behind their back.** No invisible
    characters, no silent reformatting. The new repo already does this well:
    its export works on a staged copy.

---

## 1. Why your daily Emacs is slow — and a fix for today

### Startup: 6.1 s, 441 features

Measured today in a real tty, profiling every `load` and `require`. The numbers
nest, so a parent includes its children:

| cost | what | verdict |
|---|---|---|
| **3,410 ms** | `06-org-roam` → `require org-roam` → org (2.6 s) → ox (1.2 s) + magit-section (0.4 s) | eager. `org-roam-db-autosync-mode` forces all of org at startup |
| 1,587 ms | `01-ui`: doom-modeline 526, nerd-icons 183 + all-the-icons 91, winner 405, pulsar 135 | cosmetics, rule 3 |
| 753 ms | `00-core` | includes `package` 426 ms + `use-package` 277 ms, i.e. no `package-quickstart` |
| 396 ms | `11-pdf`: pdf-tools loaded eagerly | should load on the first PDF |
| 149 + 134 + 128 | projectile, dirvish (+ side-follow mode), 03-editing | replace with built-ins or load lazily |

`emacs-init-time` is 6.1 s. A sensible config with the same features starts
in under 0.5 s.

### Runtime: three settings you already measured in the new repo

The new repo found three things that make Hebrew org crawl. The old config has
**all three**:

| old config | what the new repo measured | effect on you every day |
|---|---|---|
| `00-core.el:242` `(setq-default bidi-paragraph-direction 'left-to-right)` | forcing a direction that doesn't match the text: **286 ms per line moved, 96 ms per keystroke** on a 340 KB sefer (8 ms with nil) | **this is most of your "runtime is slow".** Every Hebrew paragraph is laid out against its own direction |
| `05-org.el:22` `org-footnote-auto-adjust t` | **863 ms per footnote inserted** on the 407 KB sefer | every `C-c C-x f` stalls for most of a second |
| font-lock on in org, with org's footnote highlighting | **3.5 s** to fontify the sefer, **38 ms per keystroke** near a footnote | jumps and searches stall, and typing in the notes lags |

There is more on top, each item smaller: `org-startup-indented` (org-indent is
slow on big files), `valign-mode` in every org buffer, `org-modern`, global
`undo-tree` with history saved on every save, relative line numbers in
text-mode, `global-hl-line-mode`, doom-modeline updating on every command, and
`gcmh` fighting the GC settings in early-init.

### Stopgap for today (about 5 minutes, no rebuild)

`~/.config/emacs/custom.el` is writable and gets loaded before the modules. A
plain `setq` there would be overwritten by the modules, so run the fixes
**after init**. Append this:

```elisp
;; Stopgap until the new config replaces this one. See ~/emacs-configs/plan.md §1.
(add-hook 'after-init-hook
          (lambda ()
            (setq-default bidi-paragraph-direction nil) ; let each paragraph pick its direction
            (setq bidi-inhibit-bpa nil)))
(with-eval-after-load 'org
  (setq org-footnote-auto-adjust nil
        org-startup-indented nil)
  (remove-hook 'org-mode-hook #'valign-mode)
  (remove-hook 'org-mode-hook #'org-modern-mode))
(add-hook 'org-mode-hook
          (lambda ()
            (setq-local org-font-lock-keywords
                        (seq-remove (lambda (kw) (string-match-p "org-activate-footnote-links"
                                                                 (format "%S" kw)))
                                    org-font-lock-keywords))
            (when (bound-and-true-p undo-tree-mode) (undo-tree-mode -1))))
```

**Test it:** open the big sefer and hold `C-n` for two seconds. Then type in
the middle of a footnote. Both should now feel instant. If a `remove-hook`
does nothing because the old config added a lambda instead of the named
function, use `M-x describe-variable org-mode-hook` and comment out the line
in a local clone.

That makes your daily editor usable while you build the new one. Don't spend
more than that on the old config. It is being retired.

---

## 2. Critique of the new repo

### What is genuinely good — keep it

- **The findings themselves.** The bidi trap (forcing a direction costs 10–50×
  on wrapped text), the org footnote face, `org-footnote-auto-adjust`, and the
  org `require` chain (~0.5 s) are real, valuable, and not widely known. They
  are the reason the old config is slow.
- **The footnote-label overlay** (`configs/hebrew/modules/display.el`): clever,
  correct, and it never touches the text.
- **Typst export on a staged copy**, leaving one PDF beside the source. Also
  the empty-footnote guard and the patched ox-typst with an upstream PR. Typst
  is the right choice: it is fast, and LaTeX bidi was a swamp in the old
  config.
- **The daemon-first launcher with per-profile server names.** That is the
  right answer to "org takes 0.5 s to load the first time".
- `custom-file` in a state dir that tolerates a corrupt file; `vc-handled-backends
  '(Git)`; lockfiles off and auto-save on; `read-process-output-max`.

### What is wrong — the process, not the code

**After 3 days and 32 commits, the profiles you would write in have no
completion, no minibuffer history, no recent files, no font for Hebrew, and no
niqqud-insensitive search.** Meanwhile the repo has 1,268 lines of harness
(`bin/` + `test/`), a 450-line HANDOFF, and a written-up measurement of a 1.5 ms
clipboard read. That is the "AI spends forever figuring out ground truths" you
described, and it has three causes:

1. **The rule "Nothing gets in without a number" is taken literally.** An agent
   given that rule will measure `use-short-answers`. Replace it with a
   **budget**:
   - *No measurement needed:* built-in settings, and well-known packages
     configured the standard way (vertico, orderless, marginalia, consult,
     savehist, recentf, eglot, magit).
   - *Measure:* anything on the **per-keystroke or redisplay path** (hooks on
     `post-command-hook`, `after-change-functions`, font-lock keywords, mode-line
     segments); anything that adds **> 5 ms to startup**; anything that **feels**
     slow.
   - *Targets:* startup < 100 ms of our own code; a keystroke < 8 ms on the
     sefer; first open of the sefer < 300 ms in the daemon.
2. **Stage gating plus "verify on Windows/macOS" is a deadlock.** You said
   Windows is "maybe someday", so stages 2 and 3 can never be called finished.
   **Drop the cross-platform gate.** Keep the code portable (relative paths are
   free) and file "first Windows run" as a normal task with no stage blocked on
   it.
3. **The handoff documents re-explain everything, so each session re-verifies
   everything.** HANDOFF.md is 450 lines of narrative. An agent reads it, doubts
   it, and re-measures. Replace it with a **`DECISIONS.md` of at most ~60
   lines**: one line per decision, its number, and "settled — do not
   re-measure". Put narrative in commit messages.

### What is wrong — the code

| where | problem | fix |
|---|---|---|
| `base/prose.el` | `(global-font-lock-mode -1)` runs in **every** profile, including `ide`, and the file contains `(memq my/profile '(hebrew notes))`. This breaks your own rule 4 ("base is profile-agnostic") | move `prose`, `footnotes` and `export` to `shared/prose/` and list them only in the hebrew and notes MANIFESTs |
| font-lock off in prose | your own measurement shows colour on English prose is nearly free (3.9 → 4.7 ms per keystroke, 64 ms for the whole buffer). The 3.5 s cost was the footnote keyword, which you already strip. Org heading colour is structure, not decoration | **test:** font-lock on, footnote keyword stripped, on the sefer. If a keystroke stays < 8 ms, turn it back on (at least `font-lock-maximum-decoration` 1) |
| `display.el` | a **global** `post-command-hook` runs after every command in every buffer of the hebrew profile | add it buffer-locally from `org-mode-hook`: `(add-hook 'post-command-hook #'my/rtl-footnote-labels-follow nil t)` |
| `base/core.el` idle modes | an idle timer plus a wall-clock fallback plus an idempotence flag, written to defer `delete-selection-mode`. The "didn't fire 1 in 9" observation came from Xvfb with injected events | one `run-with-idle-timer`, or just enable them at init. `delete-selection-mode` and `which-key` cost almost nothing once native-compiled |
| `base/packages.el` + `base/autoload.el` | a hand-rolled package activator (`my/autoload` reads `-autoloads.el` files) to dodge a "~200 ms" `package-initialize` | use built-in **`use-package`** + **`package-quickstart t`** (activation drops to ~10–30 ms; **test** it). Vendor only what you patch (ox-typst). This is where adding vertico becomes one line |
| literate `.org` → tangled `.el` → `.elc`, all three kept, plus a staleness check | every 20-line module carries a 100-line org file, so each change is edit → tangle → build → check. The old config had the same duplication, and it is part of why it got unmaintainable | **drop literate.** Use plain `.el` with comments, and keep the reasoning in `DECISIONS.md`. That halves what you (and an agent) have to read |
| `MANIFEST` loader + "unlisted module = test failure" | reasonable, but heavy for 7 files | keep it if you like it. A single `(dolist (m '(core files prose …)) (load …))` in `init.el` is the boring equivalent |
| `early-init` | `menu-bar-mode -1` etc. are function calls | best practice is frame parameters: `(push '(menu-bar-lines . 0) default-frame-alist)` (also `tool-bar-lines`, `vertical-scroll-bars`). Avoids one resize and is the documented way |
| `test/probe.el`, `bin/gui-test.sh` (Xvfb), messages-log silence | infrastructure for proving a startup is silent | delete it. Keep `test/export-*.el` (it guards real behaviour) and a short `invariants.el` |
| `state/rtl/` | leftover profile dir | delete |

### On three profiles

You want them for **mental separation and speed**. Separation is a good
reason: three daemons, three windows, three kinds of work. Keep them.

Speed is mostly **not** a reason. Major modes are per buffer, so a `.rs` file
never pays for org, and org never pays for eglot, as long as everything is
lazy (rule 6). The real speed levers are laziness and the three traps in §1.
So: keep three profiles, but make them **thin lists over one shared set of
modules**. Don't make them three configs that each have to be maintained.

---

## 3. What we are ignoring that Emacs already does (rule 2)

All of these are built in, cost no package, and in most cases cost almost no
time:

| need | built-in answer |
|---|---|
| remember minibuffer history | `savehist-mode` |
| recent files | `recentf-mode` (set `recentf-max-saved-items` 200, and turn it on at the idle timer) |
| come back to where you were in a file | `save-place-mode` |
| undo/redo | `undo-redo` (`C-M-_`), and `undo-limit` raised. Drop undo-tree |
| projects | `project.el` (`C-x p`) |
| LSP | `eglot`. Tree-sitter: `treesit` + `*-ts-mode` + `major-mode-remap-alist` |
| key hints | `which-key` (built in since 30) |
| repeating `C-x o o o` | `repeat-mode` |
| completion in buffer | `completion-preview-mode` (30+) for prose. Corfu only if you want a popup in code |
| match counts in isearch | `isearch-lazy-count t` (drop anzu) |
| window undo | `winner-mode` (but it cost 405 ms eager in the old config, so enable it at the idle timer) |
| editorconfig | `editorconfig-mode` (built in since 30) |
| restart | `restart-emacs` (built in since 29). Drop the package |
| themes | `modus-operandi` / `modus-vivendi`, built in, fast and accessible. Drop doom-themes |
| file browser | `dired` + `dired-x` + `wdired`. Drop dirvish (and its global side-follow mode) |
| diff / merge | `ediff`, `vc` |
| outline navigation in a sefer | `imenu` + `consult-imenu`; `outline-minor-mode` |
| large files | `so-long`, and `find-file` warns at `large-file-warning-threshold` |
| package startup | `package-quickstart` |
| native compilation | already on (there is an eln-cache). Make sure the new repo's elpa gets native-compiled too: `native-comp-jit-compilation t` is the default |
| Hebrew typing without the OS layout | `set-input-method "hebrew"` (`C-\`) |

---

## 4. The modules you need, per profile

The rule for this list: needed, built-in where possible, lazy.

### Shared by every profile (`base/`)
- what is there now (minus prose), plus **`savehist`, `recentf`, `save-place`,
  `repeat-mode`, `winner` (idle)**
- **completion:** `vertico` + `orderless` + `marginalia` + `consult`. This is
  the community consensus: small, fast, built on the standard completing-read
  API. (Zero-package option: `fido-vertical-mode`, but you lose orderless and
  consult.) `consult-line`, `consult-ripgrep` and `consult-buffer` cover most
  of what the old seforim-search modules hand-rolled.
- a **theme**: `modus-operandi`, one line
- **fonts:** one `set-face-attribute 'default` and, in the prose profiles,
  `(set-fontset-font t 'hebrew (font-spec :family "…"))`. Which Hebrew font?
  (Question at the end.)

### `hebrew` (in addition to `shared/prose/`)
- what is there now: the footnote-label overlay, the C-f remap, olivetti, export
- **niqqud-insensitive search.** You had `C-c s` in the old config. Port it.
  The core is a function that turns `בר` into `ב[֑-ׇ]*ר`, used as the
  `search-default-mode` or through `isearch-search-fun-function`. **Test:**
  `C-s` for an unpointed word finds the pointed one. (Built-in `char-fold` does
  *not* do this. Niqqud are combining marks *between* letters.)
- **spell-check:** `jinx` with `"he_IL en_US"`. The old config switched jinx
  off after a freeze. The comments blame its keybinding remaps colliding with
  completion, so retry jinx *without* the `ispell-completion-at-point` remap.
  **Test:** type quickly in the sefer for 30 s with jinx on, and with
  `profiler-start` running.
- `consult-ripgrep` over the library (28,827 files), instead of the old
  `12-seforim-search`

### `notes`
- `shared/prose/` + `markdown-mode` (lazy, `:mode "\\.md\\'"`) + jinx `en_US`

### `ide` (stage 4)
- `treesit` + grammars **from Nix** (`emacs.pkgs.treesit-grammars.with-all-grammars`
  via home-manager, and add its path to `treesit-extra-load-path`). Never
  `treesit-auto`: it is old bug #35, which reverted unsaved buffers.
- `eglot`, with `(setq eglot-events-buffer-config '(:size 0 :format full))` and
  `eglot-autoshutdown t`. Language servers come from Nix through **`envrc`**.
  That one is needed: without it, eglot can't find per-project servers on
  NixOS.
- `magit` (lazy, `C-x g`), `flymake` (built in), `project.el`
- `corfu` *or* `completion-preview-mode`. Try the built-in first (rule 5)
- terminal: `vterm` (compiled by Nix), or `eat` (pure elisp, works on Windows)
- Common Lisp: `sly`. Java: eglot + `jdtls` from Nix. Don't use eglot-java,
  which caused the old JDT download problem (#31)
- `font-lock` **on** here, per your own measurement (1.5–3 ms per keystroke)

---

## 5. Triage of the old config (stage 5, decided here so it isn't a stage)

Keep = it moves to the new repo, configured lazily. Drop = it does not come.

Decided 2026-11-16, package by package with the user. Final list: `lisp/packages.el`; reasons: `DECISIONS.md`.

| package / module | verdict | why |
|---|---|---|
| vertico, orderless, marginalia, consult, embark, embark-consult, wgrep | **keep** | completion stack; `C-c o` toggles orderless |
| corfu | keep (ide), manual trigger only | `corfu-auto nil` |
| magit, diff-hl, git-timemachine | keep (ide only) | |
| eglot | keep (ide) | Python, Rust, Java |
| rust-mode, cargo | **keep** (ide) | no tree-sitter grammar needed |
| SLIME | keep (ide) | Common Lisp with sbcl |
| rainbow-delimiters, yasnippet(+snippets) | keep (ide) | |
| olivetti, org-modern, markdown-mode, org-download | keep | org-modern only under 200 KB |
| avy, ace-window, multiple-cursors, expand-region, move-text, goto-last-change, beginend, crux, visual-regexp | keep | few losses, lazy |
| vundo | keep | replaces undo-tree |
| activities, dirvish | keep | |
| eat | keep, every profile | terminal panel; rejected vterm and cooked |
| gptel | keep | lazy |
| envrc, nix-mode, typst-ts-mode, pdf-tools, nov | **dropped** | not used; add pdf-tools back when reading PDFs in Emacs |
| valign, hydra, helpful, projectile (+consult-projectile) | dropped | `project.el`, `transient`, tables are rare |
| treesit-auto | dropped | data-loss bug #35 |
| eglot-java | dropped | #31 |
| undo-tree, git-gutter, anzu | dropped | vundo, diff-hl, `isearch-lazy-count` |
| doom-modeline, doom-themes, nerd-icons, all-the-icons(-dired), pulsar, focus, diminish, gcmh | dropped | cost on the redisplay path; early-init owns GC |
| restart-emacs, editorconfig, which-key packages | dropped | built in |
| engine-mode, 21-web-search | dropped | `browse-url` / `eww` |
| org-roam(+ui), citar(+org-roam), jinx | dropped | startup cost; native dependency |
| 07-latex, 03-hebrew-typesetting, auctex | dropped | Typst is the single export path |
| 09-context, 22-nix-system, seforim-* (10-16) | dropped | |
| 05-rich-footnotes, 02-hebrew-org | superseded by `display.el` + `footnotes.el` | |
| 00-hebrew, 01-hebrew-completion, 24-utils | **not yet reviewed** | see the open list in the last session |

## 6. Order of work (debt first)

**Step 0 — today.** Paste the stopgap from §1 into `~/.config/emacs/custom.el`.

**Step 1 — clear the new repo's debt (one session).**
1. Replace "nothing without a number" with the budget in §2. Remove the
   Windows/macOS gate, and close stages 2 and 3 for Linux.
2. Move `prose`, `footnotes` and `export` out of `base/` into `shared/prose/`.
   The ide profile must no longer turn font-lock off.
3. Make the footnote-overlay hook buffer-local.
4. Drop literate org: keep the `.el` files and delete the `.org` sources,
   `bin/build.el` and `--check`.
5. Delete `test/probe.el`, `bin/gui-test.sh`, the silence checks and `state/rtl/`.
6. Replace HANDOFF.md with a `DECISIONS.md` of at most 60 lines.
7. Switch packages to `use-package` + `package-quickstart`. Keep `vendor/` for
   ox-typst only (olivetti can be a normal package).

**Step 2 — make `hebrew` your daily writing editor (one or two sessions).**
Add the shared set from §4 (completion, savehist, recentf, save-place, theme,
fonts). Then add niqqud search, and jinx if it survives the test. Then **use
it for a week**, and keep a `FRICTION.md` of everything you reach for that
isn't there. That list is your real stage 5.

**Step 3 — `notes`:** markdown + jinx. Small.

**Step 4 — `ide`:** §4, one language at a time, starting with the one you use
most.

**Step 5 — retire the old config.** Point `~/.config/emacs` (home-manager) at
the new repo, or just launch `bin/emacs-hebrew` from your WM, and archive
`emacs-config-deprecated`.

---

## 7. How to test (the few tools that matter)

- **startup:** `emacs-init-time`; and for a breakdown, `(setq
  use-package-compute-statistics t)` then `M-x use-package-report`
- **"it feels slow":** `M-x profiler-start` (cpu) → do the slow thing →
  `M-x profiler-report`. Expand the biggest line. This finds the cause in
  minutes, and should come before any theorising
- **keystroke and scroll cost:** `(benchmark-run 50 (progn (next-line) (redisplay t)))`
  on the sefer
- **what runs on every command:** `M-x describe-variable post-command-hook`,
  and the same for `pre-command-hook` and `after-change-functions`. Every
  entry is a cost you pay constantly. The old config has five
- **what is loaded:** `(length features)`. The old config is at 441 after
  startup; aim for under 150 in `hebrew` before the first file opens

---

## 8. Instructions for whoever (human or AI) works on this next

- Read §0 and `DECISIONS.md`. Treat both as settled. Don't re-measure anything
  `DECISIONS.md` lists.
- Use the standard community configuration for standard packages. Don't
  research `savehist`.
- Measure only what the budget in §2 names, and time-box it: if a measurement
  takes longer than the feature, stop and ask.
- One feature per commit. A stage is done when the user has used it, not when
  the harness passes.
- When in doubt between a package and 10 lines of your own elisp, write the 10
  lines. When in doubt between your own 100 lines and a well-known package,
  take the package.

---

## 9. Questions for you

1. **Hebrew font:** which one do you write in? (Taamey Frank, SBL Hebrew,
   David CLM, Frank Ruehl CLM, Noto Serif Hebrew?) The PDF already has its own
   choice. This is the editor face.
2. **org-roam / citar / academic:** do you use org-roam links between the 689
   files, or citations? If not, they go (−3.4 s).
3. **seforim modules:** which 3–5 commands from `10-…16-seforim-*` do you
   actually press? Everything else in those 2,000 lines can go.
4. **gptel / local AI inside Emacs:** used, or not?
5. **The old `C-c s` niqqud search:** is it the behaviour you want, or did it
   miss things?
6. **Keys you can't live without** from the old config (avy? multiple-cursors?
   hydras?). Five at most.
