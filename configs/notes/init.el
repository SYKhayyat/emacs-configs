;;; init.el --- notes profile: a list of shared modules -*- lexical-binding: t; -*-
(dolist (m '(core files ui completion editing navigation prose footnotes rtl export reading))
  (load (expand-file-name (format "lisp/%s.el" m) my/repo-root) nil 'nomessage))
