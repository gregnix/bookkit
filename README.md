# bookkit

A standalone toolkit and rulebook for books in the **docir + mdstack +
pdf4tcl** format: Markdown chapters → PDF and HTML, with hierarchical
numbering, a table of contents and a subject index — and multilingual support
from the ground up.

For **new** books (template + generator) and for **migrating existing** books
into the format.

---

## Layout

```
bookkit/
    README.md         # this file
    CHANGES.md        # history of the tools
    doc/              # documentation (English at doc/, German at doc/de/)
        SPEC.md       # the binding format standard (rulebook)
        MIGRATION.md  # bring existing books into the format
        I18N.md       # multilingual support
        REGISTRY.example.md  # format of the book registry (your own one stays private)
        TOOLS.md      # per-tool reference
        STYLE.md      # writing style by book type (textbook, workshop, ...)
    tools/            # book-build, book-new, book-migrate, manual-build, index-gesamt, i18n-*, index-dedupe, book-webindex, book-search(-gui), style-check, code-compare, publish-check
    template/         # bilingual example book (reference)
    i18n/  glossary/  # anchor maps and multi-column glossaries
```

A book lives **next to** `bookkit/`:

```
my-workspace/
    bookkit/
    git-und-tcltk/        # book (source)
    git-und-tcltk-en/     # translation
    glossary/  i18n/
```

## Quick start

Create a new bilingual book:

```bash
cd my-workspace
tclsh bookkit/tools/book-new.tcl my-book "My Book" -lang de -tr en
```

Build:

```bash
tclsh bookkit/tools/book-build.tcl my-book/ -number
```

Migrate an existing book: see `doc/MIGRATION.md`. Add another language: see
`doc/I18N.md`.

## Private part and publishing

Your own book registry, notes and built PDFs stay out of the published tree,
in a folder `bookkit-privat/` next to `bookkit/` (never published):

```
my-workspace/
    bookkit/            # published
    bookkit-privat/     # private: REGISTRY.md, publish-deny.tsv, ...
    my-book/
```

`book-check.tcl` and `book-search.tcl` read the registry from there
(`doc/REGISTRY.example.md` shows the format). Before publishing:

```bash
tclsh bookkit/tools/publish-check.tcl bookkit my-book
```

It reports dates and review notes in comments, personal paths, names of
AI tools, built files (PDF, HTML) in the source tree, and everything listed
in `bookkit-privat/publish-deny.tsv` or as a source folder in the private
registry. Exit 1 on any hit. Details: `doc/TOOLS.md`.

## Runtime

The tools are Tcl scripts. The build (`book-build.tcl`) needs `docir`,
`mdstack` and `pdf4tcl` reachable (via `TCLLIBPATH` or the module path). The
remaining tools are pure Tcl.

## Origin

Extracted from the docir book format and consolidated — the same rules and
tools, only standalone and documented, with a multilingual glossary and
language-neutral tools.
