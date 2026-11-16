;;; rtl.el --- Hebrew behaviour in org buffers -*- lexical-binding: t; -*-

;; C-f / C-b follow the screen, not the logical order: in RTL text, C-f would
;; step left. right-char/left-char are the same moves in LTR text.
(global-set-key [remap forward-char] #'right-char)
(global-set-key [remap backward-char] #'left-char)

(use-package olivetti
  :commands olivetti-mode
  :custom (olivetti-body-width 100))
(defun my/toggle-reading-room ()
  "Centre the text in this window, or give the width back."
  (interactive)
  (olivetti-mode 'toggle)
  (message "Reading room: %s" (if olivetti-mode "on" "off")))
(keymap-global-set "C-c w" #'my/toggle-reading-room)

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

;; Niqqud-insensitive search: each Hebrew letter may be followed by points.
(defconst my/niqqud "[\u0591-\u05C7]*")
(defun my/hebrew-niqqud-regexp (string)
  "Regexp for STRING that ignores niqqud, or nil if it has no Hebrew letters."
  (when (string-match-p "[\u05D0-\u05EA]" string)
    (mapconcat (lambda (c)
                 (concat (regexp-quote (char-to-string c))
                         (if (<= #x05D0 c #x05EA) my/niqqud "")))
               string "")))

(defun my/isearch-niqqud-fun (orig &rest args)
  (let ((f (apply orig args)))
    (lambda (string &optional bound noerror count)
      (if-let* ((rx (and (not isearch-regexp) (my/hebrew-niqqud-regexp string))))
          (funcall (if isearch-forward #'re-search-forward #'re-search-backward)
                   rx bound noerror count)
        (funcall f string bound noerror count)))))
(advice-add 'isearch-search-fun-default :around #'my/isearch-niqqud-fun)

(with-eval-after-load 'orderless
  (defun my/orderless-hebrew (pattern _i _n)
    "All-Hebrew PATTERN matches regardless of niqqud and vav/yod spelling."
    (when (string-match-p "\\`[\u05D0-\u05EA]+\\'" pattern)
      (cons 'orderless-regexp
            (concat my/niqqud
                    (mapconcat (lambda (c)
                                 (concat (regexp-quote (char-to-string c))
                                         (if (memq c '(?ו ?י)) "?" "")
                                         my/niqqud))
                               pattern "")))))
  (add-to-list 'orderless-style-dispatchers #'my/orderless-hebrew))
