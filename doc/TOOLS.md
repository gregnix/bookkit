# bookkit — Tools

Reference for the ten tools in `tools/`. Complements SPEC.md §9 (which is only
an overview). All tools are pure Tcl and run with `tclsh` (Tcl 8.6 or 9.0); none
needs Tk. `book-build.tcl` and `manual-build.tcl` additionally need `docir`,
`mdstack` and `pdf4tcl`.

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
| `manual-build.tcl` | merge nroff-derived manpage Markdown into one manual (PDF/HTML) |

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

**Subcommand `manifest`.** `book-build.tcl manifest <bookdir>` writes a
`book.tcl` from the existing `NNN-` prefixes (a starting point after a
migration; fine-tune by hand afterwards).

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
```

`-index` appends a subject index. Its terms are the command name and the
`Keywords:` of each page's YAML head (TIP 700); every chapter ends with a line
"*Stichwörter:* after, cancel, ..." whose entries go into the index as
`[term]{.index}`. `-index-label` replaces "Stichwörter", `-index-title`
"Stichwortverzeichnis" (e.g. `-index-label Keywords -index-title Index`).

`<dir>` is scanned recursively for `*.md`. The chapter body is taken verbatim
from the source Markdown (no docir round-trip). Runtime dependencies as for
`book-build.tcl`: `docir`, `mdstack`, `pdf4tcl` on the path (env vars
`DOCIR_HOME` / `MDSTACK_HOME` / `PDF4TCL_HOME`, or sibling search).

---

## book-new.tcl

Creates a new book with optional translations: a source folder with `book.tcl`
and two example chapters, one folder per target language (same file names), a
multi-column glossary and one anchor-map template each.

**Usage**

```
tclsh bookkit/tools/book-new.tcl <book-id> "Title" [-lang de] [-tr en,fr]
```

**Arguments/options**

| Argument | Effect |
|---|---|
| `<book-id>` | book ID (lowercase, hyphens); also the directory name. |
| `"Title"` | book title (in quotes). |
| `-lang <xx>` | source language (default `de`); set as `lang` in `book.tcl`. |
| `-tr <a,b,…>` | comma-separated target languages; one `<book-id>-<xx>/` is created each. |

**Result** (one level above `tools/`):

```
<book-id>/                        source chapters + book.tcl (lang = -lang)
<book-id>-<xx>/                   per -tr language, same file names
glossary/<book-id>-glossary.tsv   multi-column TSV (source + translations)
i18n/<book-id>-anchors-<xx>.tsv   anchor-map template per translation
```

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

One-off migration of existing material: rewrites cross-refs to book anchors in
the `.md` files and optionally sets index markers. The mapping file name → H1
anchor is stored as `array set anchor {…}` in the script and must match the old
book (aligned with the docir HTML output).

**Usage**

```
tclsh bookkit/tools/book-migrate.tcl <bookdir>
```

**Note.** A tool for converting existing books; not needed for new books. The
anchor table in the script is book-specific — check it before running. Workflow
context in MIGRATION.md.

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
source path in `bookkit/doc/de/REGISTRY.md` (missing directory = error);
otherwise the given directories. Then: `index-dedupe -n`, `book.tcl`
versus `*.md`, exactly one H1 per chapter, relative `.md` links, `{.index}`
in table rows (warning), glossary filename `glossary/<book-id>-glossary.tsv`
(warning). Does **not** rebuild PDF.

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
```

Fitting in an existing book: instead of step 1, follow the checklist in
MIGRATION.md (flat one chapter/file, remove H1 numbers, generate `manifest`,
`book-migrate.tcl`, multi-column glossary), then from step 3.
