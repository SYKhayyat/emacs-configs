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

;; Force a buffer's paragraph direction (per buffer, on demand; never automatic).
(defun my/set-rtl () "Lay this buffer out right-to-left." (interactive)
  (setq-local bidi-paragraph-direction 'right-to-left))
(defun my/set-ltr () "Lay this buffer out left-to-right." (interactive)
  (setq-local bidi-paragraph-direction 'left-to-right))
(keymap-global-set "C-c r" #'my/set-rtl)
(keymap-global-set "C-c l" #'my/set-ltr)

(defun my/toggle-direction ()
  "Switch this buffer between right-to-left and left-to-right."
  (interactive)
  (if (eq bidi-paragraph-direction 'right-to-left) (my/set-ltr) (my/set-rtl)))

(defun my/toggle-bidi-reordering ()
  "Turn bidi reordering off/on in this buffer (a debugging switch)."
  (interactive)
  (setq-local bidi-display-reordering (not bidi-display-reordering))
  (message "Bidi reordering: %s" (if bidi-display-reordering "on" "off")))

(defun my/insert-hebrew-quotes ()
  "Insert a gershayim pair-mark (״), leaving point after it."
  (interactive) (insert "״"))

(defun my/insert-hebrew-parens ()
  "Insert \"()\" with point between them."
  (interactive) (insert "()") (backward-char))

(defun my/count-hebrew-words ()
  "Count Hebrew words in the buffer (or region)."
  (interactive)
  (let ((n 0) (beg (if (use-region-p) (region-beginning) (point-min)))
        (end (if (use-region-p) (region-end) (point-max))))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward "[\u05D0-\u05EA]+" end t) (cl-incf n)))
    (message "Hebrew words: %d" n)))

(defun my/new-hebrew-note (file)
  "Create FILE as an Org note with a Hebrew header."
  (interactive "FNew Hebrew note: ")
  (find-file file)
  (insert (format "#+TITLE: כותרת\n#+DATE: %s\n\n" (format-time-string "%Y-%m-%d"))))

(defun my/large-file-light ()
  "Over 5 MB: no bidi reordering, no font-lock."
  (when (> (buffer-size) (* 5 1024 1024))
    (setq-local bidi-display-reordering nil)
    (font-lock-mode -1)
    (message "Large file: bidi and font-lock off")))
(add-hook 'find-file-hook #'my/large-file-light)

(keymap-global-set "C-c d" #'my/toggle-direction)
(keymap-global-set "C-c B" #'my/toggle-bidi-reordering)
(keymap-global-set "C-c h q" #'my/insert-hebrew-quotes)
(keymap-global-set "C-c h p" #'my/insert-hebrew-parens)
(keymap-global-set "C-c h c" #'my/count-hebrew-words)
(keymap-global-set "C-c h n" #'my/new-hebrew-note)
