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

(defun keys-report (profile)
  (let ((now (keys--collect global-map [] nil)) rows)
    (dolist (e now)
      (let ((old (gethash (car e) keys--before)))
        (unless (or (equal old (cdr e))
                    ;; Emacs's own kmacro map, expanded by loading, not by us.
                    (and (symbolp (cdr e)) (string-prefix-p "kmacro-" (symbol-name (cdr e)))))
          (push (list (car e) (cdr e) old) rows))))
    (setq rows (sort rows (lambda (a b) (string< (car a) (car b)))))
    (princ (format "Keys defined by the %s profile (%d)\n\n" profile (length rows)))
    (dolist (r rows)
      (princ (format "%-22s %-38s %s\n" (nth 0 r)
                     (let ((c (nth 1 r))) (cond ((symbolp c) (symbol-name c)) ((autoloadp c) "<prefix map>") (t "<lambda>")))
                     (keys--doc (nth 1 r)))))))
