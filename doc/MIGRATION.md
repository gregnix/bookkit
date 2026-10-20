# bookkit — Migration

How to bring an **existing** book into the bookkit format — whether it consists
of loose numbered Markdown files, an older folder scheme (`100-part/`,
`200-part/` with `chapter-NN-….md`), or an already docir-like structure with
old conventions.

The goal of every migration: **one directory, one chapter per file, one
`book.tcl`, clean Markdown rules per `SPEC.md`** — and, where wanted, the
multilingual setup per `I18N.md`.

---

## Checklist

1. **One directory, one chapter per `.md`.** Dissolve nested part folders
   (`100-…/`, `200-…/`): move all chapter files flat into the book directory,
   with a continuous `NNN-` prefix.

2. **Remove numbers from H1–H3.** `# 4 — What TDBC is` becomes
   `# What TDBC is`. Numbering is done by the build (`-number`).

3. **Create `book.tcl`.** From the existing prefixes:

   ```bash
   tclsh bookkit/tools/book-build.tcl manifest <book-id>/
   ```

   Then fill in `title`, `subtitle`, `lang`, `tocTitle`, `indexTitle` and check
   the `chapters` order (order sub-chapters `04`/`04a` by hand).

4. **Check code fences.** Every non-heading line starting with `#` must be
   inside a ` ``` ` block, otherwise the build reads it as a chapter. Common
   culprits: shell comments, config examples.

5. **Set index markers.** Mark central terms inline as `[term]{.index}`. Then
   thin out duplicates per file:

   ```bash
   tclsh bookkit/tools/index-dedupe.tcl <book-id>/
   ```

6. **Convert cross-references to anchors.** Replace free-text references
   ("see chapter 6") with anchor links: `[see X](#heading-slug)`. Help:

   ```bash
   tclsh bookkit/tools/book-migrate.tcl <book-id>/
   ```

   Then build once and fix any remaining dead anchors.

7. **Migrate the glossary.** If an old two-column `-de-en.tsv` exists, prepend a
   header row and move it to `glossary/<book-id>-glossary.tsv` (see below).

8. **Multilingual** per `I18N.md`, if translations exist or are planned.

9. **Register** in `REGISTRY.md`.

---

## Dissolving an old folder scheme (example)

Starting point (older format):

```
TclTk-und-Datenbank/
    100-basics/chapter-01-tcl-and-database.md
    200-tdbc/chapter-04-what-tdbc-is.md
    ...
```

Target (bookkit):

```
database-handbook/
    010-tcl-and-database.md
    040-what-tdbc-is.md
    ...
    book.tcl
```

Approach: copy and rename files flat (continuous `NNN-` prefixes in reading
order), remove H1 numbers, then steps 3–7. The old `BUCHSTRUKTUR.md` is a good
template for the `chapters` order.

---

## Migrating the glossary (2-column → multi-column)

An old `<id>-de-en.tsv` with `german⇥english`:

```
Erweiterung	extension
Repository	repository
```

becomes the multi-column glossary by prepending a **header row** with the
language codes:

```
de	en
Erweiterung	extension
Repository	repository
```

Comment lines (`# …`) stay. New languages are added later as further columns.
Put the file at `glossary/<book-id>-glossary.tsv`.

---

## After the migration

Build once and proofread:

```bash
tclsh bookkit/tools/book-build.tcl <book-id>/ -number
```

For display in the mdserver, also generate the web output (chapter TOC +
subject index); then run `mdstack::indexgen` on the surrounding tree:

```bash
tclsh bookkit/tools/book-webindex.tcl <book-id>/
```

Check: numbering consistent, table of contents complete, subject index not
overloaded (use `index-dedupe.tcl` if needed), no dead anchors. Only then is
the book considered migrated and gets registered in `REGISTRY.md`.
