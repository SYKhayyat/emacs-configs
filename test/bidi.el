;;; bidi.el --- the direction pin, and the automatic default -*- lexical-binding: t; -*-
;; Run through bin/check, which loads a profile first.

;; The recorded decision: automatic unless asked otherwise.
(let ((default (default-value 'bidi-paragraph-direction)))
  (if default
      (message "FAIL bidi: default is pinned to %s, want nil" default)
    (message "ok bidi: the default direction is automatic")))

(with-temp-buffer
  (insert "שלום עולם, זה טקסט בעברית.")

  ;; Pure Hebrew is right-to-left without help. If this fails, the rest of the
  ;; file is measuring the wrong thing.
  (unless (eq (current-bidi-paragraph-direction) 'right-to-left)
    (message "FAIL bidi: pure Hebrew is %s, want right-to-left"
             (current-bidi-paragraph-direction)))

  ;; Pin LTR, the case that used to be unreachable outside the hebrew profile.
  (my/set-ltr)
  (unless (and my/bidi-pinned-mode (eq bidi-paragraph-direction 'left-to-right))
    (message "FAIL bidi: my/set-ltr did not pin the buffer"))
  (unless (equal my/bidi-label " LTR")
    (message "FAIL bidi: label is %S, want \" LTR\"" my/bidi-label))

  ;; The same key goes back to automatic, which is what makes one wrong
  ;; automatic answer recoverable from either direction.
  (my/set-ltr)
  (unless (and (null my/bidi-pinned-mode) (null bidi-paragraph-direction))
    (message "FAIL bidi: pressing LTR twice did not restore automatic"))
  (unless (eq (current-bidi-paragraph-direction) 'right-to-left)
    (message "FAIL bidi: after unpinning, Hebrew is %s again"
             (current-bidi-paragraph-direction)))

  ;; And the other key moves straight to the other direction.
  (my/set-rtl)
  (unless (and my/bidi-pinned-mode (equal my/bidi-label " RTL"))
    (message "FAIL bidi: my/set-rtl did not pin RTL"))
  (my/set-ltr)
  (unless (eq bidi-paragraph-direction 'left-to-right)
    (message "FAIL bidi: LTR after RTL left direction at %s" bidi-paragraph-direction)))

;; The keys have to survive Org, which is where the text is. `C-c R' is
;; `my/revert-buffer' and must stay that: a cycle key would have taken it.
(require 'org)
(with-temp-buffer
  (org-mode)
  (dolist (pair '(("C-c r" . my/set-rtl) ("C-c l" . my/set-ltr)))
    (unless (eq (key-binding (kbd (car pair))) (cdr pair))
      (message "FAIL bidi: %s is %s in Org, want %s"
               (car pair) (key-binding (kbd (car pair))) (cdr pair))))
  (unless (eq (key-binding (kbd "C-c R")) 'my/revert-buffer)
    (message "FAIL bidi: C-c R is %s in Org, want my/revert-buffer"
             (key-binding (kbd "C-c R")))))

(message "ok bidi: automatic by default, pinned by C-c r / C-c l, labelled while pinned")
