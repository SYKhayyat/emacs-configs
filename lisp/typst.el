;;; typst.el --- Typst editing and quick compile helpers -*- lexical-binding: t; -*-
;; (Export from org is in export.el.)

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
