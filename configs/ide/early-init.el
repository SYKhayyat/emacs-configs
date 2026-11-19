;;; early-init.el --- ide profile -*- lexical-binding: t; -*-
(defvar my/profile 'ide)
;; EMACS_CONFIG_ROOT first: `load' resolves symlinks, so a tree built out of
;; links into the store would derive ../.. as the store path, which is read-only
;; and has no elpa/ or state/. The Nix wrapper sets it; a plain checkout does
;; not need it.
(defvar my/repo-root
  (or (getenv "EMACS_CONFIG_ROOT")
      (expand-file-name "../.." (file-name-directory load-file-name))))
(load (expand-file-name "lisp/early.el" my/repo-root) nil 'nomessage)
