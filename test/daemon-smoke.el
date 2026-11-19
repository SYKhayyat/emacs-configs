;;; daemon-smoke.el --- checks only a running daemon can answer -*- lexical-binding: t; -*-
;; Loaded by bin/check through emacsclient into a throwaway daemon. Batch runs
;; cannot see these: a daemon running a stale tree (B1), footnote labels
;; missing until the first command (H2).
(defvar my/profile)
(defvar my/config-stamp)
(defvar my/repo-root)
(defvar my/rtl-footnote-labels)

(defconst my/daemon-smoke-text
  "* כותרת\nטקסט עם הערה.[fn:1]\n\n[fn:1] הערה ראשונה.\n")

(defun my/daemon-smoke ()
  "Return \"ok\", or a string naming each failure."
  (let ((fixture (make-temp-file "daemon-smoke-" nil ".org" my/daemon-smoke-text))
        (fail nil))
    (unwind-protect
        (progn
          (unless (and (boundp 'my/config-stamp)
                       (equal my/config-stamp
                              (file-truename (expand-file-name "lisp" my/repo-root))))
            (push "my/config-stamp missing or wrong" fail))
          (require 'compat)
          (unless (and (fboundp 'set-local)
                       (string-match-p "/elpa/compat-" (or (symbol-file 'set-local) "")))
            (push (format "set-local from %S, not elpa/compat" (symbol-file 'set-local)) fail))
          (let ((buf (find-file-noselect fixture)))
            (with-current-buffer buf
              (unless (derived-mode-p 'org-mode) (push "fixture not in org-mode" fail))
              (when (and (eq my/profile 'hebrew)
                         (not (memq 'my/rtl-footnote-labels-follow post-command-hook)))
                (push "rtl label hook missing" fail)))
            (kill-buffer buf)))
      (delete-file fixture))
    (if fail (string-join (nreverse fail) "; ") "ok")))

(defun my/daemon-smoke-shown (out)
  "Show the fixture in this (new, tty) frame; after a second of redisplay and no
command, write to OUT how many footnote labels it has, then close the frame.
The daemon's own startup frame is never redisplayed, so this needs a client."
  (let ((fixture (make-temp-file "daemon-smoke-" nil ".org" my/daemon-smoke-text)))
    ;; Visit without showing, cut the post-command path (a tty client delivers
    ;; terminal events, which count as commands), then show: only being shown
    ;; can build the labels now.
    (with-current-buffer (find-file-noselect fixture)
      (remove-hook 'post-command-hook #'my/rtl-footnote-labels-follow t))
    (switch-to-buffer (get-file-buffer fixture))
    (let ((buf (current-buffer)))
      (run-with-timer
       1 nil
       (lambda ()
         (with-temp-file out
           (insert (format "%d" (length (buffer-local-value 'my/rtl-footnote-labels buf)))))
         (kill-buffer buf)
         (delete-file fixture)
         (delete-frame))))))
