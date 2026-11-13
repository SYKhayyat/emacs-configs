# Handoff

State of this repository at commit `389f807`, written so the next session does
not have to rediscover any of it.

## What this is

A rebuild of the user's Emacs configuration as three lightweight profiles on one
shared base, inside a single repo, with no Nix and no network at load time. A
`git clone` plus `bin/emacs-<profile>` has to work on Linux, macOS and Windows.

| profile | for | state |
|---|---|---|
| `hebrew` | Hebrew org writing and reading, one PDF export path | usable; reading, export, footnotes done |
| `notes` | English writing and reading | base only |
| `ide` | Rust/TS/JS/Python/Java/Common Lisp | base only |

**Governing rule:** as fast as it can be while still usable. Cosmetic work —
syntax colouring, font choice, decoration — is off by default, and anything
added has to arrive with a measured price and an explicit yes.

## The stages, in order

The work is five stages, and it stays in this order: nothing later is started
while an earlier one is unfinished.

1. **Base** — the shared performance base every profile inherits: startup,
   GC, files, keys that annoy, the loader and its `MANIFEST`. **Done.**
2. **Hebrew notes** (`hebrew`) — Hebrew org writing and reading, one export
   path. Reading, export and footnotes are done and measured; the Hebrew buffer
   work (cursor direction, RTL movement, centred column) is the open part.
   **In progress** (comtai #1).
3. **English notes** (`notes`) — English writing and reading, footnotes, basic
   headings and lists, one export path. **Not started** (comtai #2). The
   footnote settings currently live in the hebrew profile and move to the shared
   base here, once two profiles want them.
4. **IDE** (`ide`) — Rust/TS/JS/Python/Java/Common Lisp, faster and lighter than
   Kate or Zed. **Not started** (comtai #3).
5. **Triage of the old config** (`emacs-config-deprecated`) — go through it
   **bit by bit**, and for each piece decide keep or drop, with the price of
   keeping it. **Not started** (comtai #4). Nothing from the old config is
   migrated before this stage; that is what keeps the new tree small.

## How it fits together

```
bin/build.sh                 tangle every .org to its .el, byte-compile, or --check
bin/check.sh                 the whole proof: build, 3 profiles batch + GUI, export, footnotes
bin/launch.sh                daemon-first launcher; bin/emacs-<profile> are thin wrappers
bin/check-export.sh          fixtures -> PDF through the vendored ox-typst
base/MANIFEST                load order for the shared base
configs/<p>/modules/MANIFEST load order per profile
vendor/ox-typst/             vendored exporter, its local patch and SOURCE.md
test/invariants.el           settings that must be in effect, per profile
test/export-*.el             export behaviour, from fixtures and from the PDF
```

Load order is a `MANIFEST` file, never filename digits, and every `.el` must be
listed in the `MANIFEST` beside it or `test/invariants.el` fails. A profile
`MANIFEST` at the profile root is an error: the loader never reads it.

## Done and verified, with the numbers

- Startup: daemon start **475–724 ms once per session**, then **79–117 ms per
  sefer**. The 2.1 s first `org-mode` was org's module `require` chain; a 0.2 s
  preload timer that actually *enters* `org-mode` in a temp buffer removes it.
- Reading a 407 KB sefer: read file 4.3 ms, `fundamental-mode` 3.8 ms, warm
  `org-mode` 36 ms, scroll a screen 16–19 ms in Hebrew / 11–13 ms in ASCII
  (Wayland). Font-lock is off everywhere in the hebrew profile.
- The old whole-buffer fontify cost (3.5–4.4 s) was one function:
  `org-activate-footnote-links` scanning back to the previous heading on a file
  with 230 footnotes and no headings. The footnote face is removed.
- Export: `C-c C-e` → Typst → PDF writes **one PDF beside the source** and
  deletes its working files. Notes are reordered into reading order on a staged
  copy first (452 ms on the 407 KB sefer, 1 ms on a 5 KB note), the sefer itself
  is never rewritten. 407 KB sefer → 77 pages, 1.4 MB.
- Footnotes: definitions are pinned to a `* Footnotes` section at the bottom;
  a geometry check reads `pdftotext -bbox` coordinates and fails a note that is
  in the flow rather than at the page bottom (measured: body at 13–21% of page
  height, notes at 89–91%).
- Hebrew in the PDF: real glyphs, right-aligned paragraphs, notes numbered
  ascending at the page bottom, and `dir: rtl` emitted so a numbered heading
  sits on the right like the text under it.

Not verified: any macOS or Windows run (comtai #5), and one unexplained
`End of buffer` message in an ide GUI check (comtai #6). GUI checks run on Xvfb;
real measurements run on headless `sway`, because the user is on Wayland and X
numbers do not transfer.

## The three open requests, not started

Asked at the end of the last session, measured only as far as the paragraph
below:

1. **Unlimited heading depth.** Untested whether org, or the exporter, actually
   stops at some depth. Nothing in the repo caps it today.
2. **Deep list nesting.** Same: no cap written anywhere, untested in practice.
3. **Hebrew perfection in the buffer** — cursor moving in the reading direction,
   RTL text, and an option to put the text in the middle (centred column).

Current bidi state, so the next session does not have to re-measure: the base
sets `bidi-paragraph-direction` to `left-to-right` and **deliberately leaves
`bidi-display-reordering` alone** (see `base/core.org`). `line-move-visual` is
still Emacs's default and `fill-column` is still 70; both were left to the
profiles that fill prose. Nothing is set for cursor direction, and there is no
centred-column option — that code does not exist yet.

Open question 3 needs one decision from the user before code: a centred column
is either (`visual-fill-column` style: text wrapped at N columns and the
margins widened, no new package), or a package such as `olivetti`. Both need a
price quoted before they go in.

## Vendor patch and upstream

`vendor/ox-typst/ox-typst.el` is upstream master plus four fixes, kept in
`upstream.patch` and documented in `SOURCE.md`:

1. escape `[` and `]` in plain text (stray bracket → `unclosed delimiter`);
2. escape backslash first (a line ending in `\` escapes the next character);
3. clamp the heading level with `(max 1 level)` (level 0 → `number must be
   positive`);
4. emit `dir: rtl` for RTL languages.

Applying `upstream.patch` to a clean clone reproduces the vendored file exactly
apart from the version header. Sent upstream as
<https://github.com/jmpunkt/ox-typst/pull/62>; the fork is
`SYKhayyat/ox-typst`. If it merges, the next re-vendor drops the patch and the
fixtures prove it — `bin/check-export.sh` is what catches a lost patch.

## Task list

`comtai ls` is the live list; the branch is the scope. #1–#4 are the five
stages, #5 first run on Windows/macOS, #6 the `End of buffer` mystery. Commit
messages say `refs comtai#1` — do **not** write `closes` for a stage task until
the stage is actually finished; that mistake was made once and had to be
reopened.

## Order of work from here

1. Finish stage 2: decide the centring question above, then price and implement
   the Hebrew buffer work (cursor/RTL/centred), then unbounded heading and list
   depth if anything caps them.
2. Stage 3 `emacs-notes`.
3. Stage 4 `emacs-ide`.
4. Stage 5: old-config triage, bit by bit, each item priced.
5. First run on Windows/macOS before calling any stage finished.
