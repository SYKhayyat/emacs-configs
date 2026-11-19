;;; profiles.el --- which modules each profile loads -*- lexical-binding: t; -*-
;; The one place a profile is defined. configs/<profile>/ holds only the two
;; init files Emacs looks for, both one form long, so the three cannot drift.
;;
;; notes is hebrew minus `rtl' and `search-hebrew'. `bidi' is in notes because a
;; Hebrew sentence pasted into an English note is not hypothetical, and "the
;; paragraph started with English" is not an answer to it.

(defconst my/profile-modules
  '((hebrew core files bidi ui completion editing navigation terminal
            prose writing footnotes rtl search-hebrew export ai)
    (notes  core files bidi ui completion editing navigation terminal
            prose writing footnotes export ai)
    (ide    core files bidi ui completion editing navigation terminal
            writing ide vcs ai))
  "Profile name → the lisp/ modules it loads, in order.")
