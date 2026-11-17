;;; packages.el --- the one list of packages the config owns -*- lexical-binding: t; -*-
;; `bin/install' installs whatever is missing from here into elpa/ and records
;; the installed versions in packages.lock. This file is read only by the
;; installer; at run time quickstart activates the autoloads and use-package
;; (no :ensure) configures them lazily.
;;
;; Every profile gets every package (installing everything is cheap and keeps
;; the profiles interchangeable); which profile loads what is decided by its
;; module list, not here.

(defconst my/packages
  '(;; completion (all)
    vertico orderless marginalia consult embark embark-consult wgrep corfu
    ;; editing
    avy ace-window multiple-cursors expand-region move-text goto-last-change
    beginend crux visual-regexp vundo yasnippet yasnippet-snippets
    ;; windows, files
    activities dirvish
    ;; prose (hebrew, notes)
    olivetti org-modern org-download markdown-mode nov
    ;; ide
    magit diff-hl git-timemachine envrc
    nix-mode rust-mode cargo typst-ts-mode rainbow-delimiters
    ;; reading, ai
    pdf-tools gptel)
  "Packages installed into elpa/.")
