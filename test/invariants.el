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
    (gc-cons-percentage . 0.2) (gc-cons-threshold . 67108864)
    (auto-revert-verbose . nil) (kill-ring-max . 60) (bidi-paragraph-direction . nil)
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
  ;; The C-f remap is Hebrew machinery: hebrew only.
  (when (eq my/profile 'hebrew)
    (unless (eq (key-binding [remap forward-char]) 'right-char)
      (push "forward-char is not remapped to right-char" bad)))
  ;; The startup-hook modes are really on (the tests load modules with -l, so the
  ;; hook has not run by itself).
  (run-hooks 'emacs-startup-hook)
  (dolist (m '(savehist-mode recentf-mode save-place-mode winner-mode which-key-mode
               repeat-mode global-auto-revert-mode))
    (unless (and (boundp m) (symbol-value m)) (push (format "%s is off after startup" m) bad)))
  ;; Only the hebrew profile carries the Hebrew machinery.
  (when (and (eq my/profile 'notes) (fboundp 'my/hebrew-niqqud-regexp))
    (push "notes loads search-hebrew" bad))
  (if bad
      (progn (dolist (b bad) (message "FAIL %s" b)) (kill-emacs 1))
    (message "ok   invariants (%s)" my/profile)))
