;;; ide.el --- programming -*- lexical-binding: t; -*-

(use-package corfu
  :hook (prog-mode . corfu-mode)
  :custom (corfu-cycle t) (corfu-auto t) (corfu-auto-delay 0.2) (corfu-auto-prefix 2))

(use-package eglot
  :hook ((python-mode rust-mode nix-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-send-changes-idle-time 0.5)
  (eglot-events-buffer-config '(:size 0))
  :config
  (add-to-list 'eglot-server-programs '(typst-ts-mode . ("tinymist")))
  (add-to-list 'eglot-server-programs '(nix-mode . ("nil"))))

(use-package envrc :hook (after-init . (lambda () (when (executable-find "direnv") (envrc-global-mode 1)))))
(use-package nix-mode :mode "\\.nix\\'")
(use-package rust-mode :mode "\\.rs\\'"
  :custom (rust-format-on-save t))
(use-package cargo :hook (rust-mode . cargo-minor-mode))
(use-package rainbow-delimiters :hook (prog-mode . rainbow-delimiters-mode))
