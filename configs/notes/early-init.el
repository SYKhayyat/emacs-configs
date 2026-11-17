;;; early-init.el --- notes profile -*- lexical-binding: t; -*-
(defvar my/profile 'notes)
(defvar my/repo-root (expand-file-name "../.." (file-name-directory load-file-name)))
(load (expand-file-name "lisp/early.el" my/repo-root) nil 'nomessage)
