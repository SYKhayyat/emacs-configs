;;; writing.el --- reading room, spelling, markdown -*- lexical-binding: t; -*-

(use-package olivetti
  :commands olivetti-mode
  :custom (olivetti-body-width 100))
(defun my/toggle-reading-room ()
  "Centre the text in this window, or give the width back."
  (interactive)
  (olivetti-mode 'toggle)
  (message "Reading room: %s" (if olivetti-mode "on" "off")))
(keymap-global-set "C-c w" #'my/toggle-reading-room)

;; Spelling. Needs the enchant library (see README for each platform).
(use-package jinx
  :commands jinx-mode
  :hook (text-mode . jinx-mode)
  :bind ("M-$" . jinx-correct))

(use-package markdown-mode :mode ("\\.md\\'" . markdown-mode))
