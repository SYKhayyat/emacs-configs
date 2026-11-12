;; -*- lexical-binding: t; -*-
(defvar my/state-dir)     ; bound in early-init.org
(defvar package-archives) ; defined by package.el, which may not be loaded yet

(setq package-directory-list nil)

(defun my/packages-present-p ()
  "Non-nil when the shared package directory holds at least one package."
  (let ((dir (and (boundp 'package-user-dir) package-user-dir)))
    (and (stringp dir)
         (file-directory-p dir)
         (seq-some (lambda (entry)
                     (and (file-directory-p entry)
                          ;; These two live in elpa/ but are not packages.
                          (not (member (file-name-nondirectory entry)
                                       '("archives" "gnupg")))))
                   (directory-files dir t "\\`[[:alnum:]]" t)))))

(when (my/packages-present-p)
  (require 'package)
  (add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/") t)
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
  (package-initialize))
