;;; early-init.el --- notes profile -*- lexical-binding: t; -*-
(defvar my/profile 'notes)
(load (expand-file-name "lisp/early.el" (or (getenv "EMACS_CONFIG_ROOT") (expand-file-name "../.." (file-name-directory load-file-name)))) nil 'nomessage)
