;;; editing.el --- editing and navigation helpers -*- lexical-binding: t; -*-

(use-package avy
  :bind (("M-j" . avy-goto-char-timer)
         ("M-g j" . avy-goto-line)
         ("M-g w" . avy-goto-word-1))
  :custom (avy-timeout-seconds 0.3) (avy-background t))

(use-package ace-window
  :bind ("M-o" . ace-window)
  :custom (aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l)) (aw-scope 'frame))

(use-package multiple-cursors
  :bind (("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)
         ("C-S-c C-S-c" . mc/edit-lines))
  :custom (mc/list-file (expand-file-name "mc-lists.el" my/state-dir)))

(use-package expand-region :bind ("C-=" . er/expand-region))
(use-package move-text :bind (("M-<up>" . move-text-up) ("M-<down>" . move-text-down)))
(use-package goto-last-change :bind ("C-c ;" . goto-last-change))
(use-package beginend :hook (emacs-startup . beginend-global-mode))
(use-package visual-regexp
  :bind (("C-c q" . vr/query-replace) ("C-c M" . vr/mc-mark)))

(use-package crux
  :bind (("C-a" . crux-move-beginning-of-line)
         ("C-k" . crux-smart-kill-line)
         ("C-S-<return>" . crux-smart-open-line-above)
         ("S-<return>" . crux-smart-open-line)))

;; Undo: vundo shows the undo tree on demand. Nothing runs per command, and
;; there is no history file written on every save (what made undo-tree slow).
(use-package vundo
  :bind ("C-x u" . vundo)
  :custom (vundo-glyph-alist vundo-unicode-symbols))
(keymap-global-set "C-/" #'undo)
(keymap-global-set "C-?" #'undo-redo)

(use-package yasnippet
  :hook ((prog-mode text-mode) . yas-minor-mode)
  :config (yas-reload-all))
(use-package yasnippet-snippets :after yasnippet)

(keymap-global-set "C-c C-d" #'duplicate-dwim)
(add-hook 'prog-mode-hook #'electric-pair-local-mode)

;; Replaces anzu: lazy-count in isearch is built in (core.el); this adds the
;; match count to query-replace is not needed.

(use-package hydra
  :commands defhydra
  :config
  (defhydra hydra-writing (:color blue :hint nil)
    "
Writing:  w: reading room   W: set width"
    ("w" my/toggle-reading-room)
    ("W" olivetti-set-width)
    ("q" nil))
  (defhydra hydra-tabs (:color pink :hint nil)
    "
_n_ new  _x_ close  _]_ next  _[_ prev  _r_ rename  _s_ project → tab
_b_ buffer  _d_ kill buffer  _o_ kill others  _g_ ibuffer  _1_.._9_ jump"
    ("n" tab-bar-new-tab) ("x" tab-bar-close-tab)
    ("]" tab-bar-switch-to-next-tab) ("[" tab-bar-switch-to-prev-tab)
    ("r" tab-bar-rename-tab :color blue)
    ("s" my/project-in-new-tab :color blue)
    ("1" (tab-bar-select-tab 1)) ("2" (tab-bar-select-tab 2))
    ("3" (tab-bar-select-tab 3)) ("4" (tab-bar-select-tab 4))
    ("5" (tab-bar-select-tab 5)) ("6" (tab-bar-select-tab 6))
    ("7" (tab-bar-select-tab 7)) ("8" (tab-bar-select-tab 8))
    ("9" (tab-bar-select-tab 9))
    ("b" consult-buffer :color blue)
    ("d" my/kill-current-buffer) ("o" my/kill-other-buffers)
    ("g" ibuffer :color blue) ("q" nil :color blue)))
;; hydra is lazy, so the keys that open these load it first.
(keymap-global-set "C-c W" (lambda () (interactive) (require 'hydra) (hydra-writing/body)))
(keymap-global-set "C-c T" (lambda () (interactive) (require 'hydra) (hydra-tabs/body)))
