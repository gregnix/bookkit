# bookkit — Tools

Reference for the fourteen tools in `tools/`. Complements SPEC.md §9 (which is
only an overview). **This file is the authoritative list of switches**; SPEC.md
and the bookkit book refer here. All tools are pure Tcl and run with `tclsh`
(Tcl 8.6 or 9.0). Exception: `book-search-gui.tcl` needs Tk. `book-build.tcl`
and `manual-build.tcl` additionally need `docir`, `mdstack` and `pdf4tcl`;
`book-search.tcl` and the GUI need the `sqlite3` package with FTS5.

**Working directory.** The tools are invoked one level *above* the book folder —
where the book directories (`<id>/`, `<id>-<lang>/`), `glossary/` and `i18n/`
sit next to each other. Paths to `tools/` are relative to that location (e.g.
`tclsh bookkit/tools/book-build.tcl ...`).

Overview:

| Tool | Purpose |
|---|---|
| `book-build.tcl` | build a book to PDF/HTML/Markdown; `manifest` subcommand creates `book.tcl` |
| `book-new.tcl` | create a new book (source + translations + glossary + anchor maps) |
| `book-migrate.tcl` | fit in existing material: cross-refs → anchors, index markers |
| `i18n-fix-anchors.tcl` | rewrite anchors in a translation via a map |
| `i18n-check.tcl` | find leftover source language in a translation |
| `i18n-status.tcl` | which translated chapters lag behind the source; diff since last translation |
| `index-dedupe.tcl` | thin out duplicate `[term]{.index}` per file |
| `book-check.tcl` | SPEC check: registry paths, `index-dedupe -n`, manifest vs files, one H1, `.md` links |
| `book-webindex.tcl` | web output for mdserver: `index.md` (chapter TOC) + `stichwortverzeichnis.md` |
| `style-check.tcl` | check writing style against the book type |
| `code-compare.tcl` | compare the code blocks of two versions of a book |
| `publish-check.tcl` | before publishing: no notes, private paths or built files in the tree |
| `manual-build.tcl` | merge nroff-derived manpage Markdown into one manual (PDF/HTML) |
| `index-gesamt.tcl` | one combined index PDF over several manual PDFs (links into the PDFs) |

---

## book-build.tcl

Builds a book from Markdown chapters to PDF and/or HTML (and optionally
Markdown), with hierarchical auto-numbering, a table of contents and a subject
index.

**Usage**

```
tclsh bookkit/tools/book-build.tcl <bookdir> [options]
tclsh bookkit/tools/book-build.tcl manifest <bookdir>
```

**Chapter order.** If `<bookdir>/book.tcl` exists, its `chapters` variable
determines the order (the numeric file prefixes are then ignored). Without
`book.tcl` the `.md` files are sorted by their `NNN-` prefix.

**Options**

| Option | Effect |
|---|---|
| `-pdf <file>` | PDF target. Without `-pdf`/`-html`/`-md`, PDF **and** HTML are produced next to `<bookdir>`. |
| `-html <file>` | HTML target. |
| `-md <file>` | output merged Markdown. |
| `-number` | number headings hierarchically (H1 `1`, H2 `1.1`, …). |
| `-no-toc` | no table of contents. |
| `-no-index` | no subject index. |
| `-no-cid` | PDF fonts with the 256-character subset instead of full Unicode (CID mode, default). Smaller file; ⌘ ⌥ → ∂ and similar become `?`. |
| `-depth <N>` | numbering/TOC depth (default from the build). |
| `-title <T>` | override the title (otherwise from `book.tcl`). |
| `-author <A>` | override the author. |
| `-subtitle <S>` | override the subtitle. |
| `-date <D>` | override the date. |
| `-title-page` | force a title page. |
| `-toc-title <T>` | heading of the table of contents. |
| `-index-title <T>` | heading of the subject index. |
| `-allow-missing` | a chapter listed in `book.tcl` that does not exist only warns (drafts); without it the build stops. |
| `-no-license` | no license chapter. Without it a `LICENSE` (or `LICENSE.md`, `LICENSE.txt`, `license.terms`) in the book folder becomes the last chapter, verbatim: "Lizenz" for `lang de`, "License" otherwise. |

**Subcommand `manifest`.** `book-build.tcl manifest <bookdir>` writes a
`book.tcl` from the existing `NNN-` prefixes (a starting point after a
migration; fine-tune by hand afterwards). Names with blanks or braces are written
as Tcl list elements (`{010-my chapter.md}`).

**Chapters and anchors.** Each chapter is parsed on its own. A heading id
that an earlier chapter already uses gets a suffix (`-2`, `-3` …), so every
target in HTML and PDF is unique. `#anchor` is looked up in the same chapter
first, then in the book; `file.md#anchor` only in `file.md`. `book-search.tcl`
numbers its anchors the same way.

**Runtime dependencies.** Needs `docir`, `mdstack`, `pdf4tcl` and `pdf4tcllib`
on the path. They are searched automatically (neighbouring directories,
`$HOME/code/git/github`, `$HOME/lib/tcltk`, `/usr/local/lib/tcltk`) or set
explicitly via the environment variables `DOCIR_HOME`, `MDSTACK_HOME`,
`PDF4TCL_HOME`, `PDF4TCLLIB_HOME`; `REPOS_DIR` adds another search base.

**Examples**

```
# both (PDF + HTML) next to the book folder, numbered
tclsh bookkit/tools/book-build.tcl my-book/ -number

# PDF only, without subject index
tclsh bookkit/tools/book-build.tcl my-book/ -number -no-index -pdf my-book.pdf

# generate the manifest from the NNN- prefixes
tclsh bookkit/tools/book-build.tcl manifest my-book/
```


**Links.** Chapter links (`[Chapter 3](030-x.md)`, `030-x.md#id`) become
`#id` jumps to the chapter's first heading or the named id; `#id` links are
checked against the heading ids (an ae/oe/ue/ss spelling of an umlaut also
resolves). Links without a target are reported (`WARNUNG: … Verweis(e) ohne
Ziel`) and left unchanged. In the PDF the table of contents and these links
jump inside the document, as do the page numbers of the index; this needs pdf4tcl 0.9.4.72 —
with an older pdf4tcl the PDF is built without internal links.

---

## manual-build.tcl

Merges a tree of nroff-derived manpage Markdown files into **one** Markdown
manual (and optionally PDF/HTML). Unlike `book-build.tcl` (for hand-written,
number-free chapters), this is for converted manpages that carry their own
NAME/DESCRIPTION sections and YAML front matter: each manpage becomes a chapter
titled by its command name, and the manpage's own sections are shifted one level
down for a clean hierarchy (`# after` / `## NAME` / `## DESCRIPTION`).

**Usage**

```
tclsh bookkit/tools/manual-build.tcl <dir> [-md out.md] [-pdf out.pdf] [-html out.html] [-title T]
                                     [-license file ...] [-index] [-index-label L] [-index-title T]
                                     [-no-cid] [-index-tsv file] [-label NAME]
                                     [-header TEMPLATE | -no-header] [-no-groups]
                                     [-lang TAG] [-author A] [-subject S]
```

The PDF header shows the manual title on the left and, on the right, where
the page is: the man page that starts on it, else the one still running,
with path and neighbours, as much as fits the line
(`‹ disjointset  |  struct / graph  |  graph1 ›`, else `struct / graph`,
else `graph`). This needs a docir with running titles (`%c`); with an
older docir the header is left out. `-header` sets another docir
template (`%t` title, `%c` running title, `%p` page, a tab between left and
right), `-no-header` switches it off.

**Parts.** When the man pages lie in more than one folder below `<dir>`,
each folder becomes a part: `# Tcl`, `# Tk`, `# Ttk` (the `ttk_*` pages
under `tk/`), in tcllib one part per module. The pages sit one level below
(`## after`), their sections two (`### DESCRIPTION`); the table of contents
shows parts and pages, the header the page. `-no-groups` keeps the flat
layout.

**Metadata.** `-lang TAG` (`de`, `en`) sets the document language,
`-author` and `-subject` the matching PDF fields; creator is
`bookkit manual-build.tcl`, the creation date is always set. The language
needs pdf4tcl 0.9.4.73. The current page in the header is bold if docir
supports `**...**` in the header.

`-index` appends a subject index. Its terms are the command name and the
`Keywords:` of each page's YAML head (TIP 700); every chapter ends with a line
"*Stichwörter:* after, cancel, ..." whose entries go into the index as
`[term]{.index}`. `-index-label` replaces "Stichwörter", `-index-title`
"Stichwortverzeichnis" (e.g. `-index-label Keywords -index-title Index`).

The PDF uses the CID font with the full Unicode repertoire, as in
`book-build.tcl`; the 256-character subset would turn characters such as
the narrow no-break space in "z. B." into "?". `-no-cid` switches back to
the subset.

`<dir>` is scanned recursively for `*.md`. The chapter body is taken verbatim
from the source Markdown (no docir round-trip). Runtime dependencies as for
`book-build.tcl`: `docir`, `mdstack`, `pdf4tcl` on the path (env vars
`DOCIR_HOME` / `MDSTACK_HOME` / `PDF4TCL_HOME`, or sibling search).

`-index-tsv file` (with `-pdf` and `-index`) also writes the finished index
as a table: header lines `# pdf`, `# label`, `# title`, then
`term<TAB>pages` with the printed page numbers. `-label` is the manual's name
in the combined index (default: `-title`, else the PDF name). The pages come
from `docir::pdf::indexEntries` after rendering (with an older docir that
lacks it, the internal state `st indexEntries`), so they match the printed
index.

---

## index-gesamt.tcl

A combined index over several manual PDFs: a PDF of its own in which every
term appears once, followed by the pages per manual
(`after — Tcl/Tk 9.0: 75, 210 · Tcl/Tk 8.6: 71, 198`).

```
tclsh bookkit/tools/index-gesamt.tcl -pdf gesamt.pdf [-title T] [-links 0|1] [-lang de|en] [-md gesamt.md] \
      a.index.tsv b.index.tsv ...
```

Inputs come from `manual-build.tcl -index -index-tsv`. With `-links 1`
(default) every page number links to that page in the other PDF (PDF action
`GoToR`, file relative to the combined index), so all PDFs belong in one
folder. Acrobat, Okular and Evince follow such links; some browser viewers do
not. docir sets the jump through pdf4tcl `fileLinkAdd` (0.9.4.73 or
later); where that is missing, `index-gesamt.tcl` adds it itself through a
mixin on `pdf4tcl::pdf4tcl`. Page numbers are only valid for exactly these PDFs: rebuild the
combined index whenever a manual PDF changes.

---

## book-new.tcl

Creates a new book with optional translations: a source folder with `book.tcl`
and two example chapters, one folder per target language (same file names), a
multi-column glossary and one anchor-map template each.

**Usage**

```
tclsh bookkit/tools/book-new.tcl <book-id> "Title" [-lang de] [-author Name] [-tr en,fr]
```

**Arguments/options**

| Argument | Effect |
|---|---|
| `<book-id>` | book ID (lowercase, hyphens); also the directory name. |
| `"Title"` | book title (in quotes). |
| `-lang <xx>` | source language (default `de`); set as `lang` in `book.tcl`. |
| `-author <Name>` | author. Written into `book.tcl` and substituted for `<Name>` in `LICENSE`. Without the option the placeholder stays. |
| `-tr <a,b,…>` | comma-separated target languages; one `<book-id>-<xx>/` is created each. |

**Result** (one level above `tools/`):

```
<book-id>/                        source chapters + book.tcl + LICENSE (lang = -lang)
<book-id>-<xx>/                   per -tr language, same file names, its own LICENSE
glossary/<book-id>-glossary.tsv   multi-column TSV (source + translations)
i18n/<book-id>-anchors-<xx>.tsv   anchor-map template per translation
```

`LICENSE` is taken from `template/my-book` (German for `-lang de`) or
`template/my-book-en` (every other language). Text is CC BY-SA 4.0, the
author's own code examples are MIT. The holder is the placeholder
`<Name>` unless `-author` is set.

Headings carry **no** numbers (the build assigns them). See SPEC.md.

Under Tcl 8.6 a title with non-ASCII arrives as UTF-8 bytes. `book-new.tcl`
decodes it once (`encoding convertfrom utf-8`); otherwise the title page
shows mojibake. Tcl 9 does not need this.

**Example**

```
tclsh bookkit/tools/book-new.tcl my-book "My Book" -lang de -tr en,fr
```

---

## book-migrate.tcl

Migration of existing material: links to other chapter files become links
to the chapter's anchor. The anchor of each `*.md` in `<bookdir>` is taken
from its first `# ` heading, computed like docir (lower case, every run
outside `a-z0-9` becomes `-`). `](other.md)` becomes `](#anchor)`,
`](other.md#x)` becomes `](#x)`; links to files that are not chapters stay.

**Usage**

```
tclsh bookkit/tools/book-migrate.tcl <bookdir> [-n]
```

`-n` only lists the files that would change. `book-build.tcl` resolves
`file.md` links itself, so the step is optional; it helps when chapters are
also read on their own. Workflow context in MIGRATION.md.

---

## i18n-fix-anchors.tcl

Rewrites internal cross-reference anchors in a **translation** folder. When a
heading is translated, its slug changes (source slug → target slug); links
`](#slug)` copied from the source would otherwise point nowhere. The tool
replaces only anchors listed in the map — plain text that happens to contain a
slug stays untouched.

**Usage**

```
tclsh bookkit/tools/i18n-fix-anchors.tcl <bookdir> <anchor-map.tsv> [-n]
```

| Argument | Effect |
|---|---|
| `<bookdir>` | the **translation** folder, e.g. `my-book-en/`. |
| `<anchor-map.tsv>` | lines `source-slug<TAB>target-slug`; `#` comments are ignored. |
| `-n` | dry run: reports changes, writes nothing. |

Untranslated headings (identical slug) and code/proper-name titles need no
entry. **Proven approach:** dry run (`-n`) first, then apply without `-n`. The
dry run only counts links `](#slug)` whose slug is a source slug in the map. 0
reported anchors therefore only means that no link still points at a source slug
from the map (the map has been applied). The tool does not check whether the map
is complete — if a translated heading has no entry, its old link stays broken
unnoticed.

**Example**

```
tclsh bookkit/tools/i18n-fix-anchors.tcl my-book-en/ i18n/my-book-anchors-en.tsv -n
```

---

## i18n-check.tcl

Finds probably untranslated source language in a translation (a heuristic over
common function words/endings). Skips code blocks,
headings, inline code, Markdown links and URLs. **The only language-dependent part** of the tool chain (word list of
the source language, currently German).

**Usage**

```
tclsh bookkit/tools/i18n-check.tcl <translation-bookdir> [-verbose]
```

| Argument | Effect |
|---|---|
| `<translation-bookdir>` | the translation folder, e.g. `my-book-en/`. |
| `-verbose` | print every suspicious hit individually. |

Heuristic — no guarantee of completeness; meant as a final review pass before
releasing a translation.

---

## i18n-status.tcl

Shows which chapters of a translation lag behind the source, so the source
book can grow while the translation is brought up to date later. Pure Tcl,
8.6 and 9.

**Usage**

```
tclsh bookkit/tools/i18n-status.tcl <src-dir> <tr-dir>
tclsh bookkit/tools/i18n-status.tcl <src-dir> <tr-dir> -diff <chapter>
tclsh bookkit/tools/i18n-status.tcl <src-dir> <tr-dir> -mark <chapter> ...
tclsh bookkit/tools/i18n-status.tcl <src-dir> <tr-dir> -mark-all
```

| Option | Effect |
|---|---|
| (none) | one line per source chapter: `aktuell`, `veraltet`, `fehlt`, `unbekannt` (translated, never marked); `entfallen` for chapters no longer in the source |
| `-diff <chapter>` | lines changed in the source since the chapter was last marked (`-` old, `+` new) |
| `-mark <chapter> ...` | record the current source chapter as translated |
| `-mark-all` | mark every chapter that exists in the translation (starting point) |
| `-id <book-id>` | book-id; default from `i18n/<id>-anchors-<lang>.tsv` or the source folder name |

**Storage** next to the book folders: `i18n/<id>-sync-<lang>.tsv` (chapter,
CRC-32, date marked) and a snapshot of each marked source chapter in
`i18n/<id>-sync-<lang>/`. Lines starting with `*Stand:` are ignored when
comparing, so a mere date change does not make a translation outdated.

---

## index-dedupe.tcl

Keeps only the **first** `[term]{.index}` marker per term per file; further
occurrences of the same term in the same file are defused to plain text. Keeps
the subject index free of duplicates per page.

**Usage**

```
tclsh bookkit/tools/index-dedupe.tcl <book-root>
```

Works over all `.md` files under `<book-root>` and rewrites them in place.
Commit/back up before running.

---

## book-check.tcl

Runs the checks that otherwise happen by hand: with no arguments, every
source path in the registry (missing directory = error);
otherwise the given directories. Then: `index-dedupe -n`, `book.tcl`
versus `*.md`, exactly one H1 per chapter, relative `.md` links, `{.index}`
in table rows (warning), glossary filename `glossary/<book-id>-glossary.tsv`
(warning), book type: `booktype` missing in `book.tcl`, unknown, or different
from the book type column in the registry (warning). Does **not** rebuild PDF.

The registry is the first that exists of: `$BOOKKIT_REGISTRY`,
`bookkit-privat/REGISTRY.md` next to `bookkit/`, `bookkit/doc/de/REGISTRY.md`,
`bookkit/doc/REGISTRY.md`. Format: `doc/REGISTRY.example.md`.

**Usage**

```
tclsh bookkit/tools/book-check.tcl
tclsh bookkit/tools/book-check.tcl <bookdir> [<bookdir> ...]
```

Exit 1 if any error. Warnings do not fail the run.

---

## book-webindex.tcl

Produces the **web output** of a book for a Markdown server (mdserver): a
landing page `index.md` with a chapter table of contents and — when
`[term]{.index}` markers are present — a `stichwortverzeichnis.md` (subject
index) with jump marks to the exact spots. Only **managed blocks** are written;
your own prose around them is preserved (variant B). Pure Tcl, dual 8.6/9.

**Usage**

```
tclsh bookkit/tools/book-webindex.tcl <bookdir> [--dry-run] [--no-index]
```

| Option | Effect |
|---|---|
| `--dry-run` | only report, write nothing |
| `--no-index` | do not generate a subject index |

**Produces**

```
<bookdir>/index.md                 # <!-- bookkit:toc:begin/end -->  (chapter TOC + index link)
<bookdir>/stichwortverzeichnis.md  # <!-- bookkit:index:begin/end --> (only with {.index} markers)
```

Order and titles come from `book.tcl` (`chapters`, `title`, `tocTitle`,
`indexTitle`); without `book.tcl` from the `NNN-` prefix order. The subject-index
links point to `chapter.md#idx-N` — the anchors the renderer (docir) assigns to
the `{.index}` spans (1-based, in document order, including headings). Per
chapter only the **first** occurrence of a term is listed (like
`index-dedupe.tcl`).

**Interaction with `mdstack::indexgen`.** Directories with `book.tcl` (or a
`bookkit:toc` block) belong to bookkit; `mdstack::indexgen` does not create its
own `index.md` there but still lists the book in the parent index. Hence the
order: **first `book-webindex.tcl`, then `mdstack::indexgen`.**

---

## book-search.tcl

Full-text search across all books in the registry. Builds an SQLite database
(`bibliothek-suche.db` next to `bookkit/`); each chapter is split at its
headings, one section is one row. Two FTS5 indexes: words (case-insensitive,
accents folded) and trigrams for parts of words. `[term]{.index}` markers and
the glossary TSV files form a separate term table; a term hit is listed before
the full-text hits.

**Usage**

```
tclsh bookkit/tools/book-search.tcl index ?options?
tclsh bookkit/tools/book-search.tcl query ?options? word ?word ...?
tclsh bookkit/tools/book-search.tcl stats ?-db file?
```

**Options for `index`**

| Option | Effect |
|---|---|
| `-root dir` | workspace with the books (default: the directory above `bookkit/`) |
| `-registry file` | default: the registry as for `book-check.tcl` |
| `-db file` | default `<root>/bibliothek-suche.db` |
| `-book id` | only this book (repeatable) |
| `-dir path` | extra book directory outside the registry (repeatable) |
| `-lang l` | only directories of this language |
| `-pdf dir` | also index every PDF below `dir`, one hit per page (needs `tclutils::tupdftext`) |
| `-tclutils dir` | where tclutils is, if not on the module path |

**Options for `query`**

| Option | Effect |
|---|---|
| `-db file` | as above |
| `-book id` | only this book (repeatable) |
| `-limit n` | number of section hits (default 20) |
| `-sub` | substring search (trigrams) instead of words |
| `-prefix` | words as prefixes (`nativ` finds `nativename`) |
| `-raw` | the words are an FTS5 expression (`'wheel NOT Linux'`) |
| `-format f` | `text` (default) or `tsv` |

Without `-sub`, a word query that finds nothing is repeated as a substring
search. The index does not update itself: run `index` again after building.

---

## book-search-gui.tcl

Window for `book-search.tcl`, the only tool that uses Tk. Searches the same
database as you type; hits on the left (terms first), the whole section with
the search words highlighted on the right.

```
wish  bookkit/tools/book-search-gui.tcl ?-db file? ?-root dir? ?word ...?
tclsh bookkit/tools/book-search-gui.tcl ...      (loads Tk itself)
```

Keys: Return searches now, Ctrl+F or Escape go to the search field, Return or
a double click in the list opens the built HTML at the anchor, Ctrl+E the
chapter file, Ctrl+C copies `file:line`. "Index neu" runs
`book-search.tcl index` in a second process. Needs Tcl/Tk 8.6 or 9 and
`sqlite3` with FTS5.

---

## style-check.tcl

Checks a book's writing style against its book type. Counts
hints per chapter and rates them by `booktype` from `book.tcl`. Finds
clusters, not individual mistakes.

```
tclsh bookkit/tools/style-check.tcl ?-type T? ?-strict? ?-all? <bookdir>
```

| Switch | Meaning |
|---|---|
| `-type T` | book type if `book.tcl` has none, or to override: `textbook`, `workshop`, `manual`, `reference`, `developer` (German aliases accepted). Default: textbook, with a note |
| `-strict` | exit 1 if there are hints |
| `-all` | list chapters without hints as well |

Counted in running text (no YAML header, code blocks, inline code, link
targets): the German word field "Messung" (per 1000 words), dates, date
with time, "nicht gemessen/geprüft/…", `*Stand: …*` lines, mentions of AI
and how the book was made (allowed in the first chapter that has them),
book ids `` `book-…` `` (file names like `` `book-build.tcl` `` excluded),
"Zusammenfassung" sections (reference). `set styleallow {buchid}` in
`book.tcl` switches a check off when it is the book's subject (also `mess`,
`datum`, `nicht`, `summary`, `ki`, `stand`).
Appendices (`8nn-`, `9nn-`, "anhang") are counted, not rated. Limits per
type: see `doc/de/TOOLS.md`. Exit 0 (with `-strict` 1 on hints), 2 on bad
usage. The word lists are German.

---

## code-compare.tcl

Compares the code blocks of two versions of a book, e.g. before and after
converting it to a book type. Editing the text must not
change code.

```
tclsh bookkit/tools/code-compare.tcl ?-v? ?-strict? <old> <new>
```

Every block of `<old>` is looked up in `<new>`: unchanged (not listed),
`verschoben` (moved to another file), `Kommentar` (only comments changed;
an error with `-strict`), `FEHLT` (missing or code changed). Indentation
of the whole block is ignored; `-v` shows the lines. Exit 0 if nothing
is missing, 1 otherwise, 2 on bad usage.

---

## publish-check.tcl

Checks a tree before it is published: no work notes, private paths or
built files in it.

```
tclsh bookkit/tools/publish-check.tcl ?-privat dir? ?-deny file? ?-allow file? ?-quiet? <path> ...
```

`<path>` is what will be published, e.g. `bookkit` and a book folder.
General patterns are in `tools/publish-deny.tsv`, exceptions in
`tools/publish-allow.tsv`:

| Check | Finds |
|---|---|
| `datum` | an ISO date (history belongs in `CHANGES.md`) |
| `stand` | a `*Stand:*` / `*As of:*` line (allowed in `README.md` and `BUCHSTRUKTUR.md`) |
| `review`, `review-id` | review references such as "review 2026-…", "(B04)" |
| `ki` | names of AI tools (outside the first chapter that mentions them) |
| `heim` | `~/`, `/home/`, `/Users/` |
| `messung` | "measured on <date>" |
| `kommentar:historie` | history in Tcl comments ("previously", "no longer", "fixed") |
| `datei:erzeugt` | `.pdf`, `.html`, `.epub`, `.docx` in the source tree |
| `datei:notiz` | `TODO.md`, `NOTES.md`, `UEBERGABE.md`, … |

The private part (`-privat`, default `bookkit-privat/` next to `bookkit/`)
adds its own `publish-deny.tsv` and `publish-allow.tsv` (names of your own
projects and machines, which must not be in the public list) and the source
folders of all books in its `REGISTRY.md` (check `buch`), except books that
are themselves being checked.

Pattern file: `name<TAB>regex<TAB>hint`; a name starting with `datei:` tests
the relative path, one starting with `kommentar:` only comment lines in
`.tcl`. Exception file: `glob<TAB>name<TAB>regex` (regex optional, limits it
to matching lines). Exit 0 clean, 1 hits, 2 bad usage.

---

## Tests

```
tclsh bookkit/tests/run.tcl
```

Builds small books in a temporary directory and checks: links between
chapters (`file.md`, `file.md#anchor`, umlaut anchors via transliteration),
the warning for links without a target, CID font versus `-no-cid` (the PDF
part is skipped if pdf4tcl is missing), `manual-build.tcl -index` with
`-index-label`/`-index-title` and `-index-tsv`, and `index-gesamt.tcl`
(merging, `GoToR` links, `-links 0`). Same environment as for building.

---

## Typical workflow

A new, bilingual book from scratch:

```
# 1. create the scaffold
tclsh bookkit/tools/book-new.tcl my-book "My Book" -lang de -tr en

# 2. write chapters in my-book/ (source) and my-book-en/ (translation),
#    fill the glossary and anchor map

# 3. thin out index duplicates per file
tclsh bookkit/tools/index-dedupe.tcl my-book/

# 4. align translation anchors (dry run first)
tclsh bookkit/tools/i18n-fix-anchors.tcl my-book-en/ i18n/my-book-anchors-en.tsv -n
tclsh bookkit/tools/i18n-fix-anchors.tcl my-book-en/ i18n/my-book-anchors-en.tsv

# 5. check the translation for leftover source language
tclsh bookkit/tools/i18n-check.tcl my-book-en/

# 6. build (both languages)
tclsh bookkit/tools/book-build.tcl my-book/    -number
tclsh bookkit/tools/book-build.tcl my-book-en/ -number

# 7. web output for the mdserver (chapter TOC + subject index)
tclsh bookkit/tools/book-webindex.tcl my-book/

# 8. rebuild the search index
tclsh bookkit/tools/book-search.tcl index
```

Fitting in an existing book: instead of step 1, follow the checklist in
MIGRATION.md (flat one chapter/file, remove H1 numbers, generate `manifest`,
`book-migrate.tcl`, multi-column glossary), then from step 3.
