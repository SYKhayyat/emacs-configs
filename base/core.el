;; -*- lexical-binding: t; -*-
(defvar my/state-dir)     ; bound in early-init.org

(defun my/restore-after-init ()
  "Undo the temporary damage `early-init.org' does on purpose."
  (setq gc-cons-threshold (* 16 1024 1024)   ; 16 MB for a long session
        gc-cons-percentage 0.1)
  (when (boundp 'my/file-name-handler-alist)
    ;; Merge rather than overwrite: handlers registered while init ran (for
    ;; example TRAMP's archive handler) must survive, and the saved list must
    ;; come back. `delete-dups' on pairs compares with `equal'.
    (setq file-name-handler-alist
          (delete-dups (append file-name-handler-alist
                               my/file-name-handler-alist)))
    (makunbound 'my/file-name-handler-alist)))

(add-hook 'emacs-startup-hook #'my/restore-after-init)

(setq vc-handled-backends '(Git))

(setq read-process-output-max (* 1024 1024))   ; 1 MB

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(setq-default buffer-file-coding-system 'utf-8-unix
              default-process-coding-system '(utf-8-unix . utf-8-unix))

(setq custom-file (expand-file-name "custom.el" my/state-dir))
(load custom-file 'noerror 'nomessage)

(setq-default bidi-paragraph-direction 'left-to-right)

(defvar my/idle-modes-started nil
  "Non-nil once the deferred modes have been started.")

(defun my/start-idle-modes ()
  "Start the global modes whose only job is to protect against later trouble.

Measured cold on this machine: `global-so-long-mode' 85 ms, `delete-selection-mode'
16 ms, `which-key-mode' 25 ms. None of them is needed before the first key
press or the first minified file, so all three are paid after `emacs-startup',
when the user is reading rather than waiting.

This is idempotent, because it has two callers: the idle timer and its
fallback."
  (unless my/idle-modes-started
    (setq my/idle-modes-started t)
    (global-so-long-mode 1)
    (when (boundp 'delete-selection-mode)
      (delete-selection-mode 1))
    (when (fboundp 'which-key-mode)
      (which-key-mode 1))))

(defun my/schedule-idle-modes ()
  "Start the deferred modes once Emacs goes idle, and once again by the clock.

An idle timer alone is not enough: it is postponed whenever Emacs has anything
to do — a focus event, a metrics request, a message — and in a GUI session it
was observed not to fire at all in 1 run out of 9. A wall-clock timer cannot be
postponed that way. Either one may win; `my/start-idle-modes' runs once."
  (run-with-idle-timer 1.0 nil #'my/start-idle-modes)
  (run-with-timer 3.0 nil #'my/start-idle-modes))

(add-hook 'emacs-startup-hook #'my/schedule-idle-modes)

(setq sentence-end-double-space nil   ; C1  "word. Word" is a sentence end
      use-short-answers t             ; C3  y/n instead of yes/no
      delete-by-moving-to-trash t     ; C4  delete uses the desktop trash
      use-dialog-box nil              ; C5  no native modal dialogs …
      use-file-dialog nil             ;     … for file selection either
      scroll-conservatively 101       ; C6  scroll a line, don't re-centre
      scroll-preserve-screen-position t ; C7  keep text still under C-v/M-v
      auto-save-no-message t          ; C9  it saves either way; stop narrating
      ring-bell-function #'ignore     ; C10 no bell on a failed command
      enable-recursive-minibuffers t  ; C11 open a file from inside a prompt
      save-interprogram-paste-before-kill t ; C12 don't clobber the clipboard
      vc-follow-symlinks nil)         ; C14 visit the link, don't ask

;; C2 and C8 are automatically buffer-local, so they need `setq-default' to
;; reach buffers that do not exist yet. (One form each: a trailing comment
;; after a multi-line `setq' would swallow the closing paren.)
(setq-default indent-tabs-mode nil)     ; C2  no tabs written into files
(setq-default require-final-newline t)  ; C8  no missing-newline diffs
