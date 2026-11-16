;;; terminal.el --- shell panel in a bottom side window -*- lexical-binding: t; -*-

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
    ;; shell.el defvars explicit-shell-file-name; bind it only once it is special,
    ;; or the let below is lexical and shell.el's defvar then signals.
    (require 'shell)
    (let ((explicit-shell-file-name (cdr choice)) (shell-file-name (cdr choice)))
      (shell (generate-new-buffer-name (format "*term:%s*" (car choice)))))))
(defun my/toggle-terminal ()
  "Show, hide or start the bottom shell panel."
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
