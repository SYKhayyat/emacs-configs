# Decisions

## Principles

Everything below is judged against these (they were section 0 of the old plan.md).

1. **Include only what is needed.** Emacs can do anything; that does not mean it should do everything.
2. **Look at what is built in** before reaching for a package, and before deciding something can't be done.
3. **Never sacrifice speed or lightness for cosmetics.**
4. **Emacs should move faster than any other editor**, and compete with any on speed, features and weight.
5. **Built-in first.** A package goes in only when it clearly beats the built-in, and you can say in one sentence how (`project.el` over projectile, `eglot` over lsp-mode, `vundo` over undo-tree, `modus-themes` over doom-themes).
6. **Lazy by default.** Startup loads settings, not features: `:hook`, `:commands`, `:bind`, autoloads.
7. **Measure what you feel, not everything you can.** Profile when something feels slow.
8. **Use it daily, or it isn't done.**
9. **Trust what the community already knows.** Take the settled answer (vertico, GC during init, `so-long`); re-derive only what is specific here: Hebrew, footnote-heavy sefarim, Typst.
10. **One owner per setting.** Each variable is set in exactly one place.
11. **Never touch the user's text behind its owner's back.** No invisible characters, no silent reformatting; export works on a staged copy.

## Choices

- Startup: `(emacs-init-time)` 0.15-0.19 s when first measured; re-measured 2026-11-16 at ~0.27 s init and ~0.6-0.95 s until the daemon socket answers (old config: 6.1 s).
- Profiles: hebrew = Hebrew notes (RTL, niqqud search, Hebrew font); notes = English Org/Markdown without that; ide = code.
- Completion order: alphabetical, folders first, globally (no history ranking in M-x).
- Mostly lazy (`:commands`, `:bind`, `:hook`; vertico, marginalia load at start on purpose) ; packages own `elpa/`, quickstart on.
- Compat is the real GNU ELPA package, required in core.el before completion loads. corfu, vertico and consult declare `(compat "31")`; the compat.el Emacs 30 ships is a stub that provides the feature and nothing else, so `set-local`, `incf`, `decf` and `completion-list-candidate-at-point` were void — and because `vertico--setup` calls `set-local`, every minibuffer command (C-x C-f, C-x b, M-x) died with "Symbol's function definition is void: set-local". A package can be installed and still be missing from `load-path` at the moment it matters: this was fixed by requiring it early, not by installing it.
- `bidi-paragraph-direction` stays nil: forcing it costs 10-50x on wrapped Hebrew. A buffer can still be pinned on request: `C-c r` / `C-c l` (every profile, not just hebrew), and pressing the pinned one again restores automatic, so a wrong automatic answer is recoverable from either direction. No cycle key: `C-c R` is `my/revert-buffer`, and one accidental shift is enough. While pinned the mode line says `RTL`/`LTR`; the label is a minor-mode lighter, so a buffer left automatic pays nothing per command. Footnote RTL is a buffer-local display overlay.
- `org-footnote-auto-adjust` nil (863 ms/insert); org's footnote font-lock keyword stripped. Font-lock stays on.
- org settings use `setq` in `:init`, not `:custom`: customize-set-variable loads org at startup.
- org-modern only for buffers under 200 KB. Dropped valign: tables are rare, and Org cells cannot be multiline anyway.
- Typst is the single export path; export runs on a staged copy, PDF lands beside the source.
- Dropped hydra: tab/writing commands have direct keys (`C-x t s` project in new tab, `C-c W` text width); `repeat-mode` covers repeats.
- Replaced: undo-tree → vundo, git-gutter → diff-hl, anzu → built-in `isearch-lazy-count`, doom-themes/modeline → modus-operandi, rust-ts-mode → rust-mode (no grammar needed).
- Languages (ide): Python (pyright), Rust, Java (jdtls), Common Lisp (SLIME + sbcl; chosen over sly for the documentation).
- Dropped: typst-ts-mode and lisp/typst.el (no grammar installed, no .typ editing; export from Org still uses typst), envrc, nix-mode, pdf-tools, nov (not wanted; pdf-tools had no built epdfinfo; add back when PDFs are read in Emacs), spell checking (jinx: native dependency, more trouble than worth), seforim app, org-roam, citar, latex, web-search, 09-context, 22-nix-system, icons, pulsar, focus, treesit-auto (data-loss bug: it reverts buffers).
- Undecided: eglot-java; whether query-replace needs an anzu-like count.
- Terminal: eat (pure Lisp, no compile) in every profile, bottom panel on `` C-` ``; login shell, `C-c t N` also offers Nushell and Bash. Rejected vterm (native build on NixOS) and vodik/cooked (Rust module built on first run, not on any package archive, young).
- Modules are not byte-compiled: startup is ~0.27 s, and compiling without Org loaded breaks Org macros (`org-with-wide-buffer`). custom.el loads last, as the one deliberate override layer.
- recentf excludes elpa/, state/, /tmp and export temp files; history-length 500 and kill-ring saved (no measurable startup cost). C-c r / C-c l pin RTL / LTR per buffer in every profile; the same key again restores automatic. Line numbers in prog-mode (ide). Tab bar shows only with 2+ tabs.
- eglot: decline server file-watch requests (pyright hit the 10000-watch limit and looped reconnects). Added dired-jump/wdired, C-c c compile, M-n/M-p diagnostics. Hebrew: C-c d/B/h q/h p/h c/h n kept (new note is Org only). Completion-preview skipped (corfu on TAB).
- F7 = embark-bindings: searchable cheatsheet from the live keymaps, includes built-in and mode keys. Hebrew helper keys (C-c d/B/h *) NOT wanted; only C-c r / C-c l kept.
- exec-path-from-shell: installed, used on macOS only. Skipped: Org auto-fill (soft wrap), built-in tree-sitter modes.
- GC: 64 MB threshold, 0.2 percentage, plus a collection after 4 s idle, so pauses land when nothing is typed. Native code: one shared `state/eln-cache/`, compiled asynchronously in the daemon 30 s after startup, not in the install.
- packages.lock is a local record of what was installed, not a pin: package.el cannot install an old version, so committing it promised what it could not do. The install refreshes archives only when a listed package is missing, and prunes what the list dropped unless an install failed.
- Footnote labels (hebrew) are built when a buffer is shown, not only after the first command; rebuilt only when an edit can change them.
