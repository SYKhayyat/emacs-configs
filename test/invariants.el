;;; invariants.el --- prove the agreed settings actually took effect -*- lexical-binding: t; -*-
;; Run: bin/check.sh   (it loads a profile, then this file)
;;
;; Every line here is something that was decided and measured in stage 1. The
;; point is that a setting can be *written* in the .org and still not be in
;; effect — overridden by a profile, shadowed by a package, or lost to a typo.
;; This file is the difference between "we set it" and "it is set".

(require 'cl-lib)

;; A batch run does not fire `emacs-startup-hook', so the two deferred steps are
;; invoked explicitly before anything is checked.
(my/restore-after-init)
(my/start-idle-modes)

(defconst inv/expected
  `((sentence-end-double-space . nil)     ; C1
    (use-short-answers . t)               ; C3
    (delete-by-moving-to-trash . t)       ; C4
    (use-dialog-box . nil)                ; C5
    (use-file-dialog . nil)               ; C5
    (scroll-conservatively . 101)         ; C6
    (scroll-preserve-screen-position . t) ; C7
    (auto-save-no-message . t)            ; C9
    (enable-recursive-minibuffers . t)    ; C11
    (save-interprogram-paste-before-kill . t) ; C12
    (vc-follow-symlinks . nil)            ; C14
    (create-lockfiles . nil)              ; A5
    (make-backup-files . nil)             ; A5
    (auto-save-default . t)               ; A5
    (vc-handled-backends . (Git))         ; A6
    (read-process-output-max . 1048576)   ; A7
    (gc-cons-percentage . 0.1)            ; A1, restored
    (bidi-paragraph-direction . left-to-right) ; A11
    (package-directory-list . nil))       ; determinism
  "Settings that stage 1 agreed on, as (variable . expected default value).")

(defun inv/value (var)
  "The value that a new buffer would see for VAR."
  (cond ((null (boundp var)) 'unbound)
        ((eq var 'bidi-paragraph-direction) (default-value var))
        (t (default-value var))))

(let ((bad nil))
  (dolist (pair inv/expected)
    (let* ((var (car pair)) (want (cdr pair)) (got (inv/value var)))
      (unless (equal got want)
        (push (format "  %-38s want %S, got %S" var want got) bad))))
  ;; Buffer-local settings need a real buffer.
  (with-temp-buffer
    (dolist (pair '((indent-tabs-mode . nil)      ; C2
                    (require-final-newline . t))) ; C8
      (unless (equal (symbol-value (car pair)) (cdr pair))
        (push (format "  %-38s want %S, got %S"
                      (car pair) (cdr pair) (symbol-value (car pair)))
              bad))))
  ;; Modes started on the idle timer.
  (dolist (pair '((global-so-long-mode . t)    ; A10
                  (delete-selection-mode . t)  ; C13
                  (which-key-mode . t)))       ; B5
    (unless (eq (and (boundp (car pair)) (symbol-value (car pair))) (cdr pair))
      (push (format "  %-38s want %S, got %S"
                    (car pair) (cdr pair) (and (boundp (car pair))
                                               (symbol-value (car pair))))
            bad)))
  ;; Paths must stay inside this checkout.
  (unless (string-prefix-p my/repo-root custom-file)
    (push (format "  custom-file outside the repo: %s" custom-file) bad))
  (unless (string-prefix-p (expand-file-name "elpa" my/repo-root) package-user-dir)
    (push (format "  package-user-dir outside the repo: %s" package-user-dir) bad))
  ;; The crash-recovery list follows user-emacs-directory, which --init-directory
  ;; points at configs/<profile>/ inside the checkout. It must be redirected.
  (unless (string-prefix-p (expand-file-name "state" my/repo-root)
                           auto-save-list-file-prefix)
    (push (format "  auto-save-list-file-prefix outside state/: %s"
                  auto-save-list-file-prefix) bad))
  ;; GC is restored to 16 MB, not left at the 32 MB used during init.
  (unless (= gc-cons-threshold (* 16 1024 1024))
    (push (format "  gc-cons-threshold is %d, want 16777216" gc-cons-threshold) bad))
  (if bad
      (progn
        (princ (format "FAIL %s (%d)\n%s\n" my/profile (length bad)
                       (mapconcat #'identity (nreverse bad) "\n")))
        (kill-emacs 1))
    (princ (format "ok   %s (%d invariants)\n" my/profile (length inv/expected)))))
