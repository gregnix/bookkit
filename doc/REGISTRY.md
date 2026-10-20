# bookkit — Book registry

Registry of all books that follow the bookkit format. One row per book; per
language a directory `<book-id>` or `<book-id>-<lang>`.

Build (from the workspace directory that holds the books and `bookkit/`):

```bash
tclsh bookkit/tools/book-build.tcl <book-id>/ -number
```

Output: `<book-id>.pdf` / `.html` one level above the book directory.

---

## Status

| book-id | Source | Languages | book.tcl | Note |
|---|---|---|---|---|
| tea | `book-tea/tea-de/` | de, en | yes | TEA handbook |
| tcltk9-fortgeschritten | `book-Programmierung-Fortgeschritten/TclTk-9-Programmierung-Fortgeschritten-de/` | de, en | yes | Advanced Tcl/Tk 9 |
| tcltk-canvas | `book-canvas/TclTk-Canvas-de/` | de (en planned) | yes | Tk canvas handbook |
| tcltk-text | `book-text-widget/TclTk-Text-de/` | de (en planned) | yes | Tk text widget |
| tcltk-tcloo | `book-tcloo/TclTk-TclOO-de/` | de (en planned) | yes | TclOO |
| linux-debian | `book-linux-debian/Debian-de/` | de (en planned) | yes | Debian: apt, Policy, four shell series (2026-10-20); Tcl text in book linux-tcltk |
|
| package-module | `book-package-module/Package-Module-de/` | de (en planned) | yes | tool book: package, pkgIndex, .tm |
| tclutils | `book-tclutils/Tclutils-de/` | de (en planned) | yes | tool book: tclutils 0.66.0 |
| tkutils | `book-tkutils/Tkutils-de/` | de (en planned) | yes | tool book: tkutils 0.47.0 |
| utils-stack | `book-utils-stack/Utils-Stack-de/` | de (en planned) | yes | tool book: pairing tclutils 0.66.0 / tkutils 0.47.0 / ctrlutils 0.4 |
| my-book | `bookkit/template/my-book/` | de, en | yes | reference in the template |

Columns:

- **Languages** — existing translations (ISO 639-1); planned ones in parentheses.
- **book.tcl** — manifest present?
- **Note** — maturity, special characteristics.

Register a new book: add a row once `book.tcl` exists and the book has built at
least once without errors.
