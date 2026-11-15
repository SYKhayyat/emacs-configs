;; -*- lexical-binding: t; -*-
(defvar my/profile)       ; bound by the profile bootstrap

(global-font-lock-mode -1)

(defun my/org-drop-footnote-highlighting ()
  "Remove org's footnote font-lock keyword from the current buffer.
Font-lock being off already avoids it; this is for a buffer where it was
turned back on by hand, where the cost is seconds rather than milliseconds."
  (setq-local org-font-lock-keywords
              (seq-remove (lambda (kw)
                            (string-match-p "org-activate-footnote-links"
                                            (format "%S" kw)))
                          org-font-lock-keywords)))

(add-hook 'org-mode-hook #'my/org-drop-footnote-highlighting)

(when (memq my/profile '(hebrew notes))
  (run-with-timer
   0.2 nil
   (lambda ()
     (ignore-errors (with-temp-buffer (delay-mode-hooks (org-mode)))))))
