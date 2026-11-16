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
         ("C-h B" . embark-bindings))
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  (embark-quit-after-action '((kill-buffer . nil))))

(use-package embark-consult
  :hook (embark-collect-mode . consult-preview-at-point-mode))

(use-package wgrep :defer t :custom (wgrep-auto-save-buffer t))

(use-package helpful
  :bind (([remap describe-function] . helpful-callable)
         ([remap describe-command] . helpful-command)
         ([remap describe-variable] . helpful-variable)
         ([remap describe-key] . helpful-key)))
