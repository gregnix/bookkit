# bookkit — Buchregister (Beispiel)

Das Register listet die Bücher eines Arbeitsverzeichnisses: eine Zeile je
Buch. `book-check.tcl` prüft ohne Argumente alle Quelle-Pfade daraus,
`book-search.tcl` baut daraus den Suchindex.

Das eigene Register ist meist privat und gehört nicht in den
veröffentlichten bookkit-Baum. Die Werkzeuge nehmen das erste, das es gibt:

1. die Datei in `$BOOKKIT_REGISTRY`,
2. `bookkit-privat/REGISTRY.md` neben `bookkit/`,
3. `bookkit/doc/de/REGISTRY.md`,
4. `bookkit/doc/REGISTRY.md`.

Diese Datei zeigt nur das Format; sie wird nicht gelesen.

## Status

| book-id | Quelle | Sprachen | book.tcl | Buchtyp | Anmerkung |
|---|---|---|---|---|---|
| mein-buch | `book-mein-buch/Mein-Buch-de/` | de, en | ja | `textbook` | Lehrbuch |
| handbuch | `book-handbuch/Handbuch-de/` | de | ja | `manual` | Handbuch |

- **book-id**: Kleinbuchstaben, Ziffern, `-`.
- **Quelle**: der innere Buchordner (mit `book.tcl`), relativ zum
  Arbeitsverzeichnis, in Backticks. Eine Übersetzung liegt daneben als
  `<name>-<lang>`.
- **Sprachen**: durch Komma getrennt; `de (en geplant)` zählt nur `de`.
- **Buchtyp**: wie `set booktype` in `book.tcl` (`textbook`, `workshop`,
  `manual`, `reference`, `developer`); weicht er ab, warnt `book-check.tcl`.
