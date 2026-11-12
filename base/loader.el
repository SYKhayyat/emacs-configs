;; -*- lexical-binding: t; -*-
(require 'subr-x)

;; Bound by the ten-line bootstrap in each profile directory.
(defvar my/config-dir)
(defvar my/repo-root)
(defvar my/profile)

(defvar my/load-times nil
  "Modules loaded, as (filename . milliseconds); filled only under MY_BENCH.")
(declare-function my/mark "bench" (label))
(declare-function my/report "bench" ())

(defun my/load (file)
  "Load FILE, recording how long it took when bench.el is loaded."
  (if (boundp 'my/marks)
      (let ((t0 (float-time)))
        (load file nil 'nomessage)
        (push (cons (file-name-nondirectory file) (* 1000 (- (float-time) t0)))
              my/load-times))
    (load file nil 'nomessage)))

(defun my/bench-mark (label)
  "Record a milestone for bin/bench.sh, or do nothing in a normal run."
  (when (boundp 'my/marks)
    (my/mark label)))

(defun my/load-manifest (dir)
  "Load the files named in DIR/MANIFEST, in the order listed.

Blank lines and lines beginning with # are ignored. A missing MANIFEST is not
an error: it means the directory has nothing to contribute."
  (let ((manifest (expand-file-name "MANIFEST" dir)))
    (when (file-readable-p manifest)
      (with-temp-buffer
        (insert-file-contents manifest)
        (goto-char (point-min))
        (while (re-search-forward "^[[:alnum:]_].*$" nil t)
          (my/load (expand-file-name (string-trim (match-string 0)) dir)))))))

(my/bench-mark "1 early-init done")

(my/load-manifest (expand-file-name "base" my/repo-root))
(my/bench-mark "2 base modules done")

(my/load-manifest (expand-file-name "modules" my/config-dir))
(my/bench-mark "3 profile modules done")

(when (getenv "MY_BENCH")
  (my/report))
