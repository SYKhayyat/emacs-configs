;; -*- lexical-binding: t; -*-
(defvar my/state-dir)     ; bound in early-init.org

(setq create-lockfiles nil          ; no .#file symlinks
      make-backup-files nil         ; git is the history
      auto-save-default t           ; a crash must not cost unsaved work
      auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save/" my/state-dir) t)))

;; The list of buffers that have auto-saves ("crash recovery") is written on
;; exit and follows `user-emacs-directory', which --init-directory points at
;; configs/<profile>/. Left alone it would create an untracked directory inside
;; the checkout every time a crash list exists.
(setq auto-save-list-file-prefix
      (expand-file-name "auto-save-list/.saves-" my/state-dir))
(make-directory (expand-file-name "auto-save-list/" my/state-dir) t)

(make-directory (expand-file-name "auto-save/" my/state-dir) t)

;; Every file Emacs writes at run time goes under the profile's state dir.
(setq savehist-file (expand-file-name "savehist.el" my/state-dir)
      recentf-save-file (expand-file-name "recentf.el" my/state-dir)
      save-place-file (expand-file-name "places.el" my/state-dir)
      bookmark-default-file (expand-file-name "bookmarks.el" my/state-dir)
      project-list-file (expand-file-name "projects.el" my/state-dir)
      tramp-persistency-file-name (expand-file-name "tramp.el" my/state-dir)
      transient-history-file (expand-file-name "transient-history.el" my/state-dir)
      eshell-directory-name (expand-file-name "eshell/" my/state-dir)
      url-configuration-directory (expand-file-name "url/" my/state-dir))
