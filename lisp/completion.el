;;; completion.el --- minibuffer and in-buffer completion -*- lexical-binding: t; -*-
;; The standard vertico stack, configured the documented way.

(use-package vertico
  :init (vertico-mode 1)
  :custom (vertico-count 15) (vertico-resize nil))

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
  (consult-preview-key '(:debounce 0.2 any)))

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)
         ("C-h B" . embark-bindings))
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  (embark-quit-after-action '((kill-buffer . nil))))

(use-package embark-consult
  :hook (embark-collect-mode . consult-preview-at-point-mode))

(use-package wgrep :custom (wgrep-auto-save-buffer t))

(use-package helpful
  :bind (([remap describe-function] . helpful-callable)
         ([remap describe-command] . helpful-command)
         ([remap describe-variable] . helpful-variable)
         ([remap describe-key] . helpful-key)))
