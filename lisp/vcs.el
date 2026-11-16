;;; vcs.el --- git and project navigation -*- lexical-binding: t; -*-

(use-package magit
  :bind (("C-x g" . magit-status) ("C-x M-g" . magit-dispatch) ("C-c v g" . magit-status)))
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode) (dired-mode . diff-hl-dired-mode)))
(use-package git-timemachine :bind ("C-c v t" . git-timemachine))

;; Projects: built-in project.el on C-x p. Folders with a "Bavli" file count as roots
;; even without git; every git repo under ~/Documents is remembered at startup.
(use-package project
  :custom
  (project-vc-extra-root-markers '("Bavli" ".project"))
  :config
  (when (file-directory-p "~/Documents/")
    (project-remember-projects-under "~/Documents/")))
