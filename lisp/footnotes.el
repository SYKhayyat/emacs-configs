;;; footnotes.el --- footnote settings -*- lexical-binding: t; -*-
(with-eval-after-load 'org
  (setq org-footnote-section "Footnotes"
        org-footnote-define-inline nil
        ;; 863 ms per insertion on the 407 KB sefer, measured.
        org-footnote-auto-adjust nil))
