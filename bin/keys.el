;;; keys.el --- list the global keys this profile defines -*- lexical-binding: t; -*-
;; Run through bin/keys. Loads early-init, takes a snapshot of the global keymap,
;; loads the profile, and prints every key whose binding the profile changed.

(defvar keys--before nil)

(defun keys--collect (map prefix acc)
  "Push (KEYDESC . COMMAND) for every binding in MAP below PREFIX onto ACC."
  (when (and (symbolp map) (symbol-function map) (autoloadp (symbol-function map)))
    ;; A prefix map not loaded yet: list the prefix itself, not its contents.
    (push (cons (key-description prefix) map) acc)
    (setq map nil))
  (when map (map-keymap
   (lambda (ev b)
     (let ((k (vconcat prefix (vector ev))))
       (unless (memq (aref k 0) '(menu-bar tool-bar tab-bar header-line mode-line remap
                                 mouse-1 mouse-2 mouse-3 down-mouse-1 down-mouse-2 down-mouse-3
                                 wheel-up wheel-down))
         (cond ((autoloadp b) (push (cons (key-description k) b) acc))
               ((keymapp b) (setq acc (keys--collect b k acc)))
               ((and (consp b) (stringp (car b)) (not (symbolp b))) nil) ; menu item
               (b (push (cons (key-description k) b) acc))))))
   (if (symbolp map) (symbol-function map) map)))
  acc)

(defun keys--snapshot ()
  (let ((h (make-hash-table :test 'equal)))
    (dolist (e (keys--collect global-map [] nil)) (puthash (car e) (cdr e) h))
    h))

(defun keys--doc (cmd)
  (cond ((autoloadp cmd) "")
        ((symbolp cmd)
         (let ((d (ignore-errors (documentation cmd t))))
           (if (and d (> (length d) 0)) (car (split-string d "\n")) "")))
        ((functionp cmd) "(anonymous command)")
        (t "")))

(defun keys--line (key cmd)
  (format "%-22s %-38s %s\n" key
          (cond ((symbolp cmd) (symbol-name cmd)) ((autoloadp cmd) "<prefix map>") (t "<lambda>"))
          (keys--doc cmd)))

(defun keys-report (profile)
  "Print this profile's keys first, then the rest of the global keymap."
  (let ((now (sort (keys--collect global-map [] nil)
                   (lambda (a b) (string< (car a) (car b)))))
        mine builtin)
    (dolist (e now)
      (if (or (equal (gethash (car e) keys--before) (cdr e))
              ;; Emacs's own kmacro map, expanded by loading, not by us.
              (and (symbolp (cdr e)) (string-prefix-p "kmacro-" (symbol-name (cdr e)))))
          (push e builtin)
        (push e mine)))
    (princ (format "== Defined by the %s profile (%d) ==\n\n" profile (length mine)))
    (dolist (e (nreverse mine)) (princ (keys--line (car e) (cdr e))))
    (princ (format "\n== Built-in Emacs, global keymap (%d) ==\n\n" (length builtin)))
    (dolist (e (nreverse builtin)) (princ (keys--line (car e) (cdr e))))))
