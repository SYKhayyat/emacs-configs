;;; reading.el --- PDF, epub, local AI -*- lexical-binding: t; -*-

(use-package pdf-tools
  :magic ("%PDF" . pdf-view-mode)
  :config (pdf-tools-install :no-query))
(use-package nov :mode ("\\.epub\\'" . nov-mode))

(use-package gptel
  :bind (("C-c g g" . gptel) ("C-c g s" . gptel-send) ("C-c g m" . gptel-menu))
  :config
  (setq gptel-model 'llama3
        gptel-backend (gptel-make-ollama "Ollama" :host "localhost:11434"
                                         :stream t :models '(llama3))))
