;;; vcs.el --- git and project navigation -*- lexical-binding: t; -*-

(use-package magit
  :bind (("C-x g" . magit-status) ("C-x M-g" . magit-dispatch) ("C-c v g" . magit-status)))
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode) (dired-mode . diff-hl-dired-mode)))
(use-package git-timemachine :bind ("C-c v t" . git-timemachine))

;; Projects: built-in project.el on C-x p. Folders with a "Bavli" file count as roots
;; even without git. A project is remembered the first time you visit a file in
;; it (project.el's default); nothing scans ~/Documents.
(use-package project
  :custom
  (project-vc-extra-root-markers '("Bavli" ".project")))
