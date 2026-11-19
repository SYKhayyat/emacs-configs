;;; rtl.el --- right-to-left behaviour: movement keys and footnote labels -*- lexical-binding: t; -*-
;; The direction commands themselves (`C-c r', `C-c l') are in bidi.el, which
;; every profile loads: a buffer whose direction is wrong is not a Hebrew-only
;; problem. What is Hebrew-only is how the cursor moves and how footnote labels
;; are laid out.

;; C-f / C-b follow the screen, not the logical order: in RTL text, C-f would
;; step left. right-char/left-char are the same moves in LTR text.
(global-set-key [remap forward-char] #'right-char)
(global-set-key [remap backward-char] #'left-char)

(defconst my/rlm "\u200F" "RIGHT-TO-LEFT MARK.")
(defvar-local my/rtl-footnote-labels nil)
(defvar-local my/rtl-footnote-signature nil)
(defvar-local my/rtl-footnote-dirty t
  "Non-nil when an edit may have added, broken or moved a footnote label.")

(defun my/shown-region (window)
  "(BEG . END) of the text WINDOW displays, without forcing redisplay.
A superset under `visual-line-mode' (logical lines, not screen lines).
`window-end' with UPDATE would be exact, but it forces a display walk, and
this runs after every command."
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
          (overlay-put o 'my/rtl-label t)
          (push o my/rtl-footnote-labels))))))

(defun my/rtl-footnote-note-change (beg end len)
  "Mark labels dirty only if the edit BEG..END (LEN deleted) could affect one.
Plain typing in body text leaves them alone: rebuilding every visible label
on every keystroke cost ~2 ms a character on long bidi paragraphs."
  (unless my/rtl-footnote-dirty
    (setq my/rtl-footnote-dirty
          (or (> len 0)
              (save-excursion (goto-char beg) (search-forward "\n" end t))
              (seq-some (lambda (o) (overlay-get o 'my/rtl-label))
                        (overlays-in (max (point-min) (1- beg))
                                     (min (point-max) (1+ end))))
              (save-excursion
                (goto-char beg) (beginning-of-line)
                (and (eq (char-after) ?\[)
                     (or (not (looking-at "\\[fn:[^]\n]*\\]"))
                         (<= beg (match-end 0)))))))))

(defun my/rtl-footnote-labels-follow ()
  "Rebuild labels after an edit that may touch one, or a scroll or resize."
  (let ((sig (mapcar (lambda (w) (cons w (my/shown-region w)))
                     (get-buffer-window-list nil nil t))))
    (when (or my/rtl-footnote-dirty (not (equal sig my/rtl-footnote-signature)))
      (setq my/rtl-footnote-signature sig
            my/rtl-footnote-dirty nil)
      (my/rtl-footnote-labels))))

(defun my/rtl-footnote-labels-shown (window)
  "Build labels when the buffer is first shown in WINDOW (emacsclient,
desktop restore), not only after the first command."
  (with-current-buffer (window-buffer window)
    (setq my/rtl-footnote-dirty t)
    (my/rtl-footnote-labels-follow)))

(defun my/rtl-footnote-setup ()
  ;; Buffer-local: only org buffers pay for it.
  (add-hook 'after-change-functions #'my/rtl-footnote-note-change nil t)
  (add-hook 'post-command-hook #'my/rtl-footnote-labels-follow nil t)
  (add-hook 'window-buffer-change-functions #'my/rtl-footnote-labels-shown nil t))
(add-hook 'org-mode-hook #'my/rtl-footnote-setup)

;; These run per keystroke; modules load as source, so compile them here.
(mapc #'byte-compile '(my/shown-region my/rtl-footnote-labels my/rtl-footnote-note-change
                       my/rtl-footnote-labels-follow my/rtl-footnote-labels-shown))
