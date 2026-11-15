;; -*- lexical-binding: t; -*-

;; The document language, not the keyboard layout: it decides hyphenation and,
;; with the vendored patch, whether Typst is told `dir: rtl` so that a numbered
;; heading in a Hebrew sefer aligns to the right margin like the text under it.
(setq org-export-default-language "he")
