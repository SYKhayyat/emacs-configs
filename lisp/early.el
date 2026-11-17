;;; early.el --- before the first frame -*- lexical-binding: t; -*-
;; Loaded by configs/<profile>/early-init.el, which binds `my/profile' and
;; `my/repo-root'. Settings only: nothing here loads a feature.

(defvar my/profile)
(defvar my/repo-root)

(defvar my/state-dir
  (expand-file-name (format "state/%s/" my/profile) my/repo-root)
  "Per-profile directory for files Emacs writes at run time (git-ignored).")
(make-directory my/state-dir t)

;; Packages. The repo owns them: they live in elpa/ beside this file, are listed
;; in lisp/packages.el and installed by bin/install. The system's own package
;; directories (Nix, distro) are ignored, so the config behaves the same on any
;; machine. `package-quickstart' makes activation one file load.
(setq package-user-dir (expand-file-name "elpa" my/repo-root)
      package-directory-list nil
      package-quickstart t
      package-quickstart-file (expand-file-name "quickstart.el" package-user-dir))

;; GC off while init runs; `my/restore-after-init' (core.el) sets it back.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)
(defvar my/file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

;; Frame parameters, not mode calls: no resize, no flash (documented practice).
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

(setq inhibit-startup-screen t
      initial-scratch-message nil
      frame-inhibit-implied-resize t)

(defun my/load-modules (modules)
  "Load lisp/MODULE.el for each symbol in MODULES, in order.
Every profile's init.el is just a call to this with its list."
  ;; No ".el": `load' would use an .elc if one existed. None is built on purpose:
  ;; init is ~0.27 s interpreted, and compiling modules that use Org macros
  ;; without Org loaded leaves them unexpanded (invalid-function at run time).
  (let ((load-prefer-newer t))
    (dolist (m modules)
      (load (expand-file-name (format "lisp/%s" m) my/repo-root) nil 'nomessage)))
  ;; Last, so Customize (custom.el in the state dir) is the one deliberate
  ;; override layer on top of the modules, not a silently losing second owner.
  (defvar custom-file)
  (setq custom-file (expand-file-name "custom.el" my/state-dir))
  (condition-case err
      (load custom-file 'noerror 'nomessage)
    (error (message "custom-file ignored (%s): %s"
                    (error-message-string err) custom-file))))
