;;; ide.el --- programming -*- lexical-binding: t; -*-

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

(use-package rust-mode :mode "\\.rs\\'"
  :custom (rust-format-on-save t))
(use-package cargo :hook (rust-mode . cargo-minor-mode))
(use-package rainbow-delimiters :hook (prog-mode . rainbow-delimiters-mode))

;; Snippets: code only, so Org's TAB is left alone.
(use-package yasnippet
  :hook (prog-mode . yas-minor-mode)
  :config (yas-reload-all))
(use-package yasnippet-snippets :after yasnippet)

;; Common Lisp: SLIME talks to sbcl. M-x slime starts it; .lisp files enable slime-mode.
(use-package slime
  :commands (slime slime-connect)
  :init (setq inferior-lisp-program "sbcl")
  :custom (slime-contribs '(slime-fancy))
  :config (setq slime-net-coding-system 'utf-8-unix))
