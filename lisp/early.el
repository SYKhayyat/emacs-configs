;;; early.el --- before the first frame -*- lexical-binding: t; -*-
;; Loaded by configs/<profile>/early-init.el, which binds `my/profile' and
;; nothing else. Settings only: nothing here loads a feature.

(defvar my/profile)

;; EMACS_CONFIG_ROOT first: `load' resolves symlinks, so in a tree built out of
;; links into the Nix store this file's own directory is the store copy, which
;; is read-only and has no elpa/ or state/. The Nix wrapper sets it; a plain
;; checkout does not need it.
(defvar my/repo-root
  (file-name-as-directory
   (or (getenv "EMACS_CONFIG_ROOT")
       (expand-file-name ".." (file-name-directory load-file-name))))
  "The tree this Emacs runs from: lisp/, configs/, elpa/, state/.")

;; Which copy of the config this process loaded. Under Nix, lisp/ is a link
;; into the store and its true name changes with every pin; in a checkout it is
;; the checkout. bin/launch.sh computes the same thing before it hands a frame
;; to a running daemon, and warns when they differ: a daemon started before an
;; update keeps running the old code, and nothing else would say so.
(defvar my/config-stamp (file-truename (expand-file-name "lisp" my/repo-root))
  "True name of the lisp/ directory this Emacs loaded its modules from.")

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

;; Native code for elpa/, shared by the profiles: the packages are the same
;; files in all three, and three caches meant compiling all of them three
;; times. Under state/, the one writable directory besides elpa/. Profile
;; directories stay free of it, which matters under Nix, where configs/<p>/ is
;; a directory of links.
(when (and (featurep 'native-compile) (fboundp 'startup-redirect-eln-cache))
  (startup-redirect-eln-cache (expand-file-name "state/eln-cache/" my/repo-root)))

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

(defun my/load-profile ()
  "Load the modules lisp/profiles.el lists for `my/profile'."
  (load (expand-file-name "lisp/profiles" my/repo-root) nil 'nomessage)
  (defvar my/profile-modules)
  (my/load-modules
   (or (alist-get my/profile my/profile-modules)
       (error "No module list for profile %s in lisp/profiles.el" my/profile))))
