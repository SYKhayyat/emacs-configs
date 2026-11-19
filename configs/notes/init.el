;;; init.el --- notes profile: English Org/Markdown, no Hebrew machinery -*- lexical-binding: t; -*-
;; Same as hebrew minus rtl and search-hebrew (and the Hebrew font in ui.el).
;; `bidi' is here because a Hebrew sentence pasted into an English note is not
;; hypothetical, and "the paragraph started with English" is not an answer to it.
(my/load-modules
 '(core files bidi ui completion editing navigation terminal prose writing footnotes export ai))
