;;; build.el --- tangle the literate config, compile it, prove it is current  -*- lexical-binding: t; -*-
;; Run:  bin/build.sh          tangle + byte-compile everything
;;       bin/build.sh --check  fail if any .el is not what its .org tangles to

(defconst build/root
  (expand-file-name "../" (file-name-directory (or load-file-name buffer-file-name)))
  "Root of the emacs-configs checkout.")

(defconst build/profiles '("hebrew" "notes" "ide"))

(defun build/org-files ()
  "Every literate source in the repository, base first."
  (append
   (directory-files (expand-file-name "base" build/root) t "\\.org\\'")
   (mapcan (lambda (profile)
             (let ((dir (expand-file-name (concat "configs/" profile "/modules")
                                          build/root)))
               (when (file-directory-p dir)
                 (directory-files dir t "\\.org\\'"))))
           build/profiles)))

(defun build/el-for (org)
  "The generated .el file for ORG, next to it, same basename."
  (concat (file-name-sans-extension org) ".el"))

(defun build/tangled-text (org)
  "The text tangling ORG yields, without touching the checked-in file.

ORG is copied into a fresh temporary directory first, so the tangle target
(./name.el) and anything relative resolve there.  Tangling in place is not
an option: org-babel skips writing an unchanged file, which is precisely the
case where comparing timestamps lies."
  (let* ((tmp (make-temp-file "build-check-" t))
         (copy (expand-file-name (file-name-nondirectory org) tmp)))
    (unwind-protect
        (progn
          (copy-file org copy)
          (let ((default-directory (file-name-directory copy))
                (inhibit-message t))
            (org-babel-tangle-file copy))
          (let ((made (concat (file-name-sans-extension copy) ".el")))
            (if (file-exists-p made)
                (with-temp-buffer
                  (insert-file-contents made)
                  (buffer-string))
              (format "MISSING TANGLE OUTPUT for %s" org))))
      (delete-directory tmp t))))

(defun build/stale-p (org)
  "Non-nil when ORG's generated file is missing or differs from what ORG tangles to.

Content, not timestamps: a documentation-only edit to a .org leaves the .el
byte-identical, and calling that stale makes the check cry wolf every time the
prose is improved."
  (let ((el (build/el-for org)))
    (or (not (file-exists-p el))
        (not (string= (with-temp-buffer (insert-file-contents el) (buffer-string))
                      (build/tangled-text org))))))

(defun build/tangle (org)
  "Tangle ORG to its declared target, then report what appeared."
  (org-babel-tangle-file org)
  (let ((el (build/el-for org)))
    (unless (file-exists-p el)
      (error "Tangling %s produced no %s (missing :tangle header?)"
             org (file-name-nondirectory el)))
    (princ (format "  tangled  %s\n" (file-relative-name el build/root)))
    el))

(defun build/compile (el)
  "Byte-compile EL, reporting warnings rather than hiding them."
  (let ((byte-compile-warnings '(not docstrings)))
    (with-temp-buffer
      (setq byte-compile-dest-file-function nil)
      (byte-compile-file el))))

(defun build/main ()
  (let ((check (member "--check" command-line-args-left)))
    (require 'org)
    ;; `byte-compile-warnings' must exist (as a special variable) before it is
    ;; let-bound below, or the binding is lexical and bytecomp errors out.
    (require 'bytecomp)
    (if check
        (let ((bad (seq-filter #'build/stale-p (build/org-files))))
          (if bad
              (progn
                (princ "Stale generated files (run bin/build.sh):\n")
                (dolist (org bad)
                  (princ (format "  %s\n" (file-relative-name org build/root))))
                (kill-emacs 1))
            (princ "All generated files are current.\n")))
      (dolist (org (build/org-files))
        (build/compile (build/tangle org)))
      (princ (format "\nTangled and compiled %d files.\n"
                     (length (build/org-files)))))))

(build/main)
