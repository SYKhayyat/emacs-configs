;;; early-init.el --- hebrew profile -*- lexical-binding: t; -*-
(defvar my/profile 'hebrew)
(defvar my/repo-root (expand-file-name "../.." (file-name-directory load-file-name)))
(load (expand-file-name "lisp/early.el" my/repo-root) nil 'nomessage)
