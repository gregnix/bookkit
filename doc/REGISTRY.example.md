# bookkit — book registry (example)

The registry lists the books of a workspace, one row per book. With no
arguments, `book-check.tcl` checks every source path in it, and
`book-search.tcl` builds its search index from it.

Your own registry is usually private and does not belong in the published
bookkit tree. The tools take the first one that exists:

1. the file in `$BOOKKIT_REGISTRY`,
2. `bookkit-privat/REGISTRY.md` next to `bookkit/`,
3. `bookkit/doc/de/REGISTRY.md`,
4. `bookkit/doc/REGISTRY.md`.

This file only shows the format; it is not read.

## Status

| book-id | Source | Languages | book.tcl | Book type | Note |
|---|---|---|---|---|---|
| my-book | `book-my-book/My-Book-en/` | en, de | yes | `textbook` | textbook |
| handbook | `book-handbook/Handbook-en/` | en | yes | `manual` | handbook |

- **book-id**: lower case, digits, `-`.
- **Source**: the inner book folder (with `book.tcl`), relative to the
  workspace, in backticks. A translation sits next to it as
  `<name>-<lang>`.
- **Languages**: comma-separated; `de (en planned)` counts only `de`.
- **Book type**: as `set booktype` in `book.tcl` (`textbook`, `workshop`,
  `manual`, `reference`, `developer`); `book-check.tcl` warns on a mismatch.
