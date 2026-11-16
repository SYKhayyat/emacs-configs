;;; vcs.el --- git and project navigation -*- lexical-binding: t; -*-

(use-package magit
  :bind (("C-x g" . magit-status) ("C-x M-g" . magit-dispatch) ("C-c v g" . magit-status)))
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode) (dired-mode . diff-hl-dired-mode)))
(use-package git-timemachine :bind ("C-c v t" . git-timemachine))

(use-package projectile
  :bind-keymap ("C-c p" . projectile-command-map)
  :custom
  (projectile-indexing-method 'alien)
  (projectile-project-search-path '("~/Documents/"))
  (projectile-known-projects-file (expand-file-name "projectile.eld" my/state-dir))
  (projectile-project-root-files-bottom-up '("Bavli" ".projectile" ".git")))
(use-package consult-projectile :after projectile)
