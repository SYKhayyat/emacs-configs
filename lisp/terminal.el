;;; terminal.el --- eat terminal in a bottom side window -*- lexical-binding: t; -*-

(defvar my/terminal-height 0.32 "Fraction of the frame the terminal panel takes.")

(use-package eat
  :commands (eat eat-other-window)
  :custom
  ;; Your login shell, not whatever `shell-file-name' happens to be.
  (eat-shell (or (getenv "SHELL") shell-file-name))
  :init
  ;; Every eat buffer opens in the bottom panel.
  (add-to-list 'display-buffer-alist
               `("\\`\\*eat"
                 (display-buffer-in-side-window)
                 (side . bottom) (window-height . ,my/terminal-height))))

(defun my/terminal--shells ()
  "Alist of (NAME . PROGRAM) for the shells found: login shell first."
  (let (out)
    (dolist (c `(("login shell" . ,(or (getenv "SHELL") shell-file-name))
                 ("Nushell" . "nu") ("Bash" . "bash")))
      (when-let* ((exe (executable-find (cdr c))))
        (unless (rassoc exe out) (push (cons (car c) exe) out))))
    (nreverse out)))

(defun my/new-terminal (&optional pick)
  "Start another terminal in the bottom panel; with PICK, choose the shell."
  (interactive "P")
  (require 'eat)
  (let* ((shells (my/terminal--shells))
         (choice (if pick
                     (assoc (completing-read "Shell: " (mapcar #'car shells) nil t) shells)
                   (car shells))))
    (select-window (get-buffer-window (eat (cdr choice) t)))))

(defun my/toggle-terminal ()
  "Show, hide or start the bottom terminal panel."
  (interactive)
  (require 'eat)
  (let* ((buf (seq-find (lambda (b) (with-current-buffer b (derived-mode-p 'eat-mode)))
                        (buffer-list)))
         (win (and buf (get-buffer-window buf))))
    (cond (win (delete-window win))
          (buf (select-window (display-buffer buf)))
          (t (select-window (get-buffer-window (eat)))))))

(keymap-global-set "C-`" #'my/toggle-terminal)
(keymap-global-set "C-c t t" #'my/toggle-terminal)
(keymap-global-set "C-c t n" #'my/new-terminal)
(keymap-global-set "C-c t N" (lambda () (interactive) (my/new-terminal t)))
