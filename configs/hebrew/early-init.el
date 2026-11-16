;;; early-init.el --- profile entry -*- lexical-binding: t; -*-
(defvar my/config-dir (file-name-directory (or load-file-name buffer-file-name)))
(defvar my/repo-root (expand-file-name "../.." my/config-dir))
(defvar my/profile (intern (file-name-nondirectory (directory-file-name my/config-dir))))
(load (expand-file-name "lisp/early.el" my/repo-root) nil 'nomessage)
