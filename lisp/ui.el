;;; ui.el --- theme and fonts, nothing that costs per redisplay -*- lexical-binding: t; -*-
(defvar my/profile)

(setq modus-themes-italic-constructs t)
(load-theme 'modus-operandi t)

;; Hebrew glyphs from one fixed family, so Emacs does not search fonts per run.
;; Every profile: notes and code contain Hebrew too.
(set-fontset-font t 'hebrew (font-spec :family "Noto Serif Hebrew"))
