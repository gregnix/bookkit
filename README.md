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
    SPEC.md       # the binding format standard (rulebook)
    MIGRATION.md  # bring existing books into the format
    I18N.md       # multilingual support
    REGISTRY.md   # registry of all books
    tools/        # book-build, book-new, book-migrate, i18n-*, index-dedupe, book-webindex
    template/     # bilingual example book (reference)
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

Migrate an existing book: see `MIGRATION.md`. Add another language: see
`I18N.md`.

## Runtime

The tools are Tcl scripts. The build (`book-build.tcl`) needs `docir`,
`mdstack` and `pdf4tcl` reachable (via `TCLLIBPATH` or the module path). The
remaining tools are pure Tcl.

## Origin

Extracted and consolidated from the docir book format of the manuals
*TclTk-Compile-und-Erweiterung* and *TclTk-und-Datenbank* — the same rules and
tools, only standalone and documented, with a multilingual glossary and
language-neutral tools.
