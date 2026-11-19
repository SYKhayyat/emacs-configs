;;; install.el --- install the packages in lisp/packages.el -*- lexical-binding: t; -*-
;; Run through bin/install (or `emacs --batch -Q -l bin/install.el'). Idempotent.
;; Cross-platform: pure Emacs, no shell.

(require 'package)
(let ((root (or (getenv "EMACS_CONFIG_ROOT")
                (expand-file-name ".." (file-name-directory load-file-name)))))
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
  ;; Packages Emacs ships itself, and ships as a stub. `compat' is the one: Emacs
  ;; 30's compat.el provides the feature and only compat-function/compat-call,
  ;; while corfu, vertico and consult require compat 31. `package-installed-p'
  ;; answers t for a builtin, so these have to be installed from the archive's
  ;; `package-desc' by hand. Only these: going through the desc for every package
  ;; breaks dependency resolution in this Emacs (`Wrong type argument: stringp,
  ;; #<symbol xterm-color at 685>' on eat, gptel and exec-path-from-shell), which
  ;; is also what `package-install-upgrade-built-in' did.
  (defconst my/builtin-stubs '(compat))
  ;; Installed means "into elpa/", which is a `package-desc-dir' that is a
  ;; string; a builtin's is the symbol `builtin'.
  ;;
  ;; Every install passes DONT-SELECT. `package-selected-packages' is Emacs's
  ;; own record of what a user asked for interactively and this file has
  ;; `my/packages' instead, but skipping it is not just tidiness:
  ;; `package--save-selected-packages' sorts that list with `string-lessp', and
  ;; a dependency installed on the way -- MELPA's xterm-color, pulled in by
  ;; slime -- arrives with its name as a symbol *with position*, so the sort
  ;; dies with `wrong-type-argument stringp #<symbol xterm-color at 685>' and
  ;; takes every later install in the batch with it.
  (dolist (p my/packages)
    (let ((desc (cadr (assq p package-alist))))
      (unless (and desc (stringp (package-desc-dir desc)))
        (condition-case err
            (package-install
             (if (memq p my/builtin-stubs)
                 (or (cadr (assq p package-archive-contents))
                     (error "no archive version of %s" p))
               p)
             t)
          (error (push p failed)
                 (message "FAILED %s: %s" p (error-message-string err)))))))
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
