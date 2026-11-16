;;; hydras.el --- hydra menus for writing and tabs -*- lexical-binding: t; -*-
;; Needs: my/toggle-reading-room (writing.el), the helpers in navigation.el.

(use-package hydra
  :commands defhydra
  :config
  (defhydra hydra-writing (:color blue :hint nil)
    "
Writing:  w: reading room   W: set width"
    ("w" my/toggle-reading-room)
    ("W" olivetti-set-width)
    ("q" nil))
  (defhydra hydra-tabs (:color pink :hint nil)
    "
_n_ new  _x_ close  _]_ next  _[_ prev  _r_ rename  _s_ project → tab
_b_ buffer  _d_ kill buffer  _o_ kill others  _g_ ibuffer  _1_.._9_ jump"
    ("n" tab-bar-new-tab) ("x" tab-bar-close-tab)
    ("]" tab-bar-switch-to-next-tab) ("[" tab-bar-switch-to-prev-tab)
    ("r" tab-bar-rename-tab :color blue)
    ("s" my/project-in-new-tab :color blue)
    ("1" (tab-bar-select-tab 1)) ("2" (tab-bar-select-tab 2))
    ("3" (tab-bar-select-tab 3)) ("4" (tab-bar-select-tab 4))
    ("5" (tab-bar-select-tab 5)) ("6" (tab-bar-select-tab 6))
    ("7" (tab-bar-select-tab 7)) ("8" (tab-bar-select-tab 8))
    ("9" (tab-bar-select-tab 9))
    ("b" consult-buffer :color blue)
    ("d" my/kill-current-buffer) ("o" my/kill-other-buffers)
    ("g" ibuffer :color blue) ("q" nil :color blue)))
;; hydra is lazy, so the keys that open these load it first.
(keymap-global-set "C-c W" (lambda () (interactive) (require 'hydra) (hydra-writing/body)))
(keymap-global-set "C-c T" (lambda () (interactive) (require 'hydra) (hydra-tabs/body)))
