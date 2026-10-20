# bookkit — Migration

So bringt man ein **vorhandenes** Buch in das bookkit-Format — egal ob es aus
losen nummerierten Markdown-Dateien besteht, aus einem älteren Ordner-Schema
(`100-teil/`, `200-teil/` mit `kapitel-NN-…md`) oder aus einer bereits
docir-ähnlichen Struktur mit alten Konventionen.

Das Ziel jeder Migration: **ein Verzeichnis, ein Kapitel je Datei, ein
`book.tcl`, saubere Markdown-Regeln nach `SPEC.md`** — und, wo gewünscht, die
Mehrsprachigkeit nach `I18N.md`.

---

## Checkliste

1. **Ein Verzeichnis, ein Kapitel je `.md`.** Verschachtelte Teil-Ordner
   (`100-…/`, `200-…/`) auflösen: alle Kapiteldateien flach ins
   Buchverzeichnis, mit durchlaufendem `NNN-`-Präfix.

2. **Nummern aus H1–H3 entfernen.** `# 4 — Was TDBC ist` wird zu
   `# Was TDBC ist`. Die Nummerierung übernimmt der Build (`-number`).

3. **`book.tcl` erzeugen.** Aus den vorhandenen Präfixen:

   ```bash
   tclsh bookkit/tools/book-build.tcl manifest <book-id>/
   ```

   Danach `title`, `subtitle`, `lang`, `tocTitle`, `indexTitle` eintragen und
   die `chapters`-Reihenfolge prüfen (Unterkapitel `04`/`04a` von Hand ordnen).

4. **Code-Fences prüfen.** Jede mit `#` beginnende Nicht-Überschrift muss in
   einem ` ``` `-Block stehen, sonst deutet der Build sie als Kapitel. Häufige
   Übeltäter: Shell-Kommentare, Konfig-Beispiele.

5. **Index-Marker setzen.** Zentrale Begriffe inline als `[begriff]{.index}`
   markieren. Anschließend Dubletten je Datei ausdünnen:

   ```bash
   tclsh bookkit/tools/index-dedupe.tcl <book-id>/
   ```

6. **Querverweise auf Anker umstellen.** Freitext-Verweise („siehe Kapitel 6")
   durch Anker-Links ersetzen: `[siehe X](#slug-der-ueberschrift)`. Hilfe:

   ```bash
   tclsh bookkit/tools/book-migrate.tcl <book-id>/
   ```

   Danach einmal bauen und verbliebene tote Anker korrigieren.

7. **Glossar überführen.** Falls ein altes zweispaltiges `-de-en.tsv` existiert,
   Kopfzeile voranstellen und nach `glossary/<book-id>-glossary.tsv` bringen
   (siehe unten).

8. **Mehrsprachigkeit** nach `I18N.md`, falls Übersetzungen bestehen oder
   geplant sind.

9. **Registrieren** in `REGISTRY.md`.

---

## Altes Ordner-Schema auflösen (Beispiel)

Ausgangslage (älteres Format):

```
TclTk-und-Datenbank/
    100-grundlagen/kapitel-01-tcl-und-datenbank.md
    200-tdbc/kapitel-04-was-tdbc-ist.md
    ...
```

Ziellage (bookkit):

```
datenbank-handbook/
    010-tcl-und-datenbank.md
    040-was-tdbc-ist.md
    ...
    book.tcl
```

Vorgehen: Dateien flach kopieren und umbenennen (durchlaufende `NNN-`-Präfixe
in Lesereihenfolge), H1-Nummern entfernen, dann Schritte 3–7. Die alte
`BUCHSTRUKTUR.md` ist eine gute Vorlage für die `chapters`-Reihenfolge.

---

## Glossar migrieren (2-spaltig → mehrspaltig)

Ein altes `<id>-de-en.tsv` mit `deutsch⇥englisch`:

```
Erweiterung	extension
Repository	repository
```

wird zum mehrspaltigen Glossar durch eine vorangestellte **Kopfzeile** mit den
Sprachcodes:

```
de	en
Erweiterung	extension
Repository	repository
```

Die Kommentarzeilen (`# …`) bleiben. Neue Sprachen kommen später als weitere
Spalten hinzu. Datei nach `glossary/<book-id>-glossary.tsv` legen.

---

## Nach der Migration

Einmal vollständig bauen und gegenlesen:

```bash
tclsh bookkit/tools/book-build.tcl <book-id>/ -number
```

Für die Anzeige im mdserver zusätzlich die Web-Ausgabe erzeugen (Kapitel-TOC +
Stichwortverzeichnis); danach `mdstack::indexgen` für den umgebenden Baum:

```bash
tclsh bookkit/tools/book-webindex.tcl <book-id>/
```

Prüfen: Nummerierung stimmig, Inhaltsverzeichnis vollständig,
Stichwortverzeichnis nicht überladen (ggf. `index-dedupe.tcl`), keine toten
Anker. Erst dann gilt das Buch als überführt und wird in `REGISTRY.md`
eingetragen.
