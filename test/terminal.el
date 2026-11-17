;;; terminal.el --- the terminal starts in a fresh Emacs, on your login shell -*- lexical-binding: t; -*-
(let (bad)
  (condition-case err
      (progn
        (my/toggle-terminal)
        (let ((buf (seq-find (lambda (b) (with-current-buffer b (derived-mode-p 'eat-mode)))
                             (buffer-list))))
          (cond
           ((not buf) (push "no eat buffer after my/toggle-terminal" bad))
           ((not (get-buffer-process buf)) (push "no shell process" bad))
           (t (let ((cmd (string-join (process-command (get-buffer-process buf)) " ")))
                ;; eat wraps the shell in /usr/bin/env; the shell is in the command line.
                (unless (string-match-p (regexp-quote (or (getenv "SHELL") "sh")) cmd)
                  (push (format "not the login shell: %s" cmd) bad)))
              (set-process-query-on-exit-flag (get-buffer-process buf) nil)
              (kill-buffer buf)))))
    (error (push (error-message-string err) bad)))
  (if bad (progn (dolist (b bad) (message "FAIL terminal: %s" b)) (kill-emacs 1))
    (message "ok   terminal")))

;; The shell picker lists nushell when it is installed.
(when (executable-find "nu")
  (unless (assoc "Nushell" (my/terminal--shells))
    (message "FAIL terminal: nushell installed but not offered") (kill-emacs 1)))
