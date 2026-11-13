;;; export-in-profile.el --- prove the hebrew profile exports to one PDF -*- lexical-binding: t; -*-
;;
;; Run with the hebrew profile loaded:
;;
;;   emacs -Q --batch -l configs/hebrew/early-init.el \
;;                  -l configs/hebrew/init.el -l test/export-in-profile.el
;;
;; What is checked is the shape of the result, not the existence of a function:
;;   1. the stock export command (the one the C-c C-e menu calls) works,
;;   2. a PDF appears beside the source file,
;;   3. no .typ file is left anywhere — not beside the source, not in tmp,
;;   4. the temporary directory the exporter used is gone.
;;
;; Any failure is fatal. A test that warns and continues is not a test.

(require 'subr-x)

(defvar my/export-test--failures nil)

(defun my/export-test-fail (fmt &rest args)
  (push (apply #'format fmt args) my/export-test--failures))

(defun my/export-test--typ-files (dir)
  "Every .typ file at or under DIR."
  (directory-files-recursively dir "\\.typ\\'"))

(defun my/export-test--temp-dirs ()
  "The exporter's temporary working directories."
  (directory-files temporary-file-directory t "\\`org-typst-"))

(let* ((root (file-name-directory (directory-file-name
                                   (file-name-directory load-file-name))))
       (fixture (expand-file-name "test/export/fixtures/03-footnotes.org" root))
       (work (make-temp-file "my-export-test-" t))
       (src (expand-file-name "sample.org" work))
       (pdf (expand-file-name "sample.pdf" work))
       (temps-before (my/export-test--temp-dirs)))
  (unwind-protect
      (progn
        (unless (file-readable-p fixture)
          (my/export-test-fail "fixture missing: %s" fixture))
        (when (file-readable-p fixture)
          (copy-file fixture src t)

          ;; The redirect must be in place *after* ox-typst loads, not merely
          ;; promised before it: `with-eval-after-load' fires on first use.
          (with-current-buffer (find-file-noselect src)
            (condition-case err
                (progn
                  ;; The exporter announces the PDF to the echo area, which is
                  ;; right interactively and noise in a check.
                  (let ((inhibit-message t))
                    (org-typst-export-to-pdf))
                  (unless (file-exists-p pdf)
                    (my/export-test-fail "no PDF beside the source: %s" pdf))
                  (let ((stragglers (my/export-test--typ-files work)))
                    (when stragglers
                      (my/export-test-fail "left .typ behind: %s"
                                           (string-join stragglers ", "))))
                  (let ((temps (seq-difference (my/export-test--temp-dirs)
                                               temps-before)))
                    (when temps
                      (my/export-test-fail "left a temp directory: %s"
                                           (string-join temps ", ")))))
              (error
               (my/export-test-fail "export signalled: %S" err)))
            (set-buffer-modified-p nil)
            (kill-buffer))))

    (delete-directory work t)
    ;; A fixture that failed early still must not poison the next run.
    (dolist (dir (seq-difference (my/export-test--temp-dirs) temps-before))
      (ignore-errors (delete-directory dir t))))

  (if my/export-test--failures
      (progn
        (dolist (line (nreverse my/export-test--failures))
          (princ (concat "FAIL export: " line "\n") #'external-debugging-output))
        (kill-emacs 1))
    (princ "ok   export in profile: PDF beside the source, no .typ, temp cleaned\n"
           #'external-debugging-output)))
