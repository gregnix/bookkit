# bookkit — Changes

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
