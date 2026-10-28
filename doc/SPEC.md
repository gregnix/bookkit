# bookkit — Format Specification

The binding standard for books in the **docir + mdstack + pdf4tcl** format. A
book that follows this specification can be built to PDF and HTML with
`tools/book-build.tcl` — with hierarchical numbering, a table of contents and a
subject index — and can be extended to multiple languages without restructuring.

This file is the **single source of truth** for the format. Processes are in
`MIGRATION.md` (migrating existing books) and `I18N.md` (multilingual support);
the book registry is in `REGISTRY.md` (format: `REGISTRY.example.md`).

---

## 1. Directory layout

A book is **one directory**, named after its *book-id* (lowercase, with
hyphens). Translations are separate directories with an appended language code:

```
<book-id>/            # source (source language declared in book.tcl)
<book-id>-en/         # English translation, same file names
<book-id>-fr/         # further languages likewise
glossary/             # multi-column glossaries (shared)
i18n/                 # anchor maps per translation
bookkit/              # this toolkit (neighbour or submodule)
```

The build output (`<book-id>.pdf`, `<book-id>.html`) is placed **one level
above** the book directory.

For a Markdown server (mdserver), `book-webindex.tcl` additionally produces a
**web output inside the book directory**: `index.md` (chapter TOC) and — when
`{.index}` markers are present — `stichwortverzeichnis.md` (subject index). Both
use managed blocks (`<!-- bookkit:toc:… -->`, `<!-- bookkit:index:… -->`); prose
around them is preserved. See `TOOLS.md`.

### Required in the book directory

- `book.tcl` — manifest (chapter order + metadata), see §2.
- **One** Markdown file per chapter, name prefix `NNN-` (e.g. `010-…`).

### Not in the manifest

`README.md`, `CONTRIBUTING.md`, loose notes, glossaries and build scripts do
**not** belong in the `chapters` list. Only real chapters are included.

---

## 2. `book.tcl`

The manifest is a Tcl script that only sets variables:

```tcl
set title     "Title"
set author    ""
set subtitle  "Subtitle"             ;# title page
set date      ""                     ;# title page (empty = none)
set lang      "de"                   ;# source language or translation code
set titlePage 1                      ;# 1 = own title page
set booktype  workshop               ;# book type

set tocTitle   "Inhaltsverzeichnis"  ;# in the book's own language
set indexTitle "Stichwortverzeichnis"

set chapters {
    010-einleitung.md
    020-thema.md
}
```

**Rules**

- Order is **explicit** in `chapters` — do not rely on file prefixes once
  sub-chapters exist (`04` / `04a`).
- Set `tocTitle` / `indexTitle` in the book's language.
- `booktype`: `textbook`, `workshop`, `manual`, `reference` or `developer`.
  Read by `tools/style-check.tcl`, which rates its hints by it;
  ignored by the build. Optional `set styleallow {buchid}` switches off
  style hints that are the book's subject.
- `lang` declares the language of the directory (source or translation).
- Generate the manifest from existing prefixes:
  `tclsh bookkit/tools/book-build.tcl manifest <book-id>/`, then review.

---

## 3. Markdown rules

### Headings

- **No numbers** in H1–H3. `# Basics`, not `# 1 Basics`.
- Numbering comes from the build (`-number`): 1, 1.1, 1.1.1 …
- **One `#` (H1) per chapter file.** Further levels: `##`, `###`.
- Anchors are derived from the heading text — cross-references survive a
  reordering of the chapters.

### Code and `#` lines

**Mandatory:** every line that starts with `#` and is *not* a heading must be
inside a code block. Otherwise the build reads it as a chapter heading.

```markdown
## Example

```bash
# comment — only correct because it is inside a code block
git status
```
```

### Never translate / do not set as body text

- Code blocks and inline `` `code` ``
- Commands, options, file names, paths, URLs, environment variables
- Established proper names (Stub, TEA, Starpack, tclkit, BAWT, Termux, …)

Comments **inside** code blocks may keep the source language, even in
translations.

---

## 4. Subject index

Mark index terms inline:

```markdown
Every [extension]{.index} is loaded as a shared library.
```

- Mark in **body text** or `##` headings, not in table cells.
- At least one mark per central term in the relevant chapter.
- Thin out duplicate marks of the same term per file:
  `tclsh bookkit/tools/index-dedupe.tcl <book-id>/`.
- Multilingual: mark the term in the target language
  (`[extension]{.index}`), see `I18N.md`.

---

## 5. Cross-references

Within a built book via a title anchor:

```markdown
See the [basics chapter](#basics).
```

- **Label** in the book's language.
- Anchor = slug of the target heading text (the build/`docir` generates it).
- After translation, anchors of translated headings change — see `I18N.md`
  and `tools/i18n-fix-anchors.tcl`.

---

## 6. Glossary

A **multi-column** TSV per book at `glossary/<book-id>-glossary.tsv`:

```
# header row = language codes; one line per term, TAB-separated.
de	en	fr
Erweiterung	extension	extension
Repository	repository	dépôt
```

Lines with `#` are comments. New language = new column, no restructuring. Older
two-column `-de-en.tsv` glossaries are migrated by prepending a `de⇥en` header
row (see `MIGRATION.md`).

---

## 7. Images

A book may contain images (screenshots, photographs, pre-rendered diagrams)
in plain CommonMark syntax, as a standalone block or inline:

```markdown
![The log viewer after the first run](images/logviewer.png)

Click the ![save icon](images/save.png) to store the entry.
```

For a standalone block the alt text becomes the caption (`<figcaption>` in
HTML, italic grey text below the image in PDF); for an inline image it is not
rendered as a caption. Both forms accept an optional `"title"`.

**Paths** are **relative to the book directory** (the one holding the chapter
files and `book.tcl`); an `images/` subdirectory is conventional but not
required. Absolute paths and `http(s):` URLs pass through to HTML unchanged and
are **not** embedded in PDF (which falls back to an `[image: alt]` marker) —
keep images local.

**Formats:** PNG for screenshots (lossless), JPEG for photographs. PDF cannot
embed SVG, so a diagram that should be vector in HTML and raster in PDF is
exported twice under the same base name (`abi.svg` + `abi.png`); reference the
one matching the primary output. The PDF backend loads image files directly
from disk — **Tk is not required** for a book build.

Images wider than the text column are scaled down (never up); for print aim for
roughly 200 dpi at final size (pixel width about eight times the target width in mm). A PDF
image block that does not fit the remaining space moves to the next page whole,
never split. A referenced file that does not exist is reported on stderr and
rendered as an `[image: alt]` marker; the build does not fail.

**Multilingual books** keep localised screenshots per language. Because each
translation is its **own sibling directory** (§1), reference the image with the
same relative path from every language and keep a per-language copy:

```
git-und-tcltk/      images/mainwindow.png     # German UI
git-und-tcltk-en/   images/mainwindow.png     # English UI
```

A screenshot with no text may be shared: reference it from each language with a
relative path that reaches the shared file.

---

## 8. Building

```bash
tclsh bookkit/tools/book-build.tcl <book-id>/ -number
```

`-number` assigns the numbers; the source stays without. All switches (TOC,
index, CID font, depth, title, output files) are listed only in **TOOLS.md**;
this spec defines the book format, not the invocations. Runtime
dependencies: `docir`, `mdstack`, `pdf4tcl` must be reachable.

---

## 9. Tools (overview)

| Tool | Purpose |
|---|---|
| `book-build.tcl` | book → PDF/HTML; `manifest` subcommand creates `book.tcl` |
| `book-new.tcl` | create a new book (source + translations + glossary) |
| `book-migrate.tcl` | cross-refs → anchors, index markers (existing books) |
| `manual-build.tcl` | merge nroff-derived manpage Markdown into one manual (PDF/HTML) |
| `index-gesamt.tcl` | combined index PDF over several manual PDFs |
| `i18n-fix-anchors.tcl` | rewrite anchors in a translation via a map |
| `i18n-check.tcl` | find leftover source language in a translation |
| `i18n-status.tcl` | which translated chapters lag behind the source |
| `index-dedupe.tcl` | thin out duplicate `[term]{.index}` per file |
| `book-check.tcl` | SPEC check: registry, dedupe dry-run, manifest, H1, links |
| `book-webindex.tcl` | web output for mdserver: `index.md` + `stichwortverzeichnis.md` |
| `book-search.tcl` | full-text search over all books (SQLite FTS5) |
| `book-search-gui.tcl` | search window (needs Tk, the only tool that does) |

Detailed per-tool reference (options, examples): see **TOOLS.md**.
