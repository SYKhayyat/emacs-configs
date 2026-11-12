;;; build.el --- tangle the literate config, compile it, prove it is current  -*- lexical-binding: t; -*-
;; Run:  bin/build.sh          tangle + byte-compile everything
;;       bin/build.sh --check  fail if any .el is older than its .org

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

(defun build/stale-p (org)
  "Non-nil when ORG's generated file is missing or older than ORG."
  (let ((el (build/el-for org)))
    (or (not (file-exists-p el))
        (file-newer-than-file-p org el))))

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
