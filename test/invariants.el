;;; invariants.el --- the decided settings are actually in effect -*- lexical-binding: t; -*-
;; Run through bin/check, which loads a profile first.
(require 'cl-lib)
(my/restore-after-init)

(defconst inv/expected
  '((sentence-end-double-space . nil) (use-short-answers . t)
    (delete-by-moving-to-trash . t) (use-dialog-box . nil)
    (scroll-conservatively . 101) (enable-recursive-minibuffers . t)
    (vc-follow-symlinks . nil) (create-lockfiles . nil) (make-backup-files . nil)
    (vc-handled-backends . (Git)) (read-process-output-max . 1048576)
    (gc-cons-percentage . 0.1) (bidi-paragraph-direction . nil)
    (word-wrap . t) (indent-tabs-mode . nil) (package-directory-list . nil)
    ))

(let (bad)
  (dolist (e inv/expected)
    (unless (equal (default-value (car e)) (cdr e))
      (push (format "%s = %S, want %S" (car e) (default-value (car e)) (cdr e)) bad)))
  (when (memq my/profile '(hebrew notes))
    (unless (equal org-export-headline-levels 10) (push "headline levels not 10" bad)))
  (require 'org)
  (when org-footnote-auto-adjust (push "org-footnote-auto-adjust must be nil" bad))
  ;; C-f remap exists in every profile; hebrew/notes only.
  (when (memq my/profile '(hebrew notes))
    (unless (eq (key-binding [remap forward-char]) 'right-char)
      (push "forward-char is not remapped to right-char" bad)))
  (if bad
      (progn (dolist (b bad) (message "FAIL %s" b)) (kill-emacs 1))
    (message "ok   invariants (%s)" my/profile)))
