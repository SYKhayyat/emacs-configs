;;; export-narrowed.el --- a narrowed buffer still exports the whole file -*- lexical-binding: t; -*-
;; Run with a prose profile loaded (see bin/check).
(let* ((work (make-temp-file "my-narrow-test-" t))
       (src (expand-file-name "n.org" work))
       (pdf (expand-file-name "n.pdf" work))
       (bad nil))
  (unwind-protect
      (progn
        (with-temp-file src (insert "* First\nALPHAMARK\n* Second\nBETAMARK\n"))
        (with-current-buffer (find-file-noselect src)
          (goto-char (point-max)) (org-back-to-heading) (org-narrow-to-subtree)
          (let ((inhibit-message t)) (my/org-typst-export-pdf))
          (set-buffer-modified-p nil) (kill-buffer))
        (if (not (file-exists-p pdf))
            (push "no PDF" bad)
          (if (not (executable-find "pdftotext"))
              (message "skip export-narrowed text check: no pdftotext")
            (let ((txt (shell-command-to-string (format "pdftotext %s -" (shell-quote-argument pdf)))))
              (unless (string-match-p "ALPHAMARK" txt) (push "narrowed export lost the first heading" bad)))))
        ;; async is refused, not half-run
        (with-current-buffer (find-file-noselect src)
          (unless (condition-case nil (progn (my/org-typst-export-pdf t) nil) (user-error t))
            (push "async export was not refused" bad))
          (set-buffer-modified-p nil) (kill-buffer)))
    (delete-directory work t))
  (if bad (progn (dolist (b bad) (message "FAIL export-narrowed: %s" b)) (kill-emacs 1))
    (message "ok   export-narrowed")))
