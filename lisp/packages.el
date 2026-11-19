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
  '(;; forwards compatibility. corfu, vertico and consult declare
    ;; `(compat "31")' and call `set-local', `incf', `decf' and
    ;; `completion-list-candidate-at-point' from it; Emacs 31 is not the Emacs
    ;; here, and the compat.el Emacs itself ships is a stub. See core.el.
    compat
    ;; completion (all)
    vertico orderless marginalia consult embark embark-consult wgrep corfu
    ;; editing
    avy ace-window multiple-cursors expand-region move-text goto-last-change
    beginend crux visual-regexp vundo yasnippet yasnippet-snippets
    ;; windows, files
    activities dirvish
    ;; prose (hebrew, notes)
    olivetti org-modern org-download markdown-mode
    ;; ide
    magit diff-hl git-timemachine
    rust-mode cargo rainbow-delimiters slime
    ;; terminal, ai
    eat
    gptel
    exec-path-from-shell)
  "Packages installed into elpa/.")
