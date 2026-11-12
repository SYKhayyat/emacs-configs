;; -*- lexical-binding: t; -*-
(defvar my/state-dir)     ; bound in early-init.org

(setq create-lockfiles nil          ; no .#file symlinks
      make-backup-files nil         ; git is the history
      auto-save-default t           ; a crash must not cost unsaved work
      auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save/" my/state-dir) t)))

(make-directory (expand-file-name "auto-save/" my/state-dir) t)
