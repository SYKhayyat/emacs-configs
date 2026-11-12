;; -*- lexical-binding: t; -*-
(defvar my/marks nil
  "Milestones as (label . milliseconds-since-process-start).")

(defvar my/load-times nil
  "Modules loaded, as (filename . milliseconds).")

(defun my/mark (label)
  "Record LABEL with the milliseconds elapsed since this process started."
  (push (cons label (* 1000 (float-time (time-subtract
                                         (current-time) before-init-time))))
        my/marks))

(defun my/report ()
  "Print the price table: phases, modules, and the total."
  (princ (format "\n  %-34s %7s\n" "phase" "ms"))
  (dolist (row (reverse my/marks))
    (princ (format "  %-34s %7.1f\n" (car row) (cdr row))))
  (dolist (row (reverse my/load-times))
    (princ (format "    loaded %-25s %7.1f\n" (car row) (cdr row))))
  (when (fboundp 'my/start-idle-modes)
    (let ((t0 (float-time)))
      (my/start-idle-modes)
      (princ (format "    idle modes (so-long+delsel+which-key)%5.1f\n"
                     (* 1000 (- (float-time) t0))))))
  (princ (format "  %-34s %7.1f\n" "TOTAL (process start → here)"
                 (* 1000 (float-time (time-subtract (current-time)
                                                    before-init-time))))))
