;; -*- lexical-binding: t; -*-

(defconst my/rlm "\u200F"   ; RIGHT-TO-LEFT MARK
  "Zero-width character that makes what follows it right-to-left.")

(defvar-local my/rtl-footnote-labels nil
  "Overlays that lay out each visible footnote definition right-to-left.")

(defun my/shown-region (window)
  "The text WINDOW displays, as (BEG . END), without forcing a redisplay.
`window-end' with UPDATE returns it exactly but pays for a full redisplay
(measured 2.2 ms on the sefer), which is too much to spend on every command.
Counting `window-body-height' buffer lines from the start cannot undershoot:
with wrapping, every buffer line covers at least one screen line."
  (cons (window-start window)
        (save-excursion
          (goto-char (window-start window))
          (forward-line (1+ (window-body-height window)))
          (point))))

(defun my/rtl-footnote-labels (&optional beg end)
  "Lay out each footnote definition in BEG..END right-to-left.
With no BEG and END, use the text each window showing this buffer displays.

A definition's label is Latin text at the head of the paragraph, so with the
base's nil paragraph direction the whole definition is left-to-right. Text
covered by a `display' property is not counted when Emacs picks a paragraph's
direction, so replacing the label makes the paragraph start at the Hebrew that
follows it; the label is still drawn, from the display string, at the right
edge. `evaporate' keeps a deleted label from leaving its overlay behind."
  (when (and (derived-mode-p 'org-mode) (null bidi-paragraph-direction))
    (mapc #'delete-overlay my/rtl-footnote-labels)
    (setq my/rtl-footnote-labels nil)
    (save-excursion
      (dolist (region (if (and beg end)
                          (list (cons beg end))
                        (mapcar #'my/shown-region
                                (get-buffer-window-list nil nil t))))
        (goto-char (car region))
        (while (re-search-forward "^\\[fn:[^]\n]*\\]" (cdr region) t)
          (let ((overlay (make-overlay (match-beginning 0) (match-end 0) nil t)))
            (overlay-put overlay 'display
                         (concat my/rlm (match-string-no-properties 0)))
            (overlay-put overlay 'evaporate t)
            (push overlay my/rtl-footnote-labels)))))))

(defvar-local my/rtl-footnote-signature nil
  "What the labels were last rebuilt from, so an idle command costs nothing.")

(defun my/rtl-footnote-labels-follow ()
  "Rebuild the footnote overlays when this buffer or a window has changed.
`post-command-hook' runs before redisplay, so the first frame drawn for a sefer
already has them."
  (when (and (derived-mode-p 'org-mode) (null bidi-paragraph-direction))
    (let ((signature
           (cons (buffer-chars-modified-tick)
                 (mapcar (lambda (window) (cons window (my/shown-region window)))
                         (get-buffer-window-list nil nil t)))))
      (unless (equal signature my/rtl-footnote-signature)
        (setq my/rtl-footnote-signature signature)
        (my/rtl-footnote-labels)))))

(add-hook 'post-command-hook #'my/rtl-footnote-labels-follow)

;; -*- lexical-binding: t; -*-

;; Logical movement in a Hebrew paragraph steps against the eye: C-f moves one
;; *character* forward, which inside RTL text is one step left on screen.
;; right-char/left-char move in visual order, and in LTR text they are the same
;; moves as forward-char/backward-char, so nothing changes in an English
;; paragraph. Checked in test/invariants.el for every profile: the other two
;; must still have the standard bindings.
(global-set-key [remap forward-char] #'right-char)
(global-set-key [remap backward-char] #'left-char)

(my/autoload "olivetti")

(setq-default olivetti-body-width 100)

(defun my/toggle-reading-room ()
  "Centre the text in this window, or give the width back."
  (interactive)
  (olivetti-mode 'toggle)
  (message "Reading room: %s" (if olivetti-mode "on" "off")))

(global-set-key (kbd "C-c w") #'my/toggle-reading-room)
