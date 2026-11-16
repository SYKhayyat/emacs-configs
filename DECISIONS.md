# Decisions

- Startup (daemon): hebrew 0.15 s, notes 0.18 s, ide 0.19 s (old config: 6.1 s).
- Everything lazy by default (`:commands`, `:bind`, `:hook`); packages own `elpa/`, quickstart on.
- bidi-paragraph-direction stays nil: forcing it costs 10-50x on wrapped Hebrew. Footnote RTL is a buffer-local display overlay.
- `org-footnote-auto-adjust` nil (863 ms/insert); org's footnote font-lock keyword stripped. Font-lock stays on.
- org settings use `setq` in `:init`, not `:custom`: customize-set-variable loads org at startup.
- org-modern and valign only for buffers under 200 KB (aligned tables never slow a big sefer).
- Typst is the single export path; export runs on a staged copy, PDF lands beside the source.
- Replaced: undo-tree → vundo, git-gutter → diff-hl, anzu → built-in `isearch-lazy-count`, doom-themes/modeline → modus-operandi, rust-ts-mode → rust-mode (no grammar needed).
- Dropped: spell checking (jinx: native dependency, more trouble than worth), seforim app, org-roam, citar, latex, web-search, 09-context, 22-nix-system, icons, pulsar, focus, treesit-auto (data-loss bug: it reverts buffers).
- Undecided: eglot-java; whether query-replace needs an anzu-like count.
