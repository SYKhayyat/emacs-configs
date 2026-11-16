;;; writing.el --- reading room and markdown -*- lexical-binding: t; -*-

(use-package olivetti
  :commands olivetti-mode
  :custom (olivetti-body-width 100))
(defun my/toggle-reading-room ()
  "Centre the text in this window, or give the width back."
  (interactive)
  (olivetti-mode 'toggle)
  (message "Reading room: %s" (if olivetti-mode "on" "off")))
(keymap-global-set "C-c w" #'my/toggle-reading-room)

(use-package markdown-mode :mode ("\\.md\\'" . markdown-mode))
