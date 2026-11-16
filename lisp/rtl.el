;;; rtl.el --- right-to-left behaviour: movement keys and footnote labels -*- lexical-binding: t; -*-

;; C-f / C-b follow the screen, not the logical order: in RTL text, C-f would
;; step left. right-char/left-char are the same moves in LTR text.
(global-set-key [remap forward-char] #'right-char)
(global-set-key [remap backward-char] #'left-char)

(defconst my/rlm "\u200F" "RIGHT-TO-LEFT MARK.")
(defvar-local my/rtl-footnote-labels nil)
(defvar-local my/rtl-footnote-signature nil)

(defun my/shown-region (window)
  "(BEG . END) of the text WINDOW displays, without forcing redisplay."
  (cons (window-start window)
        (save-excursion
          (goto-char (window-start window))
          (forward-line (1+ (window-body-height window)))
          (point))))

(defun my/rtl-footnote-labels ()
  "Lay out each visible footnote label right-to-left (display-string overlay).
Text under a `display' property is ignored when Emacs picks a paragraph's
direction, so the paragraph starts at the Hebrew after the label."
  (mapc #'delete-overlay my/rtl-footnote-labels)
  (setq my/rtl-footnote-labels nil)
  (save-excursion
    (dolist (region (mapcar #'my/shown-region (get-buffer-window-list nil nil t)))
      (goto-char (car region))
      (while (re-search-forward "^\\[fn:[^]\n]*\\]" (cdr region) t)
        (let ((o (make-overlay (match-beginning 0) (match-end 0) nil t)))
          (overlay-put o 'display (concat my/rlm (match-string-no-properties 0)))
          (overlay-put o 'evaporate t)
          (push o my/rtl-footnote-labels))))))

(defun my/rtl-footnote-labels-follow ()
  (let ((sig (cons (buffer-chars-modified-tick)
                   (mapcar (lambda (w) (cons w (my/shown-region w)))
                           (get-buffer-window-list nil nil t)))))
    (unless (equal sig my/rtl-footnote-signature)
      (setq my/rtl-footnote-signature sig)
      (my/rtl-footnote-labels))))

;; Buffer-local: only org buffers pay for it.
(add-hook 'org-mode-hook
          (lambda () (add-hook 'post-command-hook #'my/rtl-footnote-labels-follow nil t)))
