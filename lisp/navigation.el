;;; navigation.el --- windows, tabs, buffers, files -*- lexical-binding: t; -*-

(setq tab-bar-show 0
      tab-bar-new-tab-choice "*scratch*"
      dired-listing-switches "-al --group-directories-first"
      dired-dwim-target t)

(keymap-global-set "C-<tab>" #'tab-bar-switch-to-next-tab)
(keymap-global-set "C-S-<tab>" #'tab-bar-switch-to-prev-tab)
(keymap-global-set "C-x t n" #'tab-bar-new-tab)
(keymap-global-set "C-x t k" #'tab-bar-close-tab)
(keymap-global-set "C-x t r" #'tab-bar-rename-tab)

(defun my/kill-current-buffer () (interactive) (kill-buffer (current-buffer)))
(defun my/kill-other-buffers ()
  "Kill every file-visiting buffer but this one."
  (interactive)
  (dolist (b (buffer-list))
    (when (and (not (eq b (current-buffer))) (buffer-file-name b))
      (kill-buffer b))))
(defun my/revert-buffer () (interactive) (revert-buffer t t))
(defun my/split-below-and-follow () (interactive) (select-window (split-window-below)))
(defun my/split-right-and-follow () (interactive) (select-window (split-window-right)))
(defun my/project-in-new-tab ()
  (interactive)
  (tab-bar-new-tab)
  (call-interactively #'project-switch-project))

(keymap-global-set "C-x K" #'my/kill-current-buffer)
(keymap-global-set "C-c k" #'my/kill-other-buffers)
(keymap-global-set "C-c R" #'my/revert-buffer)
(keymap-global-set "C-x 2" #'my/split-below-and-follow)
(keymap-global-set "C-x 3" #'my/split-right-and-follow)

(use-package ibuffer
  :bind ("C-x C-b" . ibuffer)
  :custom
  (ibuffer-saved-filter-groups
   '(("default"
      ("Org" (mode . org-mode))
      ("Code" (derived-mode . prog-mode))
      ("Dired" (mode . dired-mode))
      ("Magit" (name . "\\`magit"))
      ("Emacs" (name . "\\`\\*")))))
  :hook (ibuffer-mode . (lambda () (ibuffer-switch-to-saved-filter-groups "default"))))

(use-package activities
  :commands (activities-new activities-define activities-resume activities-suspend
             activities-kill activities-switch activities-switch-buffer
             activities-revert activities-list)
  :init
  (keymap-global-set "C-x C-a C-n" #'activities-new)
  (keymap-global-set "C-x C-a C-d" #'activities-define)
  (keymap-global-set "C-x C-a C-a" #'activities-resume)
  (keymap-global-set "C-x C-a C-s" #'activities-suspend)
  (keymap-global-set "C-x C-a C-k" #'activities-kill)
  (keymap-global-set "C-x C-a RET" #'activities-switch)
  (keymap-global-set "C-x C-a b" #'activities-switch-buffer)
  (keymap-global-set "C-x C-a g" #'activities-revert)
  (keymap-global-set "C-x C-a l" #'activities-list)
  :config
  (activities-mode 1)
  (activities-tabs-mode 1))

(use-package dirvish
  :bind (("C-x d" . dirvish) ("<f8>" . dirvish-side))
  :custom
  (dirvish-attributes '(file-size))   ; no icons: they cost per-file work
  (dirvish-quick-access-entries
   '(("h" "~/" "Home") ("d" "~/Documents/" "Documents") ("D" "~/Downloads/" "Downloads"))))
