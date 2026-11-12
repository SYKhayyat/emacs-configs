;; -*- lexical-binding: t; -*-
(defvar my/profile)      ; bound by the profile loader
(defvar my/repo-root)    ; bound by the profile loader

;; Measurement lives in bench.org and is loaded only for a benchmark run, so a
;; normal start neither defines nor calls any of it.
(declare-function my/mark "bench" (label))

(when (getenv "MY_BENCH")
  (load (expand-file-name "base/bench.el" my/repo-root) nil 'nomessage)
  (my/mark "0 Emacs startup → our early-init"))
(defvar my/state-dir
  (expand-file-name (format "state/%s/" my/profile) my/repo-root)
  "Per-profile directory for files Emacs writes at run time.")

(make-directory my/state-dir t)

(setq package-user-dir (expand-file-name "elpa" my/repo-root)
      ;; Packages are activated by the loader, so activation order is visible
      ;; in `init-base.el' instead of implied by directory listing order.
      package-enable-at-startup nil)

(setq gc-cons-threshold (* 32 1024 1024)   ; 32 MB
      gc-cons-percentage 0.2)

(defvar my/file-name-handler-alist file-name-handler-alist
  "The real handler list, saved while init runs.")

(setq file-name-handler-alist nil)

(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-buffer-menu t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil
      frame-inhibit-implied-resize t)
