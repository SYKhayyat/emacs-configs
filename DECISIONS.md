# Decisions

- Startup: `(emacs-init-time)` 0.15-0.19 s when first measured; re-measured 2026-11-16 at ~0.27 s init and ~0.6-0.95 s until the daemon socket answers (old config: 6.1 s).
- Profiles: hebrew = Hebrew notes (RTL, niqqud search, Hebrew font); notes = English Org/Markdown without that; ide = code.
- Completion order: alphabetical, folders first, globally (no history ranking in M-x).
- Mostly lazy (`:commands`, `:bind`, `:hook`; vertico, marginalia load at start on purpose) ; packages own `elpa/`, quickstart on.
- bidi-paragraph-direction stays nil: forcing it costs 10-50x on wrapped Hebrew. Footnote RTL is a buffer-local display overlay.
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
