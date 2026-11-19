;;; ide.el --- programming -*- lexical-binding: t; -*-
(defvar my/state-dir)

(add-hook 'prog-mode-hook #'display-line-numbers-mode)

(use-package corfu
  :hook (prog-mode . corfu-mode)
  :custom (corfu-cycle t) (corfu-auto nil)) ; completion only when you press TAB

(use-package eglot
  :hook ((python-mode rust-mode java-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-connect-timeout 120)  ; jdtls takes ~30 s on a cold start
  (eglot-send-changes-idle-time 0.5)
  (eglot-events-buffer-config '(:size 0)))

;; Servers (pyright especially) ask Emacs to watch every file under the project.
;; In a big tree that hits the 10000-watch limit, floods warnings and loops
;; reconnects. Editing does not need it, so decline the request.
;; The cost: a server does not see files changed outside Emacs (a git checkout,
;; a build) until it restarts. `M-x my/eglot-watch-files' turns watching back on
;; for servers started afterwards.
(defun my/eglot-decline-file-watching (orig server method &rest args)
  "Around `eglot-register-capability': refuse workspace/didChangeWatchedFiles."
  (unless (eq method 'workspace/didChangeWatchedFiles)
    (apply orig server method args)))
(defun my/eglot-watch-files ()
  "Let language servers started from now on watch project files again."
  (interactive)
  (advice-remove 'eglot-register-capability #'my/eglot-decline-file-watching))
(with-eval-after-load 'eglot
  (advice-add 'eglot-register-capability :around #'my/eglot-decline-file-watching))

(use-package rust-mode :mode "\\.rs\\'"
  :custom (rust-format-on-save t))
(use-package cargo :hook (rust-mode . cargo-minor-mode))
(use-package rainbow-delimiters :hook (prog-mode . rainbow-delimiters-mode))

;; Snippets: code only, so Org's TAB is left alone.
(use-package yasnippet
  :hook (prog-mode . yas-minor-mode)
  ;; New snippets go to state/, which is writable; configs/ is a store link
  ;; under Nix. yasnippet-snippets adds its own dir after this.
  :init (setq yas-snippet-dirs (list (expand-file-name "snippets" my/state-dir)))
  (make-directory (car yas-snippet-dirs) t)
  ;; Load the snippet tables while idle after startup, so the first code file
  ;; does not stall on them.
  (add-hook 'emacs-startup-hook
            (lambda () (run-with-idle-timer 3 nil (lambda () (require 'yasnippet)))))
  :config (yas-reload-all))
(use-package yasnippet-snippets :after yasnippet)

;; Common Lisp: SLIME talks to sbcl. M-x slime starts it; .lisp files enable slime-mode.
(use-package slime
  :commands (slime slime-connect)
  :init (setq inferior-lisp-program "sbcl")
  :custom (slime-contribs '(slime-fancy))
  :config (setq slime-net-coding-system 'utf-8-unix))

;; Build: C-c c runs a compile command in the project root; errors are clickable.
(keymap-global-set "C-c c" #'project-compile)
(keymap-global-set "C-c C" #'recompile)
;; Jump between diagnostics (Eglot shows them through Flymake).
(with-eval-after-load 'flymake
  (keymap-set flymake-mode-map "M-n" #'flymake-goto-next-error)
  (keymap-set flymake-mode-map "M-p" #'flymake-goto-prev-error))
(add-hook 'sh-mode-hook #'flymake-mode)  ; lint plain shell scripts too
