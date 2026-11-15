# Handoff

State of this repository after stage 3, written so the next session does not
have to rediscover any of it. `git log` is the commit list; where this file and
the tree disagree, the tree is right.

## What this is

A rebuild of the user's Emacs configuration as three lightweight profiles on one
shared base, inside a single repo, with no Nix and no network at load time. A
`git clone` plus `bin/emacs-<profile>` has to work on Linux, macOS and Windows.

| profile | for | state |
|---|---|---|
| `hebrew` | Hebrew org writing and reading, one PDF export path | usable; reading, export, footnotes done |
| `notes` | English writing and reading | usable; writing, reading, export, footnotes done |
| `ide` | Rust/TS/JS/Python/Java/Common Lisp | base only; colour measured, grammars missing |

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
   headings and lists, one export path. **Built and checked** (comtai #2); the
   cross-platform run is the one thing outstanding. The footnote settings, the
   export machinery and the prose performance policy now live in the base,
   because two profiles want them (see "What stage 3 moved" below).
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
base/prose.el                colour off, footnote face, org preloaded (both prose profiles)
base/footnotes.el            notes at the bottom of the file (both prose profiles)
base/export.el               one PDF beside the source, notes ordered, depth 10
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
  sefer**. The first `org-mode` in a session is org's module `require` chain;
  a 0.2 s preload timer that actually *enters* `org-mode` in a temp buffer
  moves it out of the file open. Re-measured in stage 3, since the old 2,109 ms
  figure no longer reproduced: the chain itself is **492 ms**, and the first
  open of the 340 KB sefer is **1.47–1.54 s** without it against **0.1–0.5 s**
  with it. The preload is guarded to `hebrew` and `notes`; the ide profile does
  not pay for it (verified in a real frame: `(featurep 'org)` is t in both prose
  profiles 3 s after start, nil in `ide`).
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
  height, notes at 89–91%). The check now runs in **both** prose profiles, each
  with a fixture in its own language (`09-footnotes-placement.org` in Hebrew,
  `09-footnotes-placement-en.org` in English): the notes profile was exporting
  footnotes that nothing checked, and a Hebrew fixture inside an English
  document would have passed without exercising anything. Two traps are worth
  keeping in mind when a fixture is edited: a word looked for must not be the
  *first* word of its note (pdftotext glues the note number to it, so
  `BOTTOMMARK` arrives as `1BOTTOMMARK`), and only the word being looked for is
  reversed for Hebrew, never both sides. Verified to still bite: a fixture with
  the note word repeated near the top of the page fails with "sits at 16% down
  the page, not at the bottom".
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
- Cursor: `C-p`/`C-n` are visual by default; the arrow keys were always right
  because `right-char` is already visual in Hebrew. What was wrong was
  `C-f`/`C-b`, which are `forward-char`/`backward-char` — logical order, so
  inside a Hebrew paragraph they step against the screen. The hebrew profile now
  remaps those two commands to `right-char`/`left-char`
  (`configs/hebrew/modules/display.org`); in left-to-right text the moves are
  identical, so an English paragraph in a sefer is unchanged. Verified in a
  frame: from point 2 of `אבג`, `C-f` lands on 1 — the character drawn to the
  right — and in `abc` on 3, the logical move. `test/invariants.el` asserts the
  hebrew binding *and* that `notes` and `ide` still have
  `forward-char`/`backward-char`, so the remap cannot leak into a profile that
  reads Latin only. `visual-order-cursor-movement` stays nil: it changes neither
  the landing position nor the price (0.35 ms vs 0.19 ms per 200 presses), and
  its docstring warns it can move point many buffer positions away.

Not verified: any macOS or Windows run (comtai #5), and one unexplained
`End of buffer` message in an ide GUI check (comtai #6). GUI checks run on Xvfb;
real measurements run on headless `sway`, because the user is on Wayland and X
numbers do not transfer.

## What stage 3 moved, and what it measured

Stage 3 is the `notes` profile, and building it exposed that most of what the
hebrew profile owned was not Hebrew at all. The rule the repository had already
written down — a setting moves to the base once two profiles want it — was
applied to three things:

| was | now | why it is shared |
|---|---|---|
| `hebrew/modules/footnotes.org` | `base/footnotes.org` | both prose profiles want notes at the bottom of the file |
| `hebrew/modules/reading.org` | `base/prose.org` | colour off and org preloaded are prose decisions, not Hebrew ones; the org preload is guarded so the ide profile does not pay ~0.5 s of background CPU for a format it does not use |
| the machinery in `hebrew/modules/export.org` | `base/export.org` | one export path for both: PDF beside the source, notes ordered on a staged copy, depth 10, the redirect of `org-typst-export-to-pdf` |

What stayed in the profiles is one line each: the language.
`configs/hebrew/modules/export.org` sets `he` (and carries the RTL rationale),
`configs/notes/modules/export.org` sets `en`. The machinery is otherwise
identical, so a fix to the staging or the ordering cannot drift between them,
and `bin/check.sh` runs the export tests against both profiles.

Measured on a 400 KB English org file, real frame, for the colour decision
(the user chose colour off, matching hebrew): font-lock off scrolls a line in
**3.33 ms** and a keystroke in **3.89 ms**; font-lock on is **3.22 ms** and
**4.72 ms**, with **64 ms** to fontify the whole buffer. So colour on English
prose is nearly free — the 3,473 ms figure belongs to org's footnote face
scanning back to a heading that does not exist in a sefer, not to font-lock.
Colour is off anyway, by the governing rule, and that is one line to reverse.

One defect found and fixed while exercising the profile: an org footnote
definition with no text makes `ox-typst` signal `wrong-type-argument (arrayp
nil)` — it passes nil contents to `org-trim`. The export now refuses it first,
naming the note: "Footnote 1 has no text; type it or delete it before
exporting". The check is a 3 ms line scan on the 340 KB sefer, and
`test/export-in-profile.el` fails if the crash comes back (verified by
disabling the guard). The underlying bug is upstream; it is not patched in
`vendor/ox-typst/` because a fifth local patch needs a re-vendor to regenerate
`upstream.patch`, and the refusal is the better behaviour either way.

## Colour in code, priced for stage 4

Stage 4 starts with a decision: `base/prose.el` turns font-lock off for every
profile, and the ide profile would have to turn it back on for code. Rather than
reason about it, it was measured: three real files from the user's projects, a
real frame, colour on against off, two runs each, median of 20 operations per
number.

| file | mode | fontify whole buffer | scroll a screen | keystroke |
|---|---|---|---|---|
| 280 KB Rust, 6,230 lines | `rust-mode` | 1,249–1,326 ms | 13.2–16.6 on / 12.0–16.3 off | 5.3–5.5 on / 3.3–4.9 off |
| 94 KB Rust | `rust-mode` | 521–784 ms | 11.4–12.7 / 9.6–12.3 | 4.7–5.6 / 2.6–2.8 |
| 115 KB Python | `python-mode` | 1,970–2,432 ms | 11.9–16.3 / 16.2–24.3 | 8.2–8.5 / 3.3–5.5 |

The reading of it:

- **The whole-buffer number is not paid while editing.** `jit-lock-stealth-time`
  is nil in this build, so nothing fontifies a whole file in the background;
  the 0.5–2.4 s appears only when something insists on a fully fontified buffer.
- **A screen of scrolling is the same either way**, inside the spread.
- **A keystroke costs 1.5–3 ms more with colour on**, because jit-lock
  refontifies the edited line: at worst 8.5 ms in `python-mode`, which is the
  regexp-heaviest of the three. Under the ~10 ms where a keystroke starts to
  feel late.
- **The real obstacle is not speed.** No treesit grammar is installed on this
  machine (`rust`, `typescript`, `python`, `javascript`, `c` are all nil) and
  the config has no packages, so a `.rs` file opens in `fundamental-mode` today:
  colour in Rust is first a dependency question (a grammar, or `rust-mode` as a
  package), then a performance one. The numbers above were taken with
  `rust-mode` from the old config's `elpa`, i.e. what stage 4 would install.

So the answer to "does colour cost too much time?" is **no for code, yes for
prose**. The prose numbers are the ones that justify switching it off: a
keystroke at a footnote in the sefer cost 38.4 ms with the footnote face on, and
fontifying the whole sefer cost 3,473 ms — while the same buffer without the
face was 106 ms. Neither applies to a source file. Not implemented yet: colour
for code is stage 4's one-line override, and it should be made per language
base-mode rather than globally.

## The three requests from the end of stage 1

Three were asked; the third is now done (see the buffer entries above). The two
remaining are measured only as far as the paragraph below:

1. ~~**Unlimited heading depth.**~~ Tested and settled. Nothing caps the depth:
   a fixture with headings 1–8 and a list 8 deep exports to PDF with every
   level present. What Emacs's default `org-export-headline-levels` of 3 caps
   is *numbering and the TOC* — level 4+ is emitted as
   `#heading(level: 4, outlined: false, numbering: none)`, unnumbered and
   absent from the contents. The hebrew profile now sets it to 10
   (`configs/hebrew/modules/export.org`), so H4–H8 are numbered
   `1.1.1.1`…`1.1.1.1.1.1.1.1` and listed; cost is a longer TOC and nothing
   measurable. It must be a global `setq`: the export stages the text in a
   fresh buffer, where a buffer-local value is gone. A file can still override
   with `#+OPTIONS: H:n`. `test/export-in-profile.el` now fails if a
   fourth-level heading comes out unnumbered.
2. ~~**Deep list nesting.**~~ Same test: an 8-deep list exports to PDF with all
   eight levels and no error. Nothing needed.
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

Stage 2's own list is now empty except for the cross-platform run: heading and
list depth are measured and settled (see the requests section below), the
buffer work is in, and `bin/check.sh` is clean. What remains before the stage
can be called finished is the first run on Windows or macOS (comtai #5).

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
stages, #5 first run on Windows/macOS. #6, the `End of buffer` mystery, is
solved: wheel and touch events reach the private Xvfb frame from outside Emacs
about one run in four, `mwheel-scroll` at the top of `*scratch*` prints the
message, and nothing in the configuration was involved. `test/probe.el` now
records the messages log as it stood at the first input event and
`bin/check.sh` judges only that part, so the machine's pointer can no longer
fail the check while an injected startup `message` still does (verified both
ways: 20 runs clean, and an injected line is still caught).

The same file's *wait* had a second way of lying, found under load average
10–23: `MY_PROBE_WAIT` was 6 s measured from the moment the file loaded, which
is before init runs, and the three deferred modes are reached by a 3.0 s
wall-clock fallback that this host services late. A traced run saw only three
polls in 3.5 s, then all three modes on at +3.56 s — so the modes were never
missing, the clock was short. The wait now starts at `emacs-startup-hook` and
the deadline is 30 s, a backstop rather than the mechanism, since a healthy run
samples the instant the modes appear. 6 of 6 GUI runs pass at load 23, and
`bin/check.sh` is clean. Two traps for whoever edits that file: `defconst`'s
closing paren sits on the docstring's last line, and losing it makes every
following form part of the string, which Emacs reports as "Too many arguments"
far away from the real line; and `emacs-startup-hook` never runs under
`-Q --batch --eval`, so a batch probe cannot witness this behaviour at all.

Commit messages say `refs comtai#1` — do **not** write `closes` for a stage task
until the stage is actually finished; that mistake was made once and had to be
reopened.

## Order of work from here

1. Stage 4 `emacs-ide`. Stage 2 and stage 3 are otherwise finished: both are
   checked on Linux, and both await the first Windows/macOS run.
2. Stage 5: old-config triage, bit by bit, each item priced.
3. First run on Windows/macOS before calling any stage finished — it is now
   owed for two stages.
4. ~~Decide whether the ide profile wants colour back.~~ Measured — see "Colour
   in code, priced for stage 4": colour costs 1.5–3 ms a keystroke and nothing
   measurable while scrolling, so it belongs on for code and off for prose. The
   open part is the dependency: no treesit grammar is installed, so Rust/TS
   colour needs one (or a classic major mode package) before it can even show.
