# bookkit — Changes

## 2026-10-28 — STYLE.md removed

- `doc/STYLE.md`, `doc/de/STYLE.md` removed; references in README, SPEC,
  TOOLS and the tools dropped. style-check unchanged.

## 2026-10-27 — STYLE: note on AI assistance

- STYLE.md (de, en): the note on AI assistance appears once in the
  imprint (README) of every book, no longer only where it was already.
- README: note on AI assistance.

## 2026-10-27 — book-build: lang; index-dedupe: link before a marker

- `book-build`: `lang` from `book.tcl` goes to the PDF (document
  language) and the HTML (`<html lang>`); before, the PDF had none and
  the HTML said `en`. Tests in `tests/run.tcl` (2 new).
- `index-dedupe`: a marker is matched at its own `[`. A link before a
  marker on the same line (`[x](a.md) … [Word]{.index}`) was taken as the
  start of the marker: a false duplicate, and the write run broke the
  link. Tests in `tests/run.tcl` (2 new, 95 in all).

## 2026-10-27 — STYLE: series

- STYLE.md (de, en): references to a series follow the rule for other
  books: no series ids or lists of volumes in the chapters; the series by
  its name where it helps; the list of volumes in the README.

## 2026-10-26 — template and book-new: LICENSE

- `template/my-book/LICENSE` and `template/my-book-en/LICENSE` carry the
  book license (text CC BY-SA 4.0, the author's own code examples MIT,
  including the condition that the copyright and permission notice be
  kept). The copyright holder is the placeholder `<Name>`, because the
  template is public.
- `book-new.tcl` copies that file into every new directory (German text
  for `-lang de`, English otherwise). `-author` writes the name into
  `book.tcl` and replaces `<Name>` in `LICENSE`. Without `-author` the
  placeholder stays.

## 2026-10-26 — book-build: license chapter

- A `LICENSE` (or `LICENSE.md`, `LICENSE.txt`, `license.terms`) in the book
  folder becomes the last chapter of the PDF and HTML, verbatim in a text
  block, titled "Lizenz" for `lang de` and "License" otherwise. A PDF
  passed on alone carried no word about its terms; CC BY-SA asks for that
  notice. `-no-license` leaves it out. `book.tcl` is now also read for
  `lang`. Tests in `tests/run.tcl` (2 new, 84 in all).

## 2026-10-25 — publish-check: date in book.tcl; values that look like numbers

- `publish-check`: `set date "2026-10-25"` in a `book.tcl` is no longer
  reported. STYLE.md puts the date of a book there (title page), and the
  check flagged exactly that line (`publish-allow.tsv`).
- `book-build`: title, author, subtitle, date and the toc/index titles were
  chosen with `expr {$a ne "" ? $a : $b}`. expr returns a value that looks
  like a number in canonical form: a subtitle `1.10` became `1.1`, a date
  `2026.10` became `2026.1`. Now a plain choice (`firstSet`).
- `book-search`: search words went through the same kind of `expr`; `0.10`
  was searched as `0.1`, `010` as `8` under Tcl 8.6 (octal). Fixed, also
  for the trigram fallback. `book-search-gui` joined excerpt lines that
  way (a line `5.10` read `5.1`); `manual-build` the default label.

## 2026-10-24 — publishing: private part, publish-check

- New `tools/publish-check.tcl`: checks a tree before publishing for
  dates and review notes in comments, personal paths, names of AI tools,
  built files (PDF, HTML) and work notes. General patterns in
  `tools/publish-deny.tsv` / `publish-allow.tsv`, own names in the private
  part `bookkit-privat/` next to `bookkit/`, plus the source folders from the
  private registry. Respects simple `.gitignore` patterns.
- The book registry is private: `book-check.tcl` and `book-search.tcl` take
  `$BOOKKIT_REGISTRY`, else `bookkit-privat/REGISTRY.md`, else
  `doc/de/REGISTRY.md`, else `doc/REGISTRY.md`. The public tree only has
  `doc/REGISTRY.example.md` and `doc/de/REGISTRY.example.md`.
  `book-check.tcl` reads the book type column as "Buchtyp" or "Book type".
- `book-migrate.tcl` is generic: anchors come from each chapter's first
  heading instead of a table for one book; `-n` for a dry run.
- Comments, docs and the bookkit book describe what the tools do; history
  moved here. Examples use `my-book` / `mein-buch` and a neutral workspace
  instead of own projects and paths.
- `doc/SPEC-images-section.md` removed (its content is SPEC §7).

## 2026-10-24 — book-build, manual-build, book-check, book-search

- book-build: every chapter is parsed on its own; a heading id already used
  in an earlier chapter gets `-2`, `-3` …; links resolve in the scope of
  their chapter (`#a`, `file.md#a`, `file.md`). A chapter missing from disk
  stops the build, `-allow-missing` only warns. `manifest` writes chapter
  names as Tcl list elements (spaces, braces).
- Code fences after CommonMark (same character, at least as long) in
  manual-build, book-check and book-search.
- book-check: a broken `book.tcl` is an error. book-search: a broken
  `book.tcl` warns instead of silently using the file names; heading anchors
  unique over the book as in book-build.
- manual-build: parts per folder (`# Tcl`, `# Tk`, `# Ttk`, one per tcllib
  module), `-no-groups`; `-lang`, `-author`, `-subject`; current man page in
  bold in the running header; no second copyright note when the page has a
  "Copyright" section; copyright lines kept apart (` \` before the break).

## 2026-10-23 — running header, combined index links

- manual-build: running header with path and neighbours (docir `%c`).
- index-gesamt: page links as `GoToR` through pdf4tcl `fileLinkAdd`, a mixin
  where it is missing; `-lang`, creator.
- manual-build `-index-tsv` reads the printed pages from
  `docir::pdf::indexEntries`.

## 2026-10-22 — CID font in manual-build

- manual-build uses the CID font by default, as book-build; the subset
  turned the narrow no-break space in "z. B." into "?". `-no-cid` switches
  back.
