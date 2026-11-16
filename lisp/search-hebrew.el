;;; search-hebrew.el --- niqqud-insensitive search and completion -*- lexical-binding: t; -*-
;; Each Hebrew letter may be followed by niqqud/cantillation points.

(defconst my/niqqud "[\u0591-\u05C7]*")
(defconst my/hebrew-vav-yod "[\u05D5\u05D9\u0591-\u05C7]*"
  "Any run of vav, yod and niqqud, so plene and defective spellings find each other.")
(defun my/hebrew-niqqud-regexp (string)
  "Regexp for STRING that ignores niqqud, or nil if it has no Hebrew letters.
Whitespace in STRING matches any run of whitespace, as in a normal isearch."
  (when (string-match-p "[\u05D0-\u05EA]" string)
    (mapconcat (lambda (c)
                 (cond ((memq c '(?\s ?\t ?\n)) "[ \t\n]+")
                       ((<= #x05D0 c #x05EA) (concat (regexp-quote (char-to-string c)) my/niqqud))
                       (t (regexp-quote (char-to-string c)))))
               string "")))

(defun my/isearch-niqqud-fun (orig &rest args)
  (let ((f (apply orig args)))
    (lambda (string &optional bound noerror count)
      (if-let* ((rx (and (not isearch-regexp) (not isearch-regexp-function)
                         (my/hebrew-niqqud-regexp string))))
          (funcall (if isearch-forward #'re-search-forward #'re-search-backward)
                   rx bound noerror count)
        (funcall f string bound noerror count)))))
(advice-add 'isearch-search-fun-default :around #'my/isearch-niqqud-fun)

(with-eval-after-load 'orderless
  (defun my/orderless-hebrew (pattern _i _n)
    "All-Hebrew PATTERN matches regardless of niqqud and vav/yod spelling."
    (when (string-match-p "\\`[\u05D0-\u05EA]+\\'" pattern)
      (cons 'orderless-regexp
            (concat my/niqqud
                    ;; A vav/yod may sit between any two typed letters (and
                    ;; typed ones are optional), so דוד and דויד find each other.
                    (mapconcat (lambda (c)
                                 (if (memq c '(?ו ?י))
                                     (concat (regexp-quote (char-to-string c)) "?" my/niqqud)
                                   (concat (regexp-quote (char-to-string c)) my/hebrew-vav-yod)))
                               pattern "")))))
  (add-to-list 'orderless-style-dispatchers #'my/orderless-hebrew))
