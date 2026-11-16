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

(use-package envrc :hook (after-init . (lambda () (when (executable-find "direnv") (envrc-global-mode 1)))))
(use-package nix-mode :mode "\\.nix\\'")
(use-package rust-mode :mode "\\.rs\\'"
  :custom (rust-format-on-save t))
(use-package cargo :hook (rust-mode . cargo-minor-mode))
(use-package rainbow-delimiters :hook (prog-mode . rainbow-delimiters-mode))

(use-package typst-ts-mode
  :mode "\\.typ\\'"
  :hook (typst-ts-mode . electric-pair-local-mode))
(defun my/typst-compile ()
  (interactive)
  (compile (format "typst compile %s" (shell-quote-argument buffer-file-name))))
(defun my/typst-watch ()
  (interactive)
  (async-shell-command (format "typst watch %s" (shell-quote-argument buffer-file-name))))
(defun my/typst-view ()
  (interactive)
  (let ((pdf (concat (file-name-sans-extension buffer-file-name) ".pdf")))
    (if (file-exists-p pdf) (find-file-other-window pdf) (message "PDF not found"))))

;; Shell panel, bottom side window.
(defvar my/terminal-height 0.32)
(defun my/terminal--shells ()
  (delq nil
        (list (let ((ps (or (executable-find "pwsh") (executable-find "powershell"))))
                (and ps (cons "PowerShell" ps)))
              (let ((nu (executable-find "nu"))) (and nu (cons "Nushell" nu)))
              (let ((b (executable-find "bash"))) (and b (cons "Bash" b))))))
(defun my/new-terminal (&optional pick)
  "New shell buffer; with PICK, choose the shell."
  (interactive "P")
  (let* ((shells (my/terminal--shells))
         (choice (if (and pick (cdr shells))
                     (assoc (completing-read "Shell: " (mapcar #'car shells) nil t) shells)
                   (car shells))))
    (unless choice (user-error "No shell found"))
    (let ((explicit-shell-file-name (cdr choice)) (shell-file-name (cdr choice)))
      (shell (generate-new-buffer-name (format "*term:%s*" (car choice)))))))
(defun my/toggle-terminal ()
  (interactive)
  (let* ((buf (seq-find (lambda (b) (with-current-buffer b (derived-mode-p 'shell-mode)))
                        (buffer-list)))
         (win (and buf (get-buffer-window buf))))
    (cond (win (delete-window win))
          (buf (select-window (display-buffer-in-side-window
                               buf `((side . bottom) (window-height . ,my/terminal-height)))))
          (t (let ((display-buffer-alist
                    `(("\\*term:" (display-buffer-in-side-window)
                       (side . bottom) (window-height . ,my/terminal-height)))))
               (my/new-terminal))))))
(keymap-global-set "C-`" #'my/toggle-terminal)
(keymap-global-set "C-c t t" #'my/toggle-terminal)
(keymap-global-set "C-c t n" #'my/new-terminal)
(keymap-global-set "C-c t N" (lambda () (interactive) (my/new-terminal t)))
