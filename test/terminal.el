;;; terminal.el --- the first terminal starts in a fresh Emacs -*- lexical-binding: t; -*-
(let (bad)
  (condition-case err
      (let ((buf (my/new-terminal)))
        (unless (and (buffer-live-p buf) (get-buffer-process buf)) (push "no shell process" bad))
        (when (buffer-live-p buf)
          (when-let* ((p (get-buffer-process buf))) (set-process-query-on-exit-flag p nil))
          (kill-buffer buf)))
    (user-error (message "skip terminal: %s" (cadr err)))
    (error (push (error-message-string err) bad)))
  (if bad (progn (dolist (b bad) (message "FAIL terminal: %s" b)) (kill-emacs 1))
    (message "ok   terminal")))
