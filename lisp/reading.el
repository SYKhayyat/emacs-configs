;;; reading.el --- PDF and epub -*- lexical-binding: t; -*-

(use-package pdf-tools
  :magic ("%PDF" . pdf-view-mode)
  :config (pdf-tools-install :no-query))
(use-package nov :mode ("\\.epub\\'" . nov-mode))
