;; -*- lexical-binding: t; -*-
(defvar my/vendor-dir (expand-file-name "vendor" my/repo-root)
  "Packages committed into this repository, so a clone needs no network.")

(defvar my/autoloaded nil
  "Packages whose autoloads have been read, so each card is read once.")

(defun my/library-directory (name)
  "Return the directory holding package NAME, or nil.

Vendored packages first, then the shared =elpa/= directory, whose package
directories carry a version suffix."
  (let ((vendored (expand-file-name name my/vendor-dir))
        (installed (and (boundp 'package-user-dir)
                        (stringp package-user-dir)
                        (car (file-expand-wildcards
                              (expand-file-name (concat name "-*")
                                                package-user-dir)
                              t)))))
    (cond ((file-directory-p vendored) vendored)
          ((and installed (file-directory-p installed)) installed))))

(defun my/autoload (name)
  "Make NAME's commands known without loading its code.

Reads only NAME-autoloads.el, which registers the commands and puts the package
directory on `load-path'; the code itself is loaded the first time one of those
commands runs.

Fails loudly when NAME is absent. A package that is simply not there must not
surface an hour later as a void-function in the middle of writing."
  (unless (member name my/autoloaded)
    (let ((dir (my/library-directory name)))
      (unless dir
        (error "Package %s is not installed: no %s in %s and nothing matching %s-* in %s"
               name (expand-file-name name my/vendor-dir) my/vendor-dir
               name (if (boundp 'package-user-dir) package-user-dir "elpa/")))
      (let ((autoloads (expand-file-name (concat name "-autoloads.el") dir)))
        (unless (file-readable-p autoloads)
          (error "Package %s has no %s-autoloads.el (looked in %s)"
                 name name dir))
        (load autoloads nil 'nomessage)
        (push name my/autoloaded)))
    t))
