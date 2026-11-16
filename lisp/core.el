;;; core.el --- settings every profile shares -*- lexical-binding: t; -*-
(defvar my/state-dir)

(defun my/restore-after-init ()
  "Undo the temporary GC and file-handler settings from early.el."
  (setq gc-cons-threshold (* 16 1024 1024)
        gc-cons-percentage 0.1)
  ;; Merge, don't overwrite: handlers registered during init (TRAMP) survive.
  (setq file-name-handler-alist
        (delete-dups (append file-name-handler-alist my/file-name-handler-alist))))
(add-hook 'emacs-startup-hook #'my/restore-after-init)

(setq vc-handled-backends '(Git)
      read-process-output-max (* 1024 1024))

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(setq-default buffer-file-coding-system 'utf-8-unix)

;; custom.el lives in the state dir. A corrupt one (Emacs writes it, so a crash
;; can leave it half-written) must not stop Emacs from starting.
(setq custom-file (expand-file-name "custom.el" my/state-dir))
(condition-case err
    (load custom-file 'noerror 'nomessage)
  (error (message "custom-file ignored (%s): %s"
                  (error-message-string err) custom-file)))

;; No forced paragraph direction: forcing one that does not match the text costs
;; 10-50x on wrapped Hebrew (measured, see DECISIONS.md).
(setq-default bidi-paragraph-direction nil)

(setq sentence-end-double-space nil
      use-short-answers t
      delete-by-moving-to-trash t
      use-dialog-box nil
      use-file-dialog nil
      scroll-conservatively 101
      scroll-preserve-screen-position t
      auto-save-no-message t
      ring-bell-function #'ignore
      enable-recursive-minibuffers t
      save-interprogram-paste-before-kill t
      vc-follow-symlinks nil
      isearch-lazy-count t
      undo-limit (* 80 1024 1024)
      undo-strong-limit (* 120 1024 1024)
      undo-outer-limit (* 300 1024 1024)
      large-file-warning-threshold (* 100 1024 1024)
      recentf-max-saved-items 200
      savehist-file (expand-file-name "savehist.el" my/state-dir)
      recentf-save-file (expand-file-name "recentf.el" my/state-dir)
      save-place-file (expand-file-name "places.el" my/state-dir)
      bookmark-default-file (expand-file-name "bookmarks.el" my/state-dir)
      project-list-file (expand-file-name "projects.el" my/state-dir)
      tramp-persistency-file-name (expand-file-name "tramp.el" my/state-dir)
      transient-history-file (expand-file-name "transient-history.el" my/state-dir)
      eshell-directory-name (expand-file-name "eshell/" my/state-dir)
      url-configuration-directory (expand-file-name "url/" my/state-dir))
(setq-default indent-tabs-mode nil
              require-final-newline t
              word-wrap t)

(add-hook 'text-mode-hook #'visual-line-mode)

;; Built-in features that replace packages we do not need, all cheap. On after
;; init so the first frame is not waiting for them.
(add-hook 'emacs-startup-hook
          (lambda ()
            (savehist-mode 1)
            (recentf-mode 1)
            (save-place-mode 1)
            (repeat-mode 1)
            (delete-selection-mode 1)
            (global-so-long-mode 1)
            (global-auto-revert-mode 1)
            (editorconfig-mode 1)
            (which-key-mode 1)
            (winner-mode 1)))

(setq which-key-idle-delay 0.5)
(keymap-global-set "C-c <left>" #'winner-undo)
(keymap-global-set "C-c <right>" #'winner-redo)
