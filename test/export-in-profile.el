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

;; Not `copy-file': it always copies the mode (its docstring: "always sets the
;; file modes of the output file to match the input file"), and a fixture read
;; out of the pinned tree is 0444 because the store is. A copy at that mode
;; is one this test cannot then rewrite — "Opening output file: Permission
;; denied" — and no argument turns the copying of the bits off.
(defun my/export-test--copy-fixture (from to)
  "Write fixture FROM to TO as a copy the test can save over."
  (with-temp-file to (insert-file-contents from)))

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
        (my/export-test--copy-fixture
         (expand-file-name "test/export/fixtures/03-footnotes.org" root) src)
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

        ;; ---- 2. the profile's language, and with it the direction -------
        ;; Hebrew must reach Typst with dir: rtl — a numbered heading starts
        ;; with a Latin digit, which would otherwise put it at the left margin
        ;; while the text under it sits at the right. English must reach it
        ;; without one.
        (let* ((hebrew-p (eq my/profile 'hebrew))
               (doc (expand-file-name (if hebrew-p "hebrew.org" "english.org") work)))
          (if hebrew-p
              (progn
                (my/export-test--copy-fixture
                 (expand-file-name "test/export/fixtures/08-hebrew-rtl.org" root)
                 doc)
                ;; The fixture names its own language so that the exporter-level
                ;; check (no profile loaded) can exercise the RTL branch. Here
                ;; the profile's default must decide, so the keyword goes:
                ;; otherwise this test would keep passing after the profile
                ;; setting was deleted.
                (with-temp-file doc
                  (insert (replace-regexp-in-string "^#\\+LANGUAGE:.*\n" ""
                                                    (with-temp-buffer
                                                      (insert-file-contents doc)
                                                      (buffer-string))))))
            (with-temp-file doc
              (insert "#+TITLE: English notes\n"
                      "some English prose with a note[fn:1].\n\n"
                      "[fn:1] the note\n")))
          (my/export-test--with-file
           doc
           (lambda ()
             (condition-case err
                 (progn
                   (org-typst-export-as-typst)
                   (with-current-buffer org-typst-export-buffer-name
                     (let ((typed (buffer-string)))
                       (if hebrew-p
                           (unless (string-match-p
                                    "#set text(lang: \"he\", dir: rtl)" typed)
                             (my/export-test-fail
                              "Hebrew export is not told dir: rtl: a numbered heading would sit at the left margin"))
                         (unless (string-match-p "#set text(lang: \"en\")" typed)
                           (my/export-test-fail
                            "English export is not told lang: en: %S"
                            (and (string-match "#set text([^)]*)" typed)
                                 (match-string 0 typed))))
                         (when (string-match-p "dir: rtl" typed)
                           (my/export-test-fail
                            "English export was told dir: rtl, so its paragraphs will lay out right-to-left"))))))
               (error
                (my/export-test-fail "typst generation signalled: %S" err)))))))

        ;; ---- 3. footnotes come out in reading order, not definition order ---
        ;; typst numbers notes by definition order, so an unsorted definitions
        ;; section yields backwards numbers. The export must stage and
        ;; renumber; the source file must be untouched.
        (let ((oo (expand-file-name "outoforder.org" work)))
          (my/export-test--copy-fixture
           (expand-file-name "test/export/fixtures/10-footnotes-out-of-order.org" root) oo)
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

        ;; ---- 5. an empty note is refused with a message, not a crash ----
        ;; ox-typst passes nil contents to org-trim for a definition with no
        ;; text and signals `wrong-type-argument (arrayp nil)'; what a person
        ;; sees must name the note instead.
        (let ((blank (expand-file-name "emptynote.org" work)))
          (with-temp-file blank
            (insert "#+TITLE: Empty note\n\n* H\ntext with a note[fn:1].\n\n[fn:1]\n"))
          (my/export-test--with-file
           blank
           (lambda ()
             (condition-case err
                 (progn
                   (let ((inhibit-message t)) (org-typst-export-to-pdf))
                   (my/export-test-fail "an empty footnote exported instead of being refused"))
               (user-error
                (unless (string-match-p "Footnote 1 has no text" (error-message-string err))
                  (my/export-test-fail "the refusal does not say which note is empty: %S" err)))
               (error
                (my/export-test-fail
                 "an empty note signalled %S instead of being refused" err))))))

    ;; A fixture that failed early must not poison the next run.
    (dolist (dir (seq-difference (my/export-test--temp-dirs) temps-before))
      (ignore-errors (delete-directory dir t)))
    (delete-directory work t))

  (if my/export-test--failures
      (progn
        (dolist (line (nreverse my/export-test--failures))
          (princ (concat "FAIL export: " line "\n") #'external-debugging-output))
        (kill-emacs 1))
    (princ (format "ok   export in profile: one PDF beside the source, no strays (%s)\n"
                 (if (eq my/profile (quote hebrew)) "RTL, dir set" "LTR, no dir"))
           #'external-debugging-output)))
