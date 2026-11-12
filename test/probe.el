;; -*- lexical-binding: t; -*-
;;; probe.el --- what a GUI launch is allowed to say: nothing -*- lexical-binding: t; -*-
;; Loaded last by bin/gui-test.sh. It prints nothing at all; it records what it
;; found into $MY_PROBE_OUT and exits. Any other output from a GUI run is a
;; fault, and bin/check.sh treats it that way.
;;
;; The cookie on line 1 is mandatory: without it Emacs prints a
;; "Missing ‘lexical-binding’ cookie" warning, which is exactly the sort of
;; unexplained output that makes a test worthless.

(defconst my-probe-wait (string-to-number (or (getenv "MY_PROBE_WAIT") "2.6"))
  "Seconds to wait before sampling, so the deferred modes have started.")

(defconst my-probe-out (or (getenv "MY_PROBE_OUT") "/tmp/gui-probe.txt")
  "File to write the sample to.")

(run-with-timer
 my-probe-wait nil
 (lambda ()
   (with-temp-file my-probe-out
     (insert (format "profile=%s\n" my/profile))
     (insert (format "graphic=%S\n" (display-graphic-p)))
     (insert (format "frame=%dx%d\n" (frame-width) (frame-height)))
     (insert (format "gc=%d\nhandlers=%d\n"
                     gc-cons-threshold (length file-name-handler-alist)))
     (insert (format "delsel=%S\nso-long=%S\nwhich-key=%S\n"
                     (and (bound-and-true-p delete-selection-mode) t)
                     (and (bound-and-true-p global-so-long-mode) t)
                     (and (bound-and-true-p which-key-mode) t)))
     (insert (format "init=%s\n" (emacs-init-time))))
   ;; `message' output in a GUI session goes to the echo area, not to stderr,
   ;; so stderr alone cannot prove a GUI run was silent. The messages log is
   ;; the only place that sees it.
   (with-temp-file (concat my-probe-out ".messages")
     (insert (if (get-buffer "*Messages*")
                 (with-current-buffer "*Messages*" (buffer-string))
               "")))
   (kill-emacs)))
