;;; init.el --- bootstrap -*- lexical-binding: t; -*-
;; Identical in every profile, and deliberately trivial: it knows where the
;; repository is and hands over to base/loader.el, which does the real work.
;; Everything that makes a profile different is in this directory's modules/
;; and MANIFEST.

(defvar my/config-dir (file-name-directory (or load-file-name buffer-file-name)))
(defvar my/repo-root (expand-file-name "../.." my/config-dir))
(defvar my/profile (intern (file-name-nondirectory
                            (directory-file-name my/config-dir))))

(unless (bound-and-true-p my/state-dir)
  (load (expand-file-name "base/early-init.el" my/repo-root) nil 'nomessage))

(load (expand-file-name "base/loader.el" my/repo-root) nil 'nomessage)
;;; init.el ends here
