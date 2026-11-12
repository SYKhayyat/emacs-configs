;;; early-init.el --- profile loader -*- lexical-binding: t; -*-
;; Identical in every profile. Emacs loads this from --init-directory before
;; the first frame exists, which is why the shared part lives in base/.

(defvar my/config-dir (file-name-directory (or load-file-name buffer-file-name)))
(defvar my/repo-root (expand-file-name "../.." my/config-dir))
(defvar my/profile (intern (file-name-nondirectory
                            (directory-file-name my/config-dir))))

(load (expand-file-name "base/early-init.el" my/repo-root) nil 'nomessage)
;;; early-init.el ends here
