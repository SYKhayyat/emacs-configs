;;; typst.el --- Typst editing and quick compile helpers -*- lexical-binding: t; -*-
;; (Export from org is in export.el.)

(use-package typst-ts-mode
  :mode "\\.typ\\'"
  :hook (typst-ts-mode . electric-pair-local-mode))
(defun my/typst-compile ()
  "Compile this Typst file once."
  (interactive)
  (compile (format "typst compile %s" (shell-quote-argument buffer-file-name))))
(defun my/typst-watch ()
  "Recompile this Typst file on every change."
  (interactive)
  (async-shell-command (format "typst watch %s" (shell-quote-argument buffer-file-name))))
(defun my/typst-view ()
  "Open the PDF beside this Typst file."
  (interactive)
  (let ((pdf (concat (file-name-sans-extension buffer-file-name) ".pdf")))
    (if (file-exists-p pdf) (find-file-other-window pdf) (message "PDF not found"))))
