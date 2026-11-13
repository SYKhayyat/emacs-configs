;;; export-footnote-placement.el --- prove notes sit at the page bottom -*- lexical-binding: t; -*-
;;
;; Run with the hebrew profile loaded:
;;
;;   emacs -Q --batch -l configs/hebrew/early-init.el \
;;                  -l configs/hebrew/init.el -l test/export-footnote-placement.el
;;
;; A footnote that renders is not the same as a footnote that renders at the
;; bottom. Typst could just as well have put the note in the flow — and then the
;; page would look fine in a text dump and wrong on paper. So this reads the
;; geometry out of the PDF itself: every word carries its y coordinate, and the
;; note has to be in the bottom band of the page, well below the body, with
;; nothing from the body sharing its line.
;;
;; Two footnote syntaxes are checked, because they take different code paths in
;; the exporter:
;;   [fn:1] ... [fn:1] body      a standard definition
;;   text[fn::note]              an inline definition
;;
;; Needs poppler's pdftotext for the coordinates. Without it there is no
;; geometry to read, and the check says so out loud rather than passing.

(require 'subr-x)

(defvar my/fn-test--failures nil)

(defun my/fn-test-fail (fmt &rest args)
  (push (apply #'format fmt args) my/fn-test--failures))

(defun my/fn-test--reverse (s)
  "S as it appears inside a PDF's word stream."
  (apply #'string (nreverse (string-to-list s))))

(defun my/fn-test--pages (bbox-file)
  "Parse pdftotext -bbox output into a list of (HEIGHT (YMIN TEXT) ...)."
  (with-temp-buffer
    (insert-file-contents bbox-file)
    (let ((xml (buffer-string))
          pages)
      (let ((pos 0))
        (while (string-match "<page width=\"[0-9.]+\" height=\"\\([0-9.]+\\)\">" xml pos)
          (let* ((height (string-to-number (match-string 1 xml)))
                 (start (match-end 0))
                 (end (string-match "</page>" xml start))
                 (body (substring xml start end))
                 (words nil)
                 (wpos 0))
            (while (string-match
                    "<word xMin=\"[0-9.]+\" yMin=\"\\([0-9.]+\\)\" xMax=\"[0-9.]+\" yMax=\"[0-9.]+\">\\([^<]*\\)</word>"
                    body wpos)
              (push (list (string-to-number (match-string 1 body))
                          (match-string 2 body))
                    words)
              (setq wpos (match-end 0)))
            (push (cons height (nreverse words)) pages)
            (setq pos end))))
      (nreverse pages))))

(defun my/fn-test--hebrew-only (s)
  "S reduced to its Hebrew letters, so attached punctuation cannot hide a word."
  (replace-regexp-in-string "[^\u0590-\u05ff]" "" s))

(defun my/fn-test--lines-of (word page)
  "The y coordinates where WORD occurs on PAGE.

pdftotext emits words in visual order with punctuation attached, so the
comparison is made on the Hebrew letters alone, reversed."
  (let ((want (my/fn-test--reverse (my/fn-test--hebrew-only word))))
    (seq-keep (lambda (cell)
                (when (string= (my/fn-test--hebrew-only (cadr cell)) want)
                  (car cell)))
              (cdr page))))

(defun my/fn-test--assert-bottom (pages word what)
  "Fail unless every occurrence of WORD on its page is in the bottom band."
  (let ((hits (seq-mapcat (lambda (page)
                            (seq-map (lambda (y) (cons y (car page)))
                                     (my/fn-test--lines-of word page)))
                          pages)))
    (cond
     ((null hits)
      (my/fn-test-fail "%s: %S is not in the PDF text at all" what word))
     (t
      (dolist (hit hits)
        (let* ((y (car hit)) (height (cdr hit)) (frac (/ y (float height))))
          (unless (>= frac 0.75)
            (my/fn-test-fail "%s: %S sits at %.0f%% down the page, not at the bottom"
                             what word (* 100 frac)))))
      ;; The note must be far below the *text* of the page. Anything below the
      ;; middle is already excluded from "body", so a second note cannot stand in
      ;; for the body and mask an inline one.
      (let* ((page (car (seq-filter
                         (lambda (p) (my/fn-test--lines-of word p)) pages)))
             (note-y (car (my/fn-test--lines-of word page)))
             (body-ys (seq-filter (lambda (y) (< (/ y (float (car page))) 0.5))
                                  (seq-map #'car (cdr page)))))
        (when (and body-ys (< (- note-y (apply #'max body-ys)) 150))
          (my/fn-test-fail "%s: %S is only %.0f pt below the last body line — in the flow, not at the bottom"
                           what word (- note-y (apply #'max body-ys)))))))))

(let* ((root (file-name-directory (directory-file-name
                                   (file-name-directory load-file-name))))
       (pdftotext (executable-find "pdftotext"))
       (work (make-temp-file "my-fn-test-" t)))
  (unwind-protect
      (cond
       ((null pdftotext)
        (princ "skip footnote placement: pdftotext (poppler) not installed\n"
               #'external-debugging-output)
        (kill-emacs 0))
       (t
        (let* ((org (expand-file-name "notes.org" work))
               (pdf (expand-file-name "notes.pdf" work))
               (bbox (expand-file-name "notes.xml" work)))
          (copy-file (expand-file-name "test/export/fixtures/09-footnotes-placement.org" root)
                     org t)
          (with-current-buffer (find-file-noselect org)
            (condition-case err
                (let ((inhibit-message t)) (my/org-typst-export-pdf))
              (error (my/fn-test-fail "export signalled: %S" err)))
            (set-buffer-modified-p nil)
            (kill-buffer))
          (when (file-exists-p pdf)
            (let ((rc (call-process pdftotext nil nil nil "-bbox" pdf bbox)))
              (if (not (eq rc 0))
                  (my/fn-test-fail "pdftotext -bbox exited %s" rc)
                (let ((pages (my/fn-test--pages bbox)))
                  (my/fn-test--assert-bottom pages "העמוד" "standard note")
                  (my/fn-test--assert-bottom pages "מיוחדת" "inline note"))))))))

    (delete-directory work t))

  (if my/fn-test--failures
      (progn
        (dolist (line (nreverse my/fn-test--failures))
          (princ (concat "FAIL footnotes: " line "\n") #'external-debugging-output))
        (kill-emacs 1))
    (princ "ok   footnotes: standard and inline notes land at the page bottom\n"
           #'external-debugging-output)))
