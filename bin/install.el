;;; install.el --- install the packages in lisp/packages.el -*- lexical-binding: t; -*-
;; Run through bin/install (or `emacs --batch -Q -l bin/install.el'). Idempotent.
;; Cross-platform: pure Emacs, no shell.

(require 'package)
(let ((root (expand-file-name ".." (file-name-directory load-file-name))))
  (setq package-user-dir (expand-file-name "elpa" root)
        package-directory-list nil
        package-quickstart nil
        package-quickstart-file (expand-file-name "quickstart.el" package-user-dir)
        package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                           ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                           ("melpa" . "https://melpa.org/packages/")))
  (load (expand-file-name "lisp/packages.el" root) nil t)
  (package-initialize)
  (package-refresh-contents)
  (defvar failed nil)
  (dolist (p my/packages)
    (unless (package-installed-p p)
      (condition-case err (package-install p)
        (error (push p failed)
               (message "FAILED %s: %s" p (error-message-string err))))))
  (package-quickstart-refresh)
  ;; Record what is installed, so a clone can see which versions worked.
  (with-temp-file (expand-file-name "packages.lock" root)
    (insert ";; Versions installed by bin/install. Informational.\n")
    (dolist (e (sort (copy-sequence package-alist)
                     (lambda (a b) (string< (car a) (car b)))))
      (insert (format "%s %s\n" (car e)
                      (package-version-join (package-desc-version (cadr e))))))))
(when (bound-and-true-p failed)
  (message "bin/install: %d package(s) failed: %s" (length failed) failed)
  (kill-emacs 1))
