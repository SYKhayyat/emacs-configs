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
    ;; A11: no direction is forced, in any profile. This used to be an
    ;; expectation of `left-to-right' here and nil in hebrew, which is how the
    ;; RTL fix went missing: the base forced LTR and nothing overrode it.
    (bidi-paragraph-direction . nil)
    (word-wrap . t)                       ; C15
    ;; Both prose profiles number every heading level; see base/export.org.
    (org-export-headline-levels . 10)
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
  ;; Wrapping is a mode, not a variable: entering a text buffer must leave it
  ;; wrapped, not merely have a default set somewhere. org derives from
  ;; text-mode, so this is also the org path — checked here without loading org.
  (with-temp-buffer
    (text-mode)
    (unless (and visual-line-mode (null truncate-lines))
      (push (format "  a text-mode buffer is not wrapped: visual-line-mode %S, truncate-lines %S"
                    visual-line-mode truncate-lines)
            bad)))
  ;; Modes started on the idle timer.
  (dolist (pair '((global-so-long-mode . t)    ; A10
                  (delete-selection-mode . t)  ; C13
                  (which-key-mode . t)))       ; B5
    (unless (eq (and (boundp (car pair)) (symbol-value (car pair))) (cdr pair))
      (push (format "  %-38s want %S, got %S"
                    (car pair) (cdr pair) (and (boundp (car pair))
                                               (symbol-value (car pair))))
            bad)))
  ;; Footnote policy is base policy now: both prose profiles promise that a new
  ;; note lands in a "* Footnotes" section after everything else, and that no
  ;; inline definition is created. Checked, not assumed, and checked in every
  ;; profile that carries the base — the hebrew and notes modules that used to
  ;; own it are gone.
  (require 'org)
  (let ((where (with-temp-buffer
                 (insert "* heading\nsome text with a note")
                 (org-mode)
                 (goto-char (point-max))
                 ;; org announces where it put point; a check must be silent.
                 (let ((inhibit-message t)) (org-footnote-action))
                 (buffer-string))))
    (unless (string-match-p "\\(?:^\\|\\n\\)\\* Footnotes\\s-*$" where)
      (push (format "  a new footnote did not land in a bottom Footnotes section: %S"
                    where)
            bad)))
  (unless (eq (default-value 'org-footnote-define-inline) nil)
    (push (format "  %-38s want nil, got %S"
                  'org-footnote-define-inline
                  (default-value 'org-footnote-define-inline))
          bad))
  ;; The export language is the profile's own: Hebrew documents are handed to
  ;; Typst right-to-left, English ones are not.
  (when (memq my/profile '(hebrew notes))
    (let ((want (if (eq my/profile 'hebrew) "he" "en")))
      (unless (equal (and (boundp 'org-export-default-language)
                          (default-value 'org-export-default-language))
                     want)
        (push (format "  org-export-default-language is %S, want %S"
                      (and (boundp 'org-export-default-language)
                           (default-value 'org-export-default-language))
                      want)
              bad))))
  (when (eq my/profile 'hebrew)
    ;; The RTL fix and the reading room are the two things this profile adds to
    ;; the shared base; each is checked as reached, not as written.
    (unless (fboundp 'olivetti-mode)
      (push "  olivetti-mode is not autoloaded: vendor/olivetti is missing or unread" bad))
    ;; A footnote definition starts with a Latin label, so with the base's nil
    ;; direction it is laid out left-to-right; the profile's overlays are what
    ;; make it right-to-left. Both halves are asserted: the plain buffer is LTR
    ;; (so this is not a check that passes on any text), and the fixed one is
    ;; RTL (so a broken overlay fails here instead of in a sefer).
    (let ((definition (concat "[fn:1] " "אז, קנינה יהיה או שמסתמא תבוא לה ראשון"
                              " ואולי בצירוף שלה ניתן.\n")))
      (with-temp-buffer
        (insert definition)
        (org-mode)
        (goto-char (point-min))
        (unless (eq (current-bidi-paragraph-direction) 'left-to-right)
          (push (format "  a bare footnote definition is %S, so the check below proves nothing"
                        (current-bidi-paragraph-direction))
                bad))
        (my/rtl-footnote-labels (point-min) (point-max))
        (goto-char (point-min))
        (unless (eq (current-bidi-paragraph-direction) 'right-to-left)
          (push (format "  a footnote definition is %S with the overlays in place"
                        (current-bidi-paragraph-direction))
                bad))))
    (unless (eq (key-binding (kbd "C-c w")) #'my/toggle-reading-room)
      (push (format "  C-c w is %S, not the reading room"
                    (key-binding (kbd "C-c w")))
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
  ;; Load order is a file, so anything not in that file never loads — silently.
  ;; A profile MANIFEST at the profile root is worse: it is not read at all.
  ;; Both were true here once, and the only symptom was a setting that was
  ;; written and not in effect, which is exactly what this file exists to catch.
  (let ((profile-manifest (expand-file-name "MANIFEST" my/config-dir)))
    (when (file-exists-p profile-manifest)
      (push (format "  %s exists but is never read; the loader reads modules/MANIFEST"
                    profile-manifest)
            bad)))
  (dolist (dir (list (expand-file-name "modules" my/config-dir)
                     (expand-file-name "base" my/repo-root)))
    (let ((manifest (expand-file-name "MANIFEST" dir))
          ;; Loaded by other means, and named here so the exception is visible
          ;; rather than implied by a missing check:
          ;;   early-init.el  the bootstrap loads it before the loader exists
          ;;   loader.el      the bootstrap loads it, it is the loader
          ;;   bench.el       only when MY_BENCH is set
          (not-in-manifest '("early-init.el" "loader.el" "bench.el")))
      (dolist (el (directory-files dir t "\\.el\\'"))
        (unless (or (member (file-name-nondirectory el) not-in-manifest)
                    (with-temp-buffer
                      (insert-file-contents manifest)
                      (goto-char (point-min))
                      (re-search-forward
                       (concat "^" (regexp-quote (file-name-nondirectory el)) "$") nil t)))
          (push (format "  %s is not listed in %s, so it never loads"
                        (file-name-nondirectory el) manifest)
                bad)))))
  (if bad
      (progn
        (princ (format "FAIL %s (%d)\n%s\n" my/profile (length bad)
                       (mapconcat #'identity (nreverse bad) "\n")))
        (kill-emacs 1))
    (princ (format "ok   %s (%d invariants)\n" my/profile (length inv/expected)))))
