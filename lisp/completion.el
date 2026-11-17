;;; completion.el --- minibuffer and in-buffer completion -*- lexical-binding: t; -*-
;; The standard vertico stack, configured the documented way.

(defun my/vertico-sort-folders-first (cands)
  "Sort CANDS alphabetically, directories (ending in \"/\") before files.
No `file-directory-p' stat per candidate; the trailing slash is how
`read-file-name' presents directories."
  (sort (copy-sequence cands)
        (lambda (a b)
          (let* ((a (substring-no-properties a))
                 (b (substring-no-properties b))
                 (da (string-suffix-p "/" a))
                 (db (string-suffix-p "/" b)))
            (cond ((and da (not db)) t)
                  ((and db (not da)) nil)
                  (t (string-lessp (downcase a) (downcase b))))))))

(use-package vertico
  :init (vertico-mode 1)
  ;; Alphabetical, folders first, everywhere (M-x included: no history ranking).
  :custom (vertico-count 15) (vertico-resize nil)
  (vertico-sort-function #'my/vertico-sort-folders-first))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion))))
  ;; -term excludes, =term is literal.
  (orderless-style-dispatchers
   (list (lambda (p _i _n)
           (cond ((string-prefix-p "-" p) `(orderless-without-literal . ,(substring p 1)))
                 ((string-prefix-p "=" p) `(orderless-literal . ,(substring p 1))))))))

(defun my/toggle-orderless ()
  "Turn orderless matching on or off in completion lists (until restart)."
  (interactive)
  (if (memq 'orderless completion-styles)
      (progn (setq completion-styles '(basic partial-completion))
             (message "Orderless off: names match from the start"))
    (setq completion-styles '(orderless basic))
    (message "Orderless on: words match in any order")))
(keymap-global-set "C-c o" #'my/toggle-orderless)

(use-package marginalia :init (marginalia-mode 1))

(use-package consult
  :bind (("M-s l" . consult-line)
         ("C-x b" . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("M-g g" . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("M-g i" . consult-imenu)
         ("M-g o" . consult-outline)
         ("M-s r" . consult-ripgrep)
         ("M-s f" . consult-fd)
         ("M-y" . consult-yank-pop)
         ("C-x r b" . consult-bookmark))
  :custom
  (consult-narrow-key "<")

  (consult-preview-key '(:debounce 0.2 any))
  :config
  ;; Alphabetical by path (rg then runs single-threaded; slower on huge trees).
  (setq consult-ripgrep-args (concat consult-ripgrep-args " --sort path")))

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)
         ;; F7: searchable cheatsheet of every key active right now (built-in,
         ;; mode and mine), read from the live keymaps, so it cannot go stale.
         ("<f7>" . embark-bindings))
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  (embark-quit-after-action '((kill-buffer . nil))))

(use-package embark-consult
  :hook (embark-collect-mode . consult-preview-at-point-mode))

(use-package wgrep :defer t :custom (wgrep-auto-save-buffer t))
