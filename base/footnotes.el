;; -*- lexical-binding: t; -*-

;; Set after org loads, so these win over whatever org's own defcustoms did.
(with-eval-after-load 'org
  (setq org-footnote-section "Footnotes"    ; the section is created at the end
        org-footnote-define-inline nil      ; new notes go there, never inline
        ;; 863 ms per insertion on the 407 KB sefer, measured; see above.
        org-footnote-auto-adjust nil))
