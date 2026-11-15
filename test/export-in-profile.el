;;; export-in-profile.el --- prove the hebrew profile exports one RTL PDF -*- lexical-binding: t; -*-
;;
;; Run with the hebrew profile loaded:
;;
;;   emacs -Q --batch -l configs/hebrew/early-init.el \
;;                  -l configs/hebrew/init.el -l test/export-in-profile.el
;;
;; Two claims are checked, both about the shape of the result rather than the
;; existence of a function:
;;
;;   1. exporting leaves exactly one PDF beside the source — no .typ, no
;;      temporary directory, no partial file from a failed run;
;;   2. a Hebrew document is handed to Typst with an explicit direction, because
;;      Typst infers direction from the first strong character and a numbered
;;      heading starts with a Latin digit: without it the heading sits at the
;;      left margin while the Hebrew body sits at the right.
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
  "The exporter's temporary working files in the system temp directory."
  (directory-files temporary-file-directory t "\\`org-typst-"))

(defun my/export-test--with-file (org fn)
  "Call FN in a buffer visiting ORG, then close the buffer without saving."
  (unwind-protect
      (with-current-buffer (find-file-noselect org)
        (funcall fn))
    (let ((buf (get-file-buffer org)))
      (when buf
        (with-current-buffer buf (set-buffer-modified-p nil))
        (kill-buffer buf)))))

(let* ((root (file-name-directory (directory-file-name
                                   (file-name-directory load-file-name))))
       (work (make-temp-file "my-export-test-" t))
       (src (expand-file-name "sample.org" work))
       (pdf (expand-file-name "sample.pdf" work))
       (temps-before (my/export-test--temp-dirs)))
  (unwind-protect
      (progn
        ;; ---- 1. one PDF, nothing else -----------------------------------
        (copy-file (expand-file-name "test/export/fixtures/03-footnotes.org" root) src t)
        (my/export-test--with-file
         src
         (lambda ()
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
              (my/export-test-fail "export signalled: %S" err)))))

        ;; ---- 2. Hebrew is handed over with an explicit direction ---------
        (let ((he (expand-file-name "hebrew.org" work)))
          (copy-file (expand-file-name "test/export/fixtures/08-hebrew-rtl.org" root) he t)
          ;; The fixture names its own language so that the exporter-level check
          ;; (no profile loaded) can exercise the RTL branch. Here the profile's
          ;; default must be the thing that decides, so the keyword is removed:
          ;; otherwise this test would keep passing after the profile setting was
          ;; deleted.
          (with-temp-file he
            (insert (replace-regexp-in-string "^#\\+LANGUAGE:.*\n" ""
                                              (with-temp-buffer
                                                (insert-file-contents he)
                                                (buffer-string)))))
          (my/export-test--with-file
           he
           (lambda ()
             (condition-case err
                 (progn
                   (org-typst-export-as-typst)
                   (with-current-buffer org-typst-export-buffer-name
                     (unless (string-match-p "#set text(lang: \"he\", dir: rtl)"
                                             (buffer-string))
                       (my/export-test-fail
                        "Hebrew export is not told dir: rtl: a numbered heading would sit at the left margin"))))
               (error
                (my/export-test-fail "typst generation signalled: %S" err)))))))

        ;; ---- 3. footnotes come out in reading order, not definition order ---
        ;; typst numbers notes by definition order, so an unsorted definitions
        ;; section yields backwards numbers. The export must stage and
        ;; renumber; the source file must be untouched.
        (let ((oo (expand-file-name "outoforder.org" work)))
          (copy-file (expand-file-name "test/export/fixtures/10-footnotes-out-of-order.org" root) oo t)
          (let ((before (with-temp-buffer (insert-file-contents oo) (buffer-string)))
                (typst nil))
            (my/export-test--with-file
             oo
             (lambda ()
               (condition-case err
                   (progn
                     (my/org-footnotes-in-reference-order)
                     (org-typst-export-as-typst)
                     (setq typst (with-current-buffer org-typst-export-buffer-name
                                   (buffer-string))))
                 (error
                  (my/export-test-fail "order typst signalled: %S" err)))))
            ;; Reference order is fn:2 then fn:1; after ordering the generated
            ;; typst must reference note 1 before note 2, and the footnote
            ;; section must still be there.
            (when typst
              (unless (string-match "#footnote(label(.1.))[^#]*#footnote(label(.2.))" typst)
                (my/export-test-fail "footnotes not in reading order in the generated typst"))
              ;; Ordering must not lose a note: both bodies have to survive it.
              (dolist (note '("הערה ראשונה בסדר הקריאה" "הערה שניה בסדר הקריאה"))
                (unless (string-match-p (regexp-quote note) typst)
                  (my/export-test-fail "note lost while ordering: %S" note))))
            (unless (string= before (with-temp-buffer (insert-file-contents oo) (buffer-string)))
              (my/export-test-fail "ordering rewrote the source file"))))

        ;; ---- 4. deep headings are numbered, and in the TOC ----------------
        ;; Emacs defaults `org-export-headline-levels' to 3, which renders a
        ;; deeper heading but drops its number and its TOC line: the profile
        ;; promises the structure, so a fifth-level heading must arrive
        ;; without `numbering: none' / `outlined: false'. Both markers are
        ;; what ox-typst emits when the export level is short.
        (let ((deep (expand-file-name "deep.org" work)))
          (with-temp-file deep
            (insert (mapconcat (lambda (n) (format "%s H%d\nbody\n"
                                                  (make-string n ?*) n))
                               (number-sequence 1 5) "")))
          (my/export-test--with-file
           deep
           (lambda ()
             (condition-case err
                 (progn
                   (org-typst-export-as-typst)
                   (with-current-buffer org-typst-export-buffer-name
                     (let ((typed (buffer-string)))
                       (dolist (n '(4 5))
                         (unless (string-match-p
                                  (format "#heading(level: %d)\\[H%d\\]" n n) typed)
                           (my/export-test-fail
                            "heading level %d is not numbered/outlined in the export: %S"
                            n (and (string-match (format "#heading(level: %d[^]]*" n)
                                                 typed)
                                   (match-string 0 typed))))))))
               (error
                (my/export-test-fail "deep-heading typst signalled: %S" err))))))

    ;; A fixture that failed early must not poison the next run.
    (dolist (dir (seq-difference (my/export-test--temp-dirs) temps-before))
      (ignore-errors (delete-directory dir t)))
    (delete-directory work t))

  (if my/export-test--failures
      (progn
        (dolist (line (nreverse my/export-test--failures))
          (princ (concat "FAIL export: " line "\n") #'external-debugging-output))
        (kill-emacs 1))
    (princ "ok   export in profile: one RTL PDF beside the source, no strays\n"
           #'external-debugging-output)))
