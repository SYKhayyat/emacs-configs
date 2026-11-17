;;; ide.el --- programming -*- lexical-binding: t; -*-

(use-package corfu
  :hook (prog-mode . corfu-mode)
  :custom (corfu-cycle t) (corfu-auto nil)) ; completion only when you press TAB

(use-package eglot
  :hook ((python-mode rust-mode typst-ts-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-send-changes-idle-time 0.5)
  (eglot-events-buffer-config '(:size 0))
  :config
  (add-to-list 'eglot-server-programs '(typst-ts-mode . ("tinymist"))))

(use-package rust-mode :mode "\\.rs\\'"
  :custom (rust-format-on-save t))
(use-package cargo :hook (rust-mode . cargo-minor-mode))
(use-package rainbow-delimiters :hook (prog-mode . rainbow-delimiters-mode))

;; Snippets: code only, so Org's TAB is left alone.
(use-package yasnippet
  :hook (prog-mode . yas-minor-mode)
  :config (yas-reload-all))
(use-package yasnippet-snippets :after yasnippet)
