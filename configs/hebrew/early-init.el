;;; early-init.el --- hebrew profile -*- lexical-binding: t; -*-
(defvar my/profile 'hebrew)
(load (expand-file-name "lisp/early.el" (or (getenv "EMACS_CONFIG_ROOT") (expand-file-name "../.." (file-name-directory load-file-name)))) nil 'nomessage)
