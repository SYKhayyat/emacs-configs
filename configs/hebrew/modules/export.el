;; -*- lexical-binding: t; -*-

;; Commands without the code: `org-typst-export-to-pdf' and friends become
;; known here and the exporter itself loads on first use.
(my/autoload "ox-typst")

(defun my/org-typst-export-pdf (&optional _async subtreep visible-only body-only ext-plist)
  "Export the current Org buffer to a PDF beside it, leaving nothing else behind.

The Typst file is written to a fresh temporary directory and compiled with that
directory's parent as --root, then deleted.  Only NAME.pdf remains, next to
NAME.org.  This replaces `org-typst-export-to-pdf', which writes NAME.typ into
the source directory, so the stock export menu needs no new key."
  (unless buffer-file-name
    (user-error "This buffer is not visiting a file, so there is nowhere to put a PDF"))
  (let* ((src buffer-file-name)
         (dir (file-name-directory src))
         (base (file-name-base src))
         (pdf (expand-file-name (concat base ".pdf") dir))
         ;; Beside the source: typst requires the input to be inside --root, and
         ;; the root has to stay the source directory for relative references.
         (typ (make-temp-file (expand-file-name ".typst-" dir) nil ".typ")))
    (unwind-protect
        (progn
          (org-typst-export-as-typst nil subtreep visible-only body-only ext-plist)
          (with-current-buffer org-typst-export-buffer-name
            (write-region (point-min) (point-max) typ nil 'silent))
          (let ((made (org-typst-compile typ)))
            (unless (and made (file-exists-p made))
              (error "Typst did not produce a PDF for %s" src))
            (rename-file made pdf t)
            (message "Exported %s" pdf)
            pdf))
      (when (file-exists-p typ) (delete-file typ))
      ;; typst writes NAME.pdf beside NAME.typ before it is renamed above; a
      ;; failed run leaves that partial file, which is not a document.
      (let ((partial (concat (file-name-sans-extension typ) ".pdf")))
        (when (file-exists-p partial) (delete-file partial))))))

(with-eval-after-load 'ox-typst
  (advice-add 'org-typst-export-to-pdf :override #'my/org-typst-export-pdf))
