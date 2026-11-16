;;; packages.el --- the one list of packages the config owns -*- lexical-binding: t; -*-
;; `bin/install' installs whatever is missing from here into elpa/ and records
;; the installed versions in packages.lock. This file is read only by the
;; installer; at run time quickstart activates the autoloads and use-package
;; (no :ensure) configures them lazily.
;;
;; Tag after a name = the profiles that use it; no tag = all. It is only
;; documentation, installing everything everywhere is cheap and keeps the
;; three profiles interchangeable.

(defconst my/packages
  '(;; completion (all)
    vertico orderless marginalia consult embark embark-consult wgrep corfu
    ;; editing
    avy ace-window multiple-cursors expand-region move-text goto-last-change
    beginend crux visual-regexp vundo yasnippet yasnippet-snippets
    ;; help, keys
    helpful hydra
    ;; windows, files
    activities dirvish
    ;; prose (hebrew, notes)
    olivetti valign org-modern org-download jinx markdown-mode nov
    ;; ide
    magit diff-hl git-timemachine projectile consult-projectile envrc
    nix-mode rust-mode cargo typst-ts-mode rainbow-delimiters
    ;; reading, ai
    pdf-tools gptel)
  "Packages installed into elpa/.")
