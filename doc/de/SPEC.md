# bookkit — Format-Spezifikation

Der verbindliche Standard für Bücher im **docir + mdstack + pdf4tcl**-Format.
Ein Buch, das dieser Spezifikation folgt, lässt sich mit `tools/book-build.tcl`
nach PDF und HTML bauen — mit hierarchischer Nummerierung, Inhalts- und
Stichwortverzeichnis — und ist ohne Umbau mehrsprachig erweiterbar.

Diese Datei ist die **einzige Quelle der Wahrheit** für das Format. Prozesse
stehen in `MIGRATION.md` (Altbestand überführen) und `I18N.md`
(Mehrsprachigkeit); das Buchregister in `REGISTRY.md`.

---

## 1. Verzeichnislayout

Ein Buch ist **ein Verzeichnis**, benannt nach seiner *book-id* (kleingeschrieben,
mit Bindestrichen). Übersetzungen sind eigene Verzeichnisse mit angehängtem
Sprachcode:

```
<book-id>/            # Quelle (Quellsprache in book.tcl deklariert)
<book-id>-en/         # englische Übersetzung, gleiche Dateinamen
<book-id>-fr/         # weitere Sprachen analog
glossary/             # mehrspaltige Glossare (gemeinsam)
i18n/                 # Anker-Maps je Übersetzung
bookkit/              # dieses Toolkit (Nachbar oder Submodul)
```

Die Build-Ausgabe (`<book-id>.pdf`, `<book-id>.html`) liegt **eine Ebene über**
dem Buchverzeichnis.

Für einen Markdown-Server (mdserver) erzeugt `book-webindex.tcl` zusätzlich eine
**Web-Ausgabe im Buchverzeichnis**: `index.md` (Kapitel-TOC) und – bei
`{.index}`-Markern – `stichwortverzeichnis.md`. Beide nutzen verwaltete Blöcke
(`<!-- bookkit:toc:… -->`, `<!-- bookkit:index:… -->`); Prosa darum bleibt
erhalten. Siehe `TOOLS.md`.

### Pflicht im Buchverzeichnis

- `book.tcl` — Manifest (Kapitelreihenfolge + Metadaten), siehe §2.
- Je Kapitel **eine** Markdown-Datei, Namenspräfix `NNN-` (z. B. `010-…`).

### Nicht ins Manifest

`README.md`, `CONTRIBUTING.md`, lose Notizen, Glossare und Build-Skripte gehören
**nicht** in die `chapters`-Liste. Nur echte Kapitel werden aufgenommen.

---

## 2. `book.tcl`

Das Manifest ist ein Tcl-Skript, das nur Variablen setzt:

```tcl
set title     "Titel"
set author    ""
set subtitle  "Untertitel"          ;# Titelseite
set date      ""                     ;# Titelseite (leer = keins)
set lang      "de"                   ;# Quellsprache bzw. Übersetzungscode
set titlePage 1                      ;# 1 = eigene Titelseite
set booktype  workshop               ;# Buchtyp, siehe STYLE.md

set tocTitle   "Inhaltsverzeichnis"  ;# in der jeweiligen Buchsprache
set indexTitle "Stichwortverzeichnis"

set chapters {
    010-einleitung.md
    020-thema.md
}
```

**Regeln**

- Reihenfolge **explizit** in `chapters` — nicht auf Dateipräfixe verlassen,
  sobald Unterkapitel existieren (`04` / `04a`).
- `tocTitle` / `indexTitle` in der Buchsprache setzen.
- `booktype`: `textbook`, `workshop`, `manual`, `reference` oder
  `developer` (Lehrbuch, Werkstattbuch, Handbuch, Referenz, Entwicklerbuch).
  Bestimmt den Sprachstil, siehe `STYLE.md`; `tools/style-check.tcl` liest es.
  Der Build ignoriert den Wert. Wahlweise `set styleallow {buchid}`: schaltet
  Hinweise der Stilprüfung ab, die zum Thema des Buchs gehören.
- `lang` deklariert die Sprache des Verzeichnisses (Quelle oder Übersetzung).
- Manifest aus vorhandenen Präfixen erzeugen:
  `tclsh bookkit/tools/book-build.tcl manifest <book-id>/`, danach prüfen.

---

## 3. Markdown-Regeln

### Überschriften

- **Keine Nummern** in H1–H3. `# Grundlagen`, nicht `# 1 Grundlagen`.
- Die Nummerierung kommt vom Build (`-number`): 1, 1.1, 1.1.1 …
- **Ein `#` (H1) pro Kapiteldatei.** Weitere Ebenen: `##`, `###`.
- Anker werden aus dem Überschriftstext abgeleitet — Querverweise überstehen
  ein Umsortieren der Kapitel.

### Code und `#`-Zeilen

**Pflicht:** Jede Zeile, die mit `#` beginnt und *keine* Überschrift ist, muss
in einem Code-Block stehen. Sonst deutet der Build sie als Kapitelüberschrift.

```markdown
## Beispiel

```bash
# Kommentar — nur korrekt, weil im Code-Block
git status
```
```

### Nie übersetzen / nicht als Fließtext setzen

- Code-Blöcke und Inline-`` `code` ``
- Befehle, Optionen, Dateinamen, Pfade, URLs, Umgebungsvariablen
- Etablierte Eigennamen (Stub, TEA, Starpack, tclkit, BAWT, Termux, …)

Kommentare **innerhalb** von Code-Blöcken dürfen die Quellsprache behalten,
auch in Übersetzungen.

---

## 4. Stichwortverzeichnis

Index-Begriffe inline markieren:

```markdown
Jede [Erweiterung]{.index} wird als Shared Library geladen.
```

- Markierung in **Fließtext** oder `##`-Überschriften, nicht in Tabellenzellen.
- Pro zentralem Begriff mindestens eine Markierung im relevanten Kapitel.
- Doppelte Markierungen desselben Begriffs je Datei ausdünnen:
  `tclsh bookkit/tools/index-dedupe.tcl <book-id>/`.
- Mehrsprachig: den Begriff in der Zielsprache markieren
  (`[extension]{.index}`), siehe `I18N.md`.

---

## 5. Querverweise

Innerhalb eines gebauten Buchs per Titel-Anker:

```markdown
Siehe das [Grundlagen-Kapitel](#grundlagen).
```

- **Label** in der Buchsprache.
- Anker = Slug des Ziel-Überschriftstexts (der Build/`docir` erzeugt ihn).
- Nach Übersetzung ändern sich Anker übersetzter Überschriften — siehe
  `I18N.md` und `tools/i18n-fix-anchors.tcl`.

---

## 6. Glossar

Ein **mehrspaltiges** TSV je Buch unter `glossary/<book-id>-glossary.tsv`:

```
# Kopfzeile = Sprachcodes; eine Zeile je Begriff, TAB-getrennt.
de	en	fr
Erweiterung	extension	extension
Repository	repository	dépôt
```

Zeilen mit `#` sind Kommentare. Neue Sprache = neue Spalte, kein Umbau. Ältere
zweispaltige `-de-en.tsv`-Glossare werden durch eine vorangestellte Kopfzeile
`de⇥en` migriert (siehe `MIGRATION.md`).

---

## 7. Bilder

Ein Buch darf Bilder enthalten (Bildschirmfotos, Fotos, vorgerenderte
Diagramme), in einfacher CommonMark-Syntax, als eigener Block oder inline:

```markdown
![Die Log-Ansicht nach dem ersten Lauf](images/logviewer.png)

Ein Klick auf das ![Speichern-Symbol](images/save.png) sichert den Eintrag.
```

Bei einem eigenen Block wird der Alternativtext zur Bildunterschrift
(`<figcaption>` in HTML, kursiv grau unter dem Bild im PDF); bei einem
Inline-Bild wird er nicht als Unterschrift gesetzt. Beide Formen nehmen einen
optionalen `"title"`.

**Pfade** sind **relativ zum Buchverzeichnis** (dort liegen die Kapitel und
`book.tcl`); ein Unterordner `images/` ist üblich, aber nicht vorgeschrieben.
Absolute Pfade und `http(s):`-URLs gehen unverändert ins HTML und werden
**nicht** ins PDF eingebettet (dort steht ersatzweise `[image: alt]`). Bilder
lokal halten.

**Formate:** PNG für Bildschirmfotos (verlustfrei), JPEG für Fotos. PDF kann
kein SVG einbetten. Ein Diagramm, das in HTML Vektor und im PDF Raster sein
soll, wird zweimal unter demselben Basisnamen ausgegeben (`abi.svg` und
`abi.png`); verwiesen wird auf die Datei der vorrangigen Ausgabe. Das
PDF-Backend lädt Bilddateien direkt von der Platte. **Tk ist für einen
Buchbau nicht nötig.**

Bilder, die breiter als die Textspalte sind, werden verkleinert, nie
vergrößert. Für den Druck etwa 200 dpi in der Endgröße anstreben
(Pixelbreite ungefähr das Achtfache der Zielbreite in mm). Ein PDF-Bildblock, der nicht mehr auf
die Seite passt, wandert ganz auf die nächste Seite und wird nie geteilt.
Eine fehlende Datei wird auf stderr gemeldet und als `[image: alt]` gesetzt;
der Bau bricht nicht ab.

**Mehrsprachige Bücher** halten lokalisierte Bildschirmfotos je Sprache. Weil
jede Übersetzung ein **eigenes Nachbarverzeichnis** ist (§1), wird das Bild
in jeder Sprache mit demselben relativen Pfad genannt und je Sprache eine
Kopie gehalten:

```
git-und-tcltk/      images/mainwindow.png     # deutsche Oberfläche
git-und-tcltk-en/   images/mainwindow.png     # englische Oberfläche
```

Ein Bildschirmfoto ohne Text darf geteilt werden: aus jeder Sprache mit einem
relativen Pfad auf die gemeinsame Datei verweisen.

---

## 8. Bauen

```bash
tclsh bookkit/tools/book-build.tcl <book-id>/ -number
```

`-number` vergibt die Nummern; die Quelle bleibt ohne. Alle Schalter (TOC,
Index, CID-Schrift, Tiefe, Titel, Ausgabedateien) stehen nur in **TOOLS.md**;
diese Spec legt das Buchformat fest, nicht die Aufrufe.
Laufzeit-Abhängigkeiten: `docir`, `mdstack`, `pdf4tcl` müssen erreichbar sein.

---

## 9. Werkzeuge (Überblick)

| Werkzeug | Zweck |
|---|---|
| `book-build.tcl` | Buch → PDF/HTML; `manifest`-Subkommando erzeugt `book.tcl` |
| `book-new.tcl` | neues Buch anlegen (Quelle + Übersetzungen + Glossar) |
| `book-migrate.tcl` | Cross-Refs → Anker, Index-Marker (Altbestand) |
| `manual-build.tcl` | aus nroff-Markdown ein Handbuch bauen (PDF/HTML) |
| `index-gesamt.tcl` | Gesamtindex-PDF über mehrere Handbuch-PDFs |
| `i18n-fix-anchors.tcl` | Anker in Übersetzung per Map umschreiben |
| `i18n-check.tcl` | vergessene Quellsprache in einer Übersetzung finden |
| `i18n-status.tcl` | welche übersetzten Kapitel hinter der Quelle zurück sind |
| `index-dedupe.tcl` | doppelte `[begriff]{.index}` je Datei ausdünnen |
| `book-check.tcl` | SPEC-Prüfung: Register, Dedupe dry-run, Manifest, H1, Links |
| `book-webindex.tcl` | Web-Ausgabe für mdserver: `index.md` + `stichwortverzeichnis.md` |
| `book-search.tcl` | Volltextsuche über alle Bücher (SQLite FTS5) |
| `book-search-gui.tcl` | Fenster zur Suche (braucht Tk, als einziges Werkzeug) |

Ausführliche Referenz je Werkzeug (Optionen, Beispiele): siehe **TOOLS.md**.
