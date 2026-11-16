;;; export.el --- org to PDF through Typst -*- lexical-binding: t; -*-
(defvar my/repo-root)

;; Commands without the code: `org-typst-export-to-pdf' and friends become
;; known here and the exporter itself loads on first use.
(let ((dir (expand-file-name "vendor/ox-typst" my/repo-root)))
  (add-to-list 'load-path dir)
  (load (expand-file-name "ox-typst-autoloads" dir) nil 'nomessage))

;; Number and list every heading level, not Emacs's three. Deeper headings are
;; rendered either way; the default only leaves them unnumbered and out of the
;; TOC, which is exactly the structure these documents use. Global on purpose:
;; the export stages the text in a fresh buffer, where a buffer-local value is
;; gone.
(setq org-export-headline-levels 10)

(defun my/org-footnotes-in-reference-order ()
  "Order and renumber this buffer's footnotes in reading order.

Typst numbers notes by their definition order, so a definition list that is not
in the order the notes are first referenced produces numbers that read
backwards.  Org's own `org-footnote-normalize' renumbers and re-sorts the
definitions to match; this is just the promise that it runs, and that it runs on
a copy, not on the file the user is editing."
  (require 'org)
  (org-footnote-normalize))

(defun my/org-empty-footnote ()
  "Label of the first footnote definition in this buffer with no text, or nil.
`ox-typst' signals a bare `wrong-type-argument (arrayp nil)' on such a
definition, because it passes nil contents to `org-trim'; the export refuses
it first, with the label named."
  (save-excursion
    (goto-char (point-min))
    (let (label)
      (while (and (not label) (re-search-forward "^\\[fn:\\([^]\n]*\\)\\][ \t]*$" nil t))
        (let* ((name (match-string-no-properties 1))
               (after (save-excursion (forward-line 1) (point)))
               (end (save-excursion
                      (goto-char after)
                      (if (re-search-forward "^\\[fn:[^]\n]*\\]\\|^\\*+ " nil t)
                          (line-beginning-position)
                        (point-max)))))
          (unless (string-match-p "\\S-" (buffer-substring-no-properties after end))
            (setq label name))))
      label)))

(defun my/org-typst-export-pdf (&optional async subtreep visible-only body-only ext-plist)
  "Export the current Org buffer to a PDF beside it, leaving nothing else behind.

Footnotes are put in reading order first, by
`my/org-footnotes-in-reference-order', on an unsaved copy staged in the source
directory: the PDF then numbers notes 1, 2, 3 ... in the order they are
referenced, whatever order the definitions sit in the file, and the file itself
is never rewritten.  The staged copy and the working Typst file are both
deleted, so only NAME.pdf remains, next to NAME.org.

SUBTREEP is passed straight through without ordering, since ordering is a
whole-file operation.  Otherwise the whole file is exported even when the buffer
is narrowed.  ASYNC is refused: compilation here is synchronous."
  (when async
    (user-error "Asynchronous export is not supported; the PDF is compiled synchronously"))
  (unless buffer-file-name
    (user-error "This buffer is not visiting a file, so there is nowhere to put a PDF"))
  (when-let* ((empty (org-with-wide-buffer (my/org-empty-footnote))))
    (user-error "Footnote %s has no text; type it or delete it before exporting"
                empty))
  (let* ((src buffer-file-name)
         (dir (file-name-directory src))
         (base (file-name-base src))
         (pdf (expand-file-name (concat base ".pdf") dir))
         ;; Beside the source: typst requires the input to be inside --root, and
         ;; the root has to stay the source directory for relative references.
         (typ (make-temp-file (expand-file-name ".typst-" dir) nil ".typ"))
         (staged (unless subtreep
                   (make-temp-file (expand-file-name ".export-" dir) nil ".org"))))
    (unwind-protect
        (progn
          (if subtreep
              (org-typst-export-as-typst async t visible-only body-only ext-plist)
            ;; Stage the current, possibly unsaved, contents; order the notes in
            ;; the copy; export from the copy.
            ;; Read the text first: inside `with-temp-file' the current buffer is
            ;; the temporary one, and point-min/max would refer to an empty file.
            (let ((body (org-with-wide-buffer
                         (buffer-substring-no-properties (point-min) (point-max)))))
              (with-temp-file staged (insert body)))
            (with-current-buffer (find-file-noselect staged)
              (org-mode)
              (my/org-footnotes-in-reference-order)
              (org-typst-export-as-typst async nil visible-only body-only ext-plist)))
          (with-current-buffer org-typst-export-buffer-name
            (write-region (point-min) (point-max) typ nil 'silent))
          (let ((made (org-typst-compile typ)))
            (unless (and made (file-exists-p made))
              (error "Typst did not produce a PDF for %s" src))
            (rename-file made pdf t)
            (message "Exported %s" pdf)
            pdf))
      ;; The staged org file gets a buffer of its own; it must not outlive the
      ;; export, and it must never be saved back.
      (let ((b (and staged (get-file-buffer staged))))
        (when b
          (with-current-buffer b (set-buffer-modified-p nil))
          (kill-buffer b)))
      (when (and staged (file-exists-p staged)) (delete-file staged))
      (when (file-exists-p typ) (delete-file typ))
      ;; typst writes NAME.pdf beside NAME.typ before it is renamed above; a
      ;; failed run leaves that partial file, which is not a document.
      (let ((partial (concat (file-name-sans-extension typ) ".pdf")))
        (when (file-exists-p partial) (delete-file partial))))))

(with-eval-after-load 'ox-typst
  (advice-add 'org-typst-export-to-pdf :override #'my/org-typst-export-pdf))

;; The document language, not the keyboard layout: it decides hyphenation and,
;; with the vendored patch, whether Typst is told `dir: rtl' so a numbered
;; heading in a Hebrew sefer aligns right like the text under it.
(defvar my/profile)
(setq org-export-default-language (if (eq my/profile 'hebrew) "he" "en"))
