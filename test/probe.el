;; -*- lexical-binding: t; -*-
;;; probe.el --- what a GUI launch is allowed to say: nothing -*- lexical-binding: t; -*-
;; Loaded last by bin/gui-test.sh. It prints nothing at all; it records what it
;; found into $MY_PROBE_OUT and exits. Any other output from a GUI run is a
;; fault, and bin/check.sh treats it that way.
;;
;; The cookie on line 1 is mandatory: without it Emacs prints a
;; "Missing ‘lexical-binding’ cookie" warning, which is exactly the sort of
;; unexplained output that makes a test worthless.
;;
;; Input is not the configuration. On this machine wheel and touch events reach
;; the private Xvfb frame from outside Emacs about one run in four — measured:
;; `mwheel-scroll' on *scratch* at point 1, which prints "Beginning of buffer",
;; "End of buffer" when someone scrolls the frame. A check that failed on that
;; was failing on the machine's pointer, not on the configuration, and it hid
;; the fault it exists to find. So the messages log is attributed: what the
;; configuration printed is the log as it stood at the moment the first command
;; ran; anything after that arrived because a key, a wheel or a touch was
;; delivered, and is recorded but not judged.

(defconst my-probe-wait (string-to-number (or (getenv "MY_PROBE_WAIT") "30.0"))
  "Seconds after init ends to sample even if the deferred modes are still off.
Sampling waits for them (see below), so this is a deadline, not a delay, and a
generous one costs nothing: a healthy run samples the moment the modes appear.

The period is counted from `emacs-startup-hook', not from the moment this file
is loaded, because this file is read while init is still running and a deadline
measured from load time is partly spent before the configuration has finished.

Why 30 s, after 6 s failed on a loaded host. The modes come from
`my/schedule-idle-modes' in `base/core.org': a 1 s idle timer plus a 3.0 s
wall-clock fallback. Traced on a machine at load average 10-18, the fallback is
what fires, and the poll below is serviced late as well — one traced run saw
only three polls in 3.5 s, then the modes on at +3.56 s. So the modes are never
missing; the clock was. A 6 s deadline failed 1 run in 4, and raising
it to 20 s made 6 of 6 pass. Whatever else was short, it was not the config.

This deadline is a backstop, not the mechanism: a run that trips it fails
anyway, and a wider one only makes such a failure mean what it says.")

(defconst my-probe-out (or (getenv "MY_PROBE_OUT") "/tmp/gui-probe.txt")
  "File to write the sample to.")

(defun my-probe-messages-string ()
  "The `*Messages*' log as a string, or an empty string."
  (if (get-buffer "*Messages*")
      (with-current-buffer "*Messages*" (buffer-string))
    ""))

(defvar my-probe-first-command nil
  "Non-nil once a command has run, i.e. once input has been delivered.")

(defvar my-probe-config-messages nil
  "The messages log at the first command; nil while no input has arrived.")

(defun my-probe-note-command ()
  "Record the messages log the moment the first command runs."
  (unless my-probe-first-command
    (setq my-probe-first-command t)
    (setq my-probe-config-messages (my-probe-messages-string))))

(add-hook 'pre-command-hook #'my-probe-note-command)

(defun my/probe-modes-ready-p ()
  "Non-nil when the three modes deferred to a timer are all on."
  (and (bound-and-true-p delete-selection-mode)
       (bound-and-true-p global-so-long-mode)
       (bound-and-true-p which-key-mode)))

(defun my/probe-sample ()
  "Record the sample, the messages log, and exit."
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
    (insert (format "init=%s\n" (emacs-init-time)))
    ;; Whether input arrived, so bin/check.sh can say which claim it checked.
    (insert (format "input=%s\n" (if my-probe-first-command "yes" "no"))))
  ;; `message' output in a GUI session goes to the echo area, not to stderr,
  ;; so stderr alone cannot prove a GUI run was silent. The messages log is
  ;; the only place that sees it.
  (with-temp-file (concat my-probe-out ".messages")
    (insert (my-probe-messages-string)))
  ;; The log up to the first input event: this is the configuration's own
  ;; output, and the only part of it that bin/check.sh judges.
  (with-temp-file (concat my-probe-out ".messages.config")
    (insert (or my-probe-config-messages (my-probe-messages-string))))
  (kill-emacs))

(defun my/probe-await-modes (deadline)
  "Sample as soon as the deferred modes are on, or at DEADLINE at the latest.
Waiting for the condition, rather than sleeping a fixed time, is what makes
this check measure the configuration instead of the machine's load. The modes
themselves have an idle timer and a 3.0 s wall-clock fallback; sampling at a
fixed 2.6 s raced the fallback and failed about half the time on a busy
machine while proving nothing about the config."
  (if (or (my/probe-modes-ready-p) (<= deadline (float-time)))
      (my/probe-sample)
    (run-with-timer 0.1 nil #'my/probe-await-modes deadline)))

(defun my/probe-start-waiting ()
  "Begin the wait for the deferred modes, once init is over.

Counted from here, and stretched by init time: a machine that needed 2.8 s for
init is slow enough to need more than 3 s afterwards for a wall-clock timer to
be serviced, and a fixed deadline turned that into a failure naming the wrong
cause."
  (let* ((init-seconds (or (and (boundp 'emacs-init-time)
                                (string-to-number emacs-init-time))
                           0))
         (budget (+ my-probe-wait init-seconds)))
    (run-with-timer 0 nil #'my/probe-await-modes (+ (float-time) budget))))

;; Armed from the startup hook, never from load time: this file is read while
;; init is still running, so a deadline that starts here is partly spent before
;; the configuration has finished loading.
;;
;; A batch run never fires `emacs-startup-hook' at all under `-Q --batch
;; --eval' (verified), and a daemon has already finished its init, so both wait
;; from load time and keep the old behaviour.
(if (or noninteractive (daemonp))
    (run-with-timer 0 nil #'my/probe-await-modes (+ (float-time) my-probe-wait))
  (add-hook 'emacs-startup-hook #'my/probe-start-waiting))
