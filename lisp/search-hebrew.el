;;; search-hebrew.el --- niqqud-insensitive search and completion -*- lexical-binding: t; -*-
;; Each Hebrew letter may be followed by niqqud/cantillation points.

(defconst my/niqqud "[\u0591-\u05C7]*")
(defun my/hebrew-niqqud-regexp (string)
  "Regexp for STRING that ignores niqqud, or nil if it has no Hebrew letters."
  (when (string-match-p "[\u05D0-\u05EA]" string)
    (mapconcat (lambda (c)
                 (concat (regexp-quote (char-to-string c))
                         (if (<= #x05D0 c #x05EA) my/niqqud "")))
               string "")))

(defun my/isearch-niqqud-fun (orig &rest args)
  (let ((f (apply orig args)))
    (lambda (string &optional bound noerror count)
      (if-let* ((rx (and (not isearch-regexp) (my/hebrew-niqqud-regexp string))))
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
                    (mapconcat (lambda (c)
                                 (concat (regexp-quote (char-to-string c))
                                         (if (memq c '(?ו ?י)) "?" "")
                                         my/niqqud))
                               pattern "")))))
  (add-to-list 'orderless-style-dispatchers #'my/orderless-hebrew))
