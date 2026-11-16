;;; ai.el --- local LLM through Ollama -*- lexical-binding: t; -*-

(use-package gptel
  :bind (("C-c g g" . gptel) ("C-c g s" . gptel-send) ("C-c g m" . gptel-menu))
  :config
  (setq gptel-model 'llama3
        gptel-backend (gptel-make-ollama "Ollama" :host "localhost:11434"
                                         :stream t :models '(llama3))))
