;;; bidi.el --- paragraph direction: automatic, or pinned per buffer -*- lexical-binding: t; -*-
;;
;; DECISIONS.md keeps `bidi-paragraph-direction' nil, and this does not change
;; that: automatic is the cheap path, and forcing a direction that does not
;; match the text is the slow one (10-50x on wrapped Hebrew).
;;
;; What was missing was a way *out* of a wrong automatic answer. Automatic means
;; "from the first strong character in the paragraph", so Hebrew typed into a
;; paragraph that opened in English -- the scratch buffer, a reply under a quoted
;; English line -- lays out left-to-right. The commands to say otherwise lived
;; in the hebrew profile only, so the notes profile had none at all.
;;
;; Two keys, no third: `C-c r' pins right-to-left, `C-c l' pins left-to-right,
;; and pressing the one that is already pinned returns the buffer to automatic.
;; A cycle key was tempting and there is no room for it -- `C-c R' is
;; `my/revert-buffer' (navigation.el), and one accidental shift is enough.
;;
;; Nothing here runs per command: the state is one buffer-local variable, and the
;; label is a minor-mode lighter, which Emacs reads only in buffers where the
;; mode is on. No hook, no `:eval', no redisplay callback.

(defvar-local my/bidi-label " RTL"
  "Mode-line label for the pinned direction.
Only read when `my/bidi-pinned-mode' is on, so a buffer left automatic pays
nothing for it.")

(define-minor-mode my/bidi-pinned-mode
  "Non-nil when this buffer's paragraph direction is pinned by `my/bidi-set'.
The mode carries the label; the direction itself is `bidi-paragraph-direction'.
Turning it off restores automatic, so the mode and the direction cannot
disagree."
  :lighter my/bidi-label
  (unless my/bidi-pinned-mode
    (setq-local bidi-paragraph-direction nil)))

(defun my/bidi-set (direction)
  "Pin this buffer's direction to DIRECTION, or unpin it with nil.
DIRECTION is `right-to-left', `left-to-right' or nil for automatic."
  (setq-local bidi-paragraph-direction direction)
  (setq-local my/bidi-label (if (eq direction 'right-to-left) " RTL" " LTR"))
  (my/bidi-pinned-mode (if direction 1 -1))
  (message "Direction: %s"
           (pcase direction
             ('right-to-left "right-to-left")
             ('left-to-right "left-to-right")
             (_ "automatic, per paragraph"))))

(defun my/bidi-toggle (direction)
  "Pin DIRECTION, or restore automatic if this buffer is already pinned to it."
  (my/bidi-set (if (and my/bidi-pinned-mode
                        (eq bidi-paragraph-direction direction))
                   nil
                 direction)))

(defun my/set-rtl ()
  "Lay this buffer out right-to-left; again to go back to automatic."
  (interactive)
  (my/bidi-toggle 'right-to-left))

(defun my/set-ltr ()
  "Lay this buffer out left-to-right; again to go back to automatic."
  (interactive)
  (my/bidi-toggle 'left-to-right))

(keymap-global-set "C-c r" #'my/set-rtl)
(keymap-global-set "C-c l" #'my/set-ltr)
