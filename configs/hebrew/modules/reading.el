;; -*- lexical-binding: t; -*-

;; Colour off, everywhere in this profile. Not a size threshold: a threshold
;; would make the same file look different depending on where it was opened
;; from, and the saving never depends on the threshold anyway — font-lock is
;; the same price per screen at any size.
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

;; Org loads its own modules on the first org buffer: 2,109 ms measured, and the
;; first file opened through the daemon pays it. Loading org on a short timer
;; moves that work into the background, where it overlaps with the second or so
;; a person spends choosing a file, instead of sitting in front of the buffer.
;; A plain timer, not an idle timer: an idle timer stops when Emacs is busy, and
;; a daemon with no clients is not always reported as idle.
;; Entering org once is what loads the chain: `require'ing org.el alone leaves
;; `org-load-modules-maybe' to run on the first real sefer, which is the cost we
;; were trying to move. Measured: `(featurep \='org)' was already t and the
;; first open still took 2.5 s.
(run-with-timer
 0.2 nil
 (lambda ()
   (ignore-errors (with-temp-buffer (delay-mode-hooks (org-mode))))))
