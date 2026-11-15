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
vendor/olivetti/             vendored centred column, SOURCE.md, no patch needed
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
- Hebrew in the buffer (stage 2, done): `bidi-paragraph-direction` is nil in
  the base for **all three profiles** — no direction is forced anywhere. The
  first character of the sefer is drawn at x=1259 of a 1260 px body instead of
  x=219. Wrapping is base policy (C15): no profile cuts long lines at the edge
  any more. Cost on the sefer: 3.8–4.4 / 5.0–5.7 / 2.4–3.1 ms per line scroll /
  half page / keystroke.
- The 10× trap, measured both ways and reversible (A/B/A in one session: 43.4 /
  4.0 / 4.2 / 4.1 ms). Forcing a direction costs nothing while the direction
  matches the text (forced `right-to-left` on Hebrew: 4.2 ms) and costs 10×
  when it does not: forced `left-to-right` on the wrapped sefer is
  **43.4 / 49.7 / 17.1 ms**, and forced `right-to-left` on a wrapped 400 KB
  English file is **63.4 / 72.0 / 89.6 ms**. `bidi-inhibit-bpa` and
  font-lock-off controls change nothing (44.1 / 44.9 ms). With truncation on,
  all three directions are 4.0–4.5 ms — the trap needs wrapping. Hence: never
  force, and A11 in `base/core.org` carries the table. Reproduced twice more,
  five interleaved rounds each with the direction order rotated per round
  (medians): another sefer, 340 KB with 358 notes — forced `left-to-right`
  286 ms a line against 8.1 ms, 96 against 8.0 per keystroke; the 400 KB
  English file — forced `right-to-left` 163 ms against 3.3 ms, 90 against 4.5.
  "10×" is the floor; it is 35× and 50× on those two.
- Footnote definitions under nil: an org definition starts with the Latin
  `[fn:label]`, so it is a left-to-right paragraph — label at x=7, and the
  caret costs **38.4 ms** per character typed, because it is a wrapped Hebrew
  paragraph the bidi base disagrees with. `configs/hebrew/modules/display.org`
  puts a `display` overlay over each visible label (replaced text is not
  counted when Emacs picks a paragraph's direction), which makes the definition
  RTL: label at x=1259 of 1260, direction `right-to-left`, caret 6.8 ms — the
  same as with no label at all. Cost of the hook: 0.032 ms per idle command,
  0.069 ms when it rebuilds 11 overlays; scrolling unchanged (10.7 ms with and
  without); buffer never modified; `org-export-as` output byte-identical with
  and without the overlays. Not possible: per-paragraph direction from Lisp —
  `bidi-paragraph-start-regexp` and `bidi-paragraph-separate-regexp` were
  measured and change nothing (label still at x=7).
- Reading room: `C-c w` toggles the vendored `olivetti` at 100 columns. First
  press 12.6 ms load + 94.5 ms re-layout, later toggles ~8 ms, redisplay
  unchanged (3.4–4.4 / 5.4–7.2 / 3.2–3.7 ms). It recalculates per window on a split without
  any code of ours (60-column body: 13 columns each side in a split half, 59 in
  a full frame).
- Cursor: nothing set, deliberately. `C-p`/`C-n` are visual by default;
  `C-f`/`C-b` are logical by design and no variable changes that;
  `right-char` is already visual in Hebrew. `visual-order-cursor-movement`
  changes neither the landing position nor the price here (0.35 ms vs 0.19 ms
  per 200 presses) and is left nil.

Not verified: any macOS or Windows run (comtai #5), and one unexplained
`End of buffer` message in an ide GUI check (comtai #6). GUI checks run on Xvfb;
real measurements run on headless `sway`, because the user is on Wayland and X
numbers do not transfer.

## The three requests from the end of stage 1

Three were asked; the third is now done (see the buffer entries above). The two
remaining are measured only as far as the paragraph below:

1. **Unlimited heading depth.** Untested whether org, or the exporter, actually
   stops at some depth. Nothing in the repo caps it today.
2. **Deep list nesting.** Same: no cap written anywhere, untested in practice.
3. ~~**Hebrew perfection in the buffer**~~ — RTL text, cursor, centred column.
   Done: `configs/hebrew/modules/display.org`, plus C15 in `base/core.org`.

Open question 3 is **done** — see the buffer entries under "Done and verified".
The base sets `bidi-paragraph-direction` to nil for every profile (A11) and
**deliberately leaves `bidi-display-reordering` alone**; the hebrew profile's
`configs/hebrew/modules/display.org` owns the footnote-label fix, the cursor
notes and the reading room. `test/invariants.el` now expects nil for all three
profiles — the per-profile expectation is how the missing RTL fix once hid — and
asserts, in the hebrew profile, that a footnote definition is *left*-to-right
without the labels and `right-to-left` with them, so the check cannot pass on a
broken hook. `fill-column` is still 70 and `line-move-visual` is still Emacs's
default.

Still open in stage 2: unlimited heading depth, and deep list nesting.

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

1. Finish stage 2: the buffer work (RTL, wrapping, cursor, centred column) is
   in and checked. What remains is unbounded heading and list depth if anything
   caps them, and the first Windows/macOS run.
2. Stage 3 `emacs-notes`.
3. Stage 4 `emacs-ide`.
4. Stage 5: old-config triage, bit by bit, each item priced.
5. First run on Windows/macOS before calling any stage finished.
