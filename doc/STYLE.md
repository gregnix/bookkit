# bookkit — Writing style by book type

Common rules for all books, applied according to the book type. Adds the
text itself to `SPEC.md` (format). Part of it can be checked with
`tools/style-check.tcl` (see `TOOLS.md`). The tool gives hints; the author
decides.

German version: `doc/de/STYLE.md`. The word lists of `style-check.tcl` are
German; on an English book it finds dates, status lines and book ids, but
little of the wording.

---

## 1. Book types

Every book has a type. It is set in `book.tcl`:

```tcl
set booktype workshop     ;# textbook | workshop | manual | reference | developer
```

| `booktype` | Book type | Style | What goes in |
|---|---|---|---|
| `textbook` | textbook | explanatory, accessible, building up | foundations, connections, progressive examples, exercises |
| `workshop` | workshop book | practical, direct, solution-oriented | procedures, commands, troubleshooting, experience |
| `manual` | manual | factual, precise, systematic | functions, options, configuration, use cases |
| `reference` | reference | terse, unambiguous, complete | syntax, parameters, return values, errors |
| `developer` | developer book | technical, reasoned | architecture, implementation, design decisions |

The type in `book.tcl` and the self-description in the README ("An
English-language workshop book on …") agree. A book stays with its type:
a textbook does not turn into a test log, a reference not into a story.

### The same content in four types

*Textbook:*

> Tcl/Tk can be built from source on macOS. For that we need Apple's
> developer tools and the Tcl/Tk sources. In the next section we set up
> the environment and then create a first Tk application.

*Workshop book:*

> To build Tcl/Tk 9.0.4 we use BAWT. It is installed to `/opt/tcl9`.
> First we check whether Xcode and the command line tools are present.

*Manual:*

> The installation directory `/opt/tcl9` holds the Tcl/Tk runtime.
> Further packages live in a directory of their own and are added through
> the package search path.

*Reference:*

```tcl
puts $::tcl_version
puts $::auto_path
puts [tcl::tm::path list]
```

---

## 2. Common rules

These rules apply to every book.

**Wording.**

- "Measure", "measured", "measurement" only when a quantity is measured:
  time, size in bytes, a count, memory. A functional test is not a
  measurement. Instead: "checked", "tested", "tried", "observed", or just
  the statement itself ("`wish9.0` reports `aqua`").
- Natural sentences instead of constructed ones: "This book covers the
  specifics of Tcl/Tk on macOS", not "This book separates Tcl/Tk on macOS
  from Linux and Windows".

**What does not belong in the chapters.**

- How the book was made. No chapter opens with its own history. The note
  on AI assistance appears **once**, in the README (imprint) or a preface.
- Timestamps and times of test runs, build directories, counts that do
  not help the reader ("all 141 libraries").
- Administration: ids of other books (`book-other-book`) in running text,
  lists of neighbouring books at the start of a chapter. Refer to another
  book by title where it helps; keep the list in the README.
- Repeated summaries that only list the chapter text again.

**What must stay.**

- Technical limitations and important test results: what does not work,
  which version something applies to, what is not checked and therefore
  uncertain. That is information for the reader, not a log. It only goes
  to a different place (section 3).
- Sources (appendix Sources) and pitfalls (appendix Pitfalls).

**Dates.** One `*As of: …*` per book, in the README and in `book.tcl`
(`set date`), not below every chapter title. A date in running text only
when it means something to the reader: a release ("Tcl/Tk 9.1.0 came out
in September 2026"), a deadline, the age of a source ("wiki page from
2013").

---

## 3. Where tests and test status go

| Place | What |
|---|---|
| main text | only results that matter for understanding or use, stated as facts |
| at the example or chapter end | a "Tested with" box, see below |
| appendix "Test environment" | machine, operating system, exact versions, check scripts, open items |
| repository | full logs, timestamps, complete output, history (`CHANGES.md`) |

The box sums up what a chapter has checked and what not. It appears once,
at the end of the chapter or after the example it refers to:

```markdown
::: {.info}
**Tested with** Tcl/Tk 9.0.4 on macOS 27 (Apple silicon).

**Not tested:** launching by double-click in the Finder, passing the app
on to a second Mac.
:::
```

Instead of "measured on 19 October: …" in the middle of a sentence, the
text states the result ("Tk loads `AppMain.tcl` with the BAWT `wish9.0`
too"), and the box says what it was checked with.

---

## 4. Rules per book type

### Textbook (`textbook`)

- A chapter answers: What is it? What do I need it for? How does it work?
  What do I have to watch out for?
- Explain terms before using them. Examples build on each other.
  Exercises at the end of a chapter are welcome.
- "We" is fine ("We first create …"); no familiar address.
- No test status in the main text, at most the box at the chapter end.
- Summary at the chapter end: yes, short, as learning goals.

### Workshop book (`workshop`)

- Straight to the procedure: prerequisites, steps, result,
  troubleshooting.
- May show what did not work and why, when the reader learns from it. No
  chronology of the development.
- Commands complete and runnable, with the expected output.
- Test status in the box. "Measured" only for real measurements (run
  time, size).
- Summary: only for a long chapter, then as a checklist "In short" with
  the steps, not as a repetition of the text.

### Manual (`manual`)

- Ordered systematically by function or option, each with purpose,
  values, default, effect.
- Present tense, factual, no narrative. No "I" or "we".
- Test status only where it explains a limitation.
- Summary only as a short checklist, not as a repetition; options and
  values preferably in tables.

### Reference (`reference`)

- Syntax, parameters, return values, errors. Complete, terse, uniformly
  structured.
- No test status, no dates, no summary.
- Short examples without explanations the text already gives.

### Developer book (`developer`)

- Architecture, implementation and design decisions, each with reasons
  and rejected alternatives.
- May contain measurements (run time, memory), then with method and
  number.
- The version history of the tool belongs in `CHANGES.md`, not in the
  chapters.

---

## 5. Checking

```bash
tclsh bookkit/tools/style-check.tcl book-my-book/My-Book-en/
```

The tool counts the hints from sections 2 and 3 per chapter and rates
them by `booktype`. If a counted item is the subject of the book,
`book.tcl` switches it off: a book about bookkit names book ids, so
`set styleallow {buchid}`. It finds clusters, not individual style
errors: a hit may be right ("the run time measured with `time`").
Switches and output: `TOOLS.md`.

---

## 6. Before and after

Before (introduction of a workshop book):

> On 17 October at 22:25 BAWT 3.3.0 ran on the test machine with
> `update`, Tcl/Tk **9.0.4**, root `../Bawt9.0.4`. Level **None** for all
> 141 libraries. The distribution is under `/opt/tcl9`. Measured there
> with `wish9.0`: patchlevel **9.0.4**, `tk windowingsystem` **aqua**.

After:

> The examples use Tcl/Tk 9.0.4, built with BAWT and installed under
> `/opt/tcl9`. The programs are native ARM64 programs and use the Aqua
> window system (`tk windowingsystem` returns `aqua`).

The rest (BAWT version, build directory, date) goes into the appendix
"Test environment".

---

## 7. Converting a book

Steps for bringing an existing book to its book type. The result for a
workshop book: a new chapter 010 (introduction, what the examples work
with, how to read the book) and an appendix
`860-appendix-test-environment.md`.

### Before

1. **Copy the book directory** (outside the book). The copy is the basis
   for `code-compare.tcl` at the end.
2. **Choose the type.** What the book does decides, not what it calls
   itself: an installation guide is a workshop book, even if the README
   says "textbook". When in doubt, run `style-check.tcl -type …` with
   several types and look at the content.
3. **Count the starting point:** `style-check.tcl <book>` and
   `book-check.tcl <book>/`. Note errors that are already in the
   original, so they are not attributed to the revision.

### Change

4. **`book.tcl`:** `set booktype <type>` with a comment. If a counted
   item is the subject, also `set styleallow {…}`.
5. **Status lines** `*As of: …*` below the chapter titles: remove. One
   status stays in the README.
6. **Go through every chapter**, following sections 2 and 4:
   - "measured", "measurement" only for quantities; otherwise the
     statement itself or "checked", "tested", "tried", "observed". A check
     script is called "check script" in the text, even if the file is
     named `measure-*.tcl`.
   - Date and time of test runs out of the running text. Release and
     source dates stay, as month and year.
   - Replace book ids `book-…` by the book title.
   - No history and no AI in the chapters. The note on AI assistance
     appears once in the imprint (README), and only if the book already
     has it.
   - Version history ("since …", "fixed on …", "version 1, first run …")
     becomes the current state. In a workshop book, instructive failures
     become a section "Pitfalls"; old versions point to `CHANGES.md`.
7. **Rewrite chapter 010** for the type:
   - Workshop book: introduction (what it is about, for whom), "What the
     examples work with" (versions, machine in one sentence, pointer to
     the appendix), "How to read this book" (parts, appendices).
   - Manual: purpose, audience, basis of the information, structure.
   - Textbook: what is learned, prerequisites, path through the book, a
     "Tested with" box at the end.
8. **Appendix "Test environment"** (`860-appendix-test-environment.md`,
   next free letter) when the book has test status: machines and
   versions, check scripts, a table "Not yet tested" per chapter,
   collected from every "not checked" in the book. If the book already
   has a log appendix, put it there instead of twice. A textbook rarely
   needs it; the box at the chapter end is enough there.
9. **Appendices 800–899:** adjust only the wording; dates may stay.
10. **README, structure, counts:** book type in the self-description, a
    short paragraph on versions instead of a test log, the new appendix
    in reading order and counts.

### Do not

- **Do not change code blocks**, at most comments in them
  (";# measured: 5.2.0" → ";# -> 5.2.0"). A block may move to an
  appendix.
- **Do not invent anything.** What the book does not say (the operating
  system of a machine, a version, that something ran) does not go in;
  leave it open and note it as an open question.
- **Do not drop facts.** Limitations and test results move (box,
  appendix); they do not disappear.
- Do not silently resolve contradictions between chapters or books; note
  them.

### After

```bash
tclsh bookkit/tools/style-check.tcl <book>             # 0 with hints, justify the rest
tclsh bookkit/tools/code-compare.tcl <copy> <book>     # FEHLT 0
tclsh bookkit/tools/book-check.tcl <book>/             # 0 errors, 0 warnings
tclsh bookkit/tools/book-build.tcl <book>/ -number     # PDF and HTML
```

If the book has a translation, update it too and then run
`i18n-status.tcl <source> <translation> -mark-all`.

Finally note: book type, hints before and after, new files, what was
deliberately kept (real measurements), what is uncertain or
contradictory.
