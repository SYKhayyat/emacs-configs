;;; core.el --- defaults and built-in modes every profile shares -*- lexical-binding: t; -*-
;; Settings only. Paths of files Emacs writes are in files.el.
(defvar my/state-dir)

;; The real Compat, before anything that needs it. corfu, vertico and consult
;; now declare `(compat "31")' and call `set-local', `incf', `decf' and
;; `completion-list-candidate-at-point'; this Emacs is 30.2, and the compat.el
;; it ships is a stub that provides the feature and nothing else — so those
;; names were void at run time and every byte-compile warned about each one.
;; It is not enough to have the package installed: it has to be loaded before
;; `vertico--setup' runs (any minibuffer: C-x C-f, C-x b, M-x), which is why
;; this is here and not in the module that uses completion.
;;
;; `load' by name, not `require': once the stub has provided the feature — and
;; anything that loads an autoload file can do that — `require' returns it and
;; the real package never loads. `elpa/' is ahead of lisp/emacs-lisp/ on
;; `load-path' after package activation, so this finds the GNU ELPA copy.
(let ((compat (locate-library "compat")))
  (unless compat (error "Compat is not installed: run bin/install"))
  (load compat nil 'nomessage))

(defvar my/gc-idle-timer nil)
(defun my/restore-after-init ()
  "Undo the temporary GC and file-handler settings from early.el.
GC then happens mostly while idle: a full collection in a loaded daemon takes
50-80 ms, and typing in Org conses 35-40 KB per character, so a 16 MB threshold
put a visible stall mid-word every ~400 characters. 64 MB plus a collection
after 4 s idle moves it to the pauses. Not higher: each collection that does
happen while typing then takes longer."
  (setq gc-cons-threshold (* 64 1024 1024)
        gc-cons-percentage 0.2)
  (unless my/gc-idle-timer
    (setq my/gc-idle-timer (run-with-idle-timer 4 t #'garbage-collect)))
  ;; Merge, don't overwrite: handlers registered during init (TRAMP) survive.
  (setq file-name-handler-alist
        (delete-dups (append file-name-handler-alist my/file-name-handler-alist))))
(add-hook 'emacs-startup-hook #'my/restore-after-init)

(setq vc-handled-backends '(Git)
      read-process-output-max (* 1024 1024))

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(setq-default buffer-file-coding-system 'utf-8-unix)

;; No forced paragraph direction: forcing one that does not match the text costs
;; 10-50x on wrapped Hebrew (measured, see DECISIONS.md).
(setq-default bidi-paragraph-direction nil)

(setq sentence-end-double-space nil
      use-short-answers t
      delete-by-moving-to-trash t
      use-dialog-box nil
      use-file-dialog nil
      scroll-conservatively 101
      scroll-preserve-screen-position t
      auto-save-no-message t
      ring-bell-function #'ignore
      enable-recursive-minibuffers t
      save-interprogram-paste-before-kill t
      vc-follow-symlinks nil
      isearch-lazy-count t
      undo-limit (* 80 1024 1024)
      undo-strong-limit (* 120 1024 1024)
      undo-outer-limit (* 300 1024 1024)
      large-file-warning-threshold (* 100 1024 1024)
      recentf-max-saved-items 200
      history-length 500
      savehist-additional-variables '(kill-ring)
      kill-ring-max 60
      auto-revert-verbose nil
      ;; Files the config itself creates are not "recent".
      recentf-exclude (list (concat "\\`" (regexp-quote (expand-file-name my/repo-root))
                                    "\\(elpa\\|state\\)/")
                            "\\`/tmp/" "\\.export-" "\\.typst-"))
(setq-default indent-tabs-mode nil
              require-final-newline t
              word-wrap t)

(add-hook 'text-mode-hook #'visual-line-mode)

;; The kill ring is saved as plain text. Kills from Org or Magit carry faces and
;; `display' properties, which made the savehist file large, every autosave
;; slow, and could write objects that do not read back.
(defun my/savehist-plain-kill-ring ()
  (setq kill-ring (mapcar #'substring-no-properties (seq-filter #'stringp kill-ring))))
(add-hook 'savehist-save-hook #'my/savehist-plain-kill-ring)

;; Native code for elpa/ (cache in state/eln-cache/, see early.el), compiled
;; once in the background after the first idle half-minute, instead of
;; package by package as each one is first loaded. Files that already have
;; current native code are skipped, so after the first run this is a scan.
;; Not in bin/install: under Nix that runs during activation, inside a systemd
;; unit that kills whatever it leaves running.
(when (and (fboundp 'native-comp-available-p) (native-comp-available-p))
  (setq native-comp-async-report-warnings-errors 'silent)
  (add-hook 'emacs-startup-hook
            (lambda ()
              (run-with-idle-timer
               30 nil (lambda () (native-compile-async package-user-dir 'recursively))))))

;; Built-in features that replace packages we do not need, all cheap. On after
;; init so the first frame is not waiting for them.
(add-hook 'emacs-startup-hook
          (lambda ()
            (savehist-mode 1)
            (recentf-mode 1)
            (save-place-mode 1)
            (repeat-mode 1)
            (delete-selection-mode 1)
            (global-so-long-mode 1)
            (global-auto-revert-mode 1)
            (editorconfig-mode 1)
            (which-key-mode 1)
            (winner-mode 1)))

(setq which-key-idle-delay 0.5)
(keymap-global-set "C-c <left>" #'winner-undo)
(keymap-global-set "C-c <right>" #'winner-redo)

;; macOS only: a Finder/Dock launch has a bare PATH, so copy the shell's (rg, fd,
;; typst, language servers). On Linux the package is never loaded.
(when (eq system-type 'darwin)
  (require 'exec-path-from-shell nil t)
  (when (fboundp 'exec-path-from-shell-initialize)
    (exec-path-from-shell-initialize)))
