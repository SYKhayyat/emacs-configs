;;; prose.el --- org and writing -*- lexical-binding: t; -*-
(defvar my/profile)

(defun my/org-drop-footnote-highlighting ()
  "Remove org's footnote font-lock keyword; it costs seconds on big files."
  (setq-local org-font-lock-keywords
              (seq-remove (lambda (kw)
                            (string-match-p "org-activate-footnote-links" (format "%S" kw)))
                          org-font-lock-keywords)))

(defconst my/pretty-max-size (* 200 1024)
  "Buffers larger than this skip the table/org-look packages.")

(defun my/org-pretty ()
  (when (< (buffer-size) my/pretty-max-size)
    (org-modern-mode 1)
    (valign-mode 1)))

(use-package org
  :defer t
  :hook ((org-mode . my/org-drop-footnote-highlighting)
         (org-mode . my/org-pretty))
  :bind (("C-c a" . org-agenda) ("C-c c" . org-capture))
  ;; setq, not :custom: customize-set-variable on org options would load org.
  :init
  (setq org-hide-leading-stars t
        org-hide-emphasis-markers t
        org-ellipsis " ▾"
        org-pretty-entities t
        org-src-fontify-natively t
        org-return-follows-link t
        org-log-done 'time
        org-directory "~/Documents/org"
        org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "WAITING(w)" "|" "DONE(d)" "CANCELLED(c)"))
        org-capture-templates
        '(("t" "Task" entry (file+headline "~/Documents/org/inbox.org" "Tasks")
           "* TODO %?\n  %U")
          ("n" "Note" entry (file+headline "~/Documents/org/inbox.org" "Notes")
           "* %?\n  %U"))
        org-agenda-files '("~/Documents/org"))
  :config
  (org-babel-do-load-languages 'org-babel-load-languages
                               '((emacs-lisp . t) (shell . t) (python . t))))

(use-package org-modern :commands org-modern-mode
  :custom (org-modern-star 'replace) (org-modern-table nil))
(use-package valign :commands valign-mode)
(use-package org-download
  :commands (org-download-clipboard org-download-yank org-download-screenshot)
  :init (setq org-download-image-dir "./images"))

(use-package markdown-mode
  :mode ("\\.md\\'" . markdown-mode))

;; Spelling. Needs the enchant library (see README for each platform).
(use-package jinx
  :commands jinx-mode
  :hook (text-mode . jinx-mode)
  :bind ("M-$" . jinx-correct))
