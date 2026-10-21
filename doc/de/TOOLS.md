# bookkit — Werkzeuge

Referenz zu den zehn Werkzeugen in `tools/`. Ergänzt SPEC.md §9 (dort nur ein
Überblick). Alle Werkzeuge sind reines Tcl und laufen mit `tclsh` (Tcl 8.6 oder
9.0); keines braucht Tk. `book-build.tcl` und `manual-build.tcl` brauchen
zusätzlich `docir`, `mdstack` und `pdf4tcl`.

**Arbeitsverzeichnis.** Die Werkzeuge werden eine Ebene *über* dem Buchordner
aufgerufen — dort, wo die Buchverzeichnisse (`<id>/`, `<id>-<lang>/`), `glossary/`
und `i18n/` nebeneinander liegen. Pfadangaben zu `tools/` sind relativ zu diesem
Ort (z. B. `tclsh bookkit/tools/book-build.tcl ...`).

Übersicht:

| Werkzeug | Zweck |
|---|---|
| `book-build.tcl` | Buch nach PDF/HTML/Markdown bauen; `manifest`-Subkommando erzeugt `book.tcl` |
| `book-new.tcl` | neues Buch anlegen (Quelle + Übersetzungen + Glossar + Anker-Maps) |
| `book-migrate.tcl` | Altbestand einpassen: Cross-Refs → Anker, Index-Marker |
| `manual-build.tcl` | aus nroff-Markdown ein Handbuch bauen (PDF/HTML) |
| `i18n-fix-anchors.tcl` | Anker in einer Übersetzung per Map umschreiben |
| `i18n-check.tcl` | vergessene Quellsprache in einer Übersetzung finden |
| `i18n-status.tcl` | welche übersetzten Kapitel hinter der Quelle zurück sind; Diff seit der letzten Übersetzung |
| `index-dedupe.tcl` | doppelte `[begriff]{.index}` je Datei ausdünnen |
| `book-check.tcl` | SPEC-Prüfung: Registerpfade, `index-dedupe -n`, Manifest, eine H1, `.md`-Links |
| `book-webindex.tcl` | Web-Ausgabe für mdserver: `index.md` (Kapitel-TOC) + `stichwortverzeichnis.md` |

---

## book-build.tcl

Baut ein Buch aus Markdown-Kapiteln nach PDF und/oder HTML (und optional
Markdown), mit hierarchischer Auto-Nummerierung, Inhaltsverzeichnis und
Stichwortverzeichnis.

**Aufruf**

```
tclsh bookkit/tools/book-build.tcl <bookdir> [Optionen]
tclsh bookkit/tools/book-build.tcl manifest <bookdir>
```

**Kapitelreihenfolge.** Existiert `<bookdir>/book.tcl`, bestimmt dessen Variable
`chapters` die Reihenfolge (die numerischen Dateipräfixe werden dann ignoriert).
Ohne `book.tcl` werden die `.md`-Dateien nach ihrem `NNN-`-Präfix sortiert.

**Optionen**

| Option | Wirkung |
|---|---|
| `-pdf <datei>` | PDF-Ziel. Ohne `-pdf`/`-html`/`-md` werden PDF **und** HTML neben `<bookdir>` erzeugt. |
| `-html <datei>` | HTML-Ziel. |
| `-md <datei>` | zusammengeführtes Markdown ausgeben. |
| `-number` | Überschriften hierarchisch nummerieren (H1 `1`, H2 `1.1`, …). |
| `-no-toc` | kein Inhaltsverzeichnis. |
| `-no-index` | kein Stichwortverzeichnis. |
| `-no-cid` | PDF-Schriften mit 256-Zeichen-Teilmenge statt vollem Unicode (CID-Modus, Standard). Kleinere Datei; ⌘ ⌥ → ∂ und ähnliche werden zu `?`. |
| `-depth <N>` | Nummerierungs-/TOC-Tiefe (Standard aus dem Build). |
| `-title <T>` | Titel überschreiben (sonst aus `book.tcl`). |
| `-author <A>` | Autor überschreiben. |
| `-subtitle <S>` | Untertitel überschreiben. |
| `-date <D>` | Datum überschreiben. |
| `-title-page` | Titelseite erzwingen. |
| `-toc-title <T>` | Überschrift des Inhaltsverzeichnisses. |
| `-index-title <T>` | Überschrift des Stichwortverzeichnisses. |

**Subkommando `manifest`.** `book-build.tcl manifest <bookdir>` schreibt eine
`book.tcl` aus den vorhandenen `NNN-`-Präfixen (Startpunkt nach einer Migration;
danach von Hand feinjustieren).

**Laufzeit-Abhängigkeiten.** Braucht `docir`, `mdstack`, `pdf4tcl` und
`pdf4tcllib` auf dem Pfad. Sie werden automatisch gesucht (Nachbarverzeichnisse,
`$HOME/code/git/github`, `$HOME/lib/tcltk`, `/usr/local/lib/tcltk`) oder explizit
über die Umgebungsvariablen `DOCIR_HOME`, `MDSTACK_HOME`, `PDF4TCL_HOME`,
`PDF4TCLLIB_HOME` gesetzt; `REPOS_DIR` fügt eine weitere Suchbasis hinzu.

**Beispiele**

```
# beides (PDF + HTML) neben dem Buchordner, nummeriert
tclsh bookkit/tools/book-build.tcl mein-buch/ -number

# nur PDF, ohne Stichwortverzeichnis
tclsh bookkit/tools/book-build.tcl mein-buch/ -number -no-index -pdf mein-buch.pdf

# Manifest aus den NNN-Präfixen erzeugen
tclsh bookkit/tools/book-build.tcl manifest mein-buch/
```


**Links.** Kapitelverweise (`[Kapitel 3](030-x.md)`, `030-x.md#id`) werden
zu `#id`-Sprüngen auf die erste Überschrift des Kapitels bzw. die genannte
Kennung; `#id`-Links werden gegen die Überschriften geprüft (eine
Umlaut-Schreibung mit ae/oe/ue/ss löst ebenfalls auf). Links ohne Ziel meldet
der Bau (`WARNUNG: … Verweis(e) ohne Ziel`) und lässt sie unverändert. Im PDF
springen Inhaltsverzeichnis, Stichwortverzeichnis und diese Links im Dokument; dafür braucht es
pdf4tcl 0.9.4.72 — mit älterem pdf4tcl entsteht das PDF
ohne interne Links.

---

## manual-build.tcl

Fügt einen Baum aus nroff-abgeleitetem Manpage-Markdown zu **einem**
Markdown-Handbuch zusammen (optional auch PDF/HTML). Anders als
`book-build.tcl` (für von Hand geschriebene Kapitel ohne Nummern) ist das für
umgewandelte Manpages mit eigenen Abschnitten NAME/DESCRIPTION und
YAML-Vorspann: jede Manpage wird ein Kapitel mit dem Befehlsnamen als Titel,
die eigenen Abschnitte rücken eine Ebene nach unten (`# after` / `## NAME` /
`## DESCRIPTION`).

**Aufruf**

```
tclsh bookkit/tools/manual-build.tcl <verzeichnis> [-md out.md] [-pdf out.pdf] [-html out.html] [-title T]
                                     [-license datei ...] [-index] [-index-label L] [-index-title T]
```

`-index` hängt ein Stichwortverzeichnis an. Die Begriffe sind der
Befehlsname und die `Keywords:` aus dem YAML-Kopf jeder Seite (TIP 700);
jedes Kapitel endet mit einer Zeile „*Stichwörter:* after, cancel, …“, deren
Einträge als `[begriff]{.index}` ins Verzeichnis gehen. `-index-label`
ändert „Stichwörter“, `-index-title` „Stichwortverzeichnis“. Gemessen an
`de-markdown/9.0`: 221 Seiten, Verzeichnis 12 Seiten.

`<verzeichnis>` wird rekursiv nach `*.md` durchsucht. Der Kapiteltext wird
wörtlich aus dem Quell-Markdown genommen (kein Umweg über docir).
Laufzeit-Abhängigkeiten wie bei `book-build.tcl`: `docir`, `mdstack`,
`pdf4tcl` auf dem Pfad (Umgebungsvariablen `DOCIR_HOME` / `MDSTACK_HOME` /
`PDF4TCL_HOME`, oder Suche in Nachbarverzeichnissen).

---

## book-new.tcl

Legt ein neues Buch samt optionaler Übersetzungen an: Quellordner mit
`book.tcl` und zwei Beispielkapiteln, je einen Ordner pro Zielsprache
(gleiche Dateinamen), ein mehrspaltiges Glossar und je eine Anker-Map-Vorlage.

**Aufruf**

```
tclsh bookkit/tools/book-new.tcl <book-id> "Titel" [-lang de] [-tr en,fr]
```

**Argumente/Optionen**

| Argument | Wirkung |
|---|---|
| `<book-id>` | Buch-ID (kleingeschrieben, Bindestriche); zugleich Verzeichnisname. |
| `"Titel"` | Buchtitel (in Anführungszeichen). |
| `-lang <xx>` | Quellsprache (Standard `de`); wird als `lang` in `book.tcl` gesetzt. |
| `-tr <a,b,…>` | kommagetrennte Zielsprachen; je eine `<book-id>-<xx>/` wird angelegt. |

**Ergebnis** (eine Ebene über `tools/`):

```
<book-id>/                        Quellkapitel + book.tcl (lang = -lang)
<book-id>-<xx>/                   je -tr-Sprache, gleiche Dateinamen
glossary/<book-id>-glossary.tsv   mehrspaltiges TSV (Quelle + Übersetzungen)
i18n/<book-id>-anchors-<xx>.tsv   Anker-Map-Vorlage je Übersetzung
```

Überschriften tragen **keine** Nummern (die vergibt der Build). Siehe SPEC.md.

Unter Tcl 8.6 kommt ein Titel mit Umlaut als UTF-8-Bytes an. `book-new.tcl`
dekodiert ihn einmal (`encoding convertfrom utf-8`), sonst landet
„Ãrger“ auf der Titelseite. Tcl 9 braucht das nicht.

**Beispiel**

```
tclsh bookkit/tools/book-new.tcl mein-buch "Mein Buch" -lang de -tr en,fr
```

---

## book-migrate.tcl

Einmalige Migration von Altbestand: schreibt in den `.md`-Dateien Cross-Refs auf
Buch-Anker um und setzt optional Index-Marker. Die Zuordnung Dateiname → H1-Anker
steht als `array set anchor {…}` im Skript und muss zum Altbuch passen (an die
docir-HTML-Ausgabe angeglichen).

**Aufruf**

```
tclsh bookkit/tools/book-migrate.tcl <bookdir>
```

**Hinweis.** Werkzeug für den Umstieg bestehender Bücher; für neue Bücher nicht
nötig. Die Anker-Tabelle im Skript ist buchspezifisch — vor dem Lauf prüfen.
Ablauf-Kontext in MIGRATION.md.

---

## i18n-fix-anchors.tcl

Schreibt interne Querverweis-Anker in einem **Übersetzungs**-Ordner um. Wird eine
Überschrift übersetzt, ändert sich ihr Slug (Quell-Slug → Ziel-Slug); aus der
Quelle kopierte Links `](#slug)` zeigen sonst ins Leere. Das Werkzeug ersetzt nur
Anker, die in der Map stehen — Klartext, der zufällig einen Slug enthält, bleibt
unberührt.

**Aufruf**

```
tclsh bookkit/tools/i18n-fix-anchors.tcl <bookdir> <anchor-map.tsv> [-n]
```

| Argument | Wirkung |
|---|---|
| `<bookdir>` | der **Übersetzungs**-Ordner, z. B. `mein-buch-en/`. |
| `<anchor-map.tsv>` | Zeilen `quell-slug<TAB>ziel-slug`; `#`-Kommentare werden ignoriert. |
| `-n` | Trockenlauf: meldet Änderungen, schreibt nichts. |

Nicht übersetzte Überschriften (identischer Slug) sowie Code-/Eigennamen-Titel
brauchen keinen Eintrag. **Bewährt:** erst Trockenlauf (`-n`), dann ohne `-n`
anwenden. Der Trockenlauf zählt nur Links `](#slug)`, deren Slug als Quell-Slug
in der Map steht. 0 gemeldete Anker heißt daher nur: Kein Link zeigt mehr auf
einen Quell-Slug aus der Map (die Map ist schon angewendet). Ob die Map
vollständig ist, prüft das Werkzeug nicht — fehlt der Eintrag für eine übersetzte
Überschrift, bleibt der alte Link unbemerkt stehen.

**Beispiel**

```
tclsh bookkit/tools/i18n-fix-anchors.tcl mein-buch-en/ i18n/mein-buch-anchors-en.tsv -n
```

---

## i18n-check.tcl

Findet wahrscheinlich unübersetzte Quellsprache in einer Übersetzung
(Heuristik über häufige Funktionswörter/Endungen). Überspringt Code-Blöcke,
Überschriften, Inline-Code, Markdown-Links und URLs. **Einzige sprachabhängige Stelle** der
Werkzeugkette (Wortliste der Quellsprache, aktuell Deutsch).

**Aufruf**

```
tclsh bookkit/tools/i18n-check.tcl <bookdir-übersetzung> [-verbose]
```

| Argument | Wirkung |
|---|---|
| `<bookdir-übersetzung>` | der Übersetzungs-Ordner, z. B. `mein-buch-en/`. |
| `-verbose` | jede verdächtige Fundstelle einzeln ausgeben. |

Heuristik — keine Garantie auf Vollständigkeit; als letzter Sichtungslauf vor
der Freigabe einer Übersetzung gedacht.

---

## i18n-status.tcl

Zeigt, welche Kapitel einer Übersetzung hinter der Quelle zurück sind. So kann
das Quellbuch wachsen, und die Übersetzung wird nachgezogen, wenn Zeit ist.
Reines Tcl, 8.6 und 9.

**Aufruf**

```
tclsh bookkit/tools/i18n-status.tcl <quelle> <übersetzung>
tclsh bookkit/tools/i18n-status.tcl <quelle> <übersetzung> -diff <kapitel>
tclsh bookkit/tools/i18n-status.tcl <quelle> <übersetzung> -mark <kapitel> ...
tclsh bookkit/tools/i18n-status.tcl <quelle> <übersetzung> -mark-all
```

| Option | Wirkung |
|---|---|
| (keine) | eine Zeile je Quellkapitel: `aktuell`, `veraltet`, `fehlt`, `unbekannt` (übersetzt, nie markiert); `entfallen` für Kapitel, die die Quelle nicht mehr hat |
| `-diff <kapitel>` | Zeilen, die sich in der Quelle seit der letzten Markierung geändert haben (`-` alt, `+` neu) |
| `-mark <kapitel> ...` | aktuelles Quellkapitel als übersetzt festhalten |
| `-mark-all` | alle Kapitel markieren, die die Übersetzung hat (Ausgangsstand) |
| `-id <book-id>` | book-id; sonst aus `i18n/<id>-anchors-<lang>.tsv` oder dem Quellordner |

**Ablage** neben den Buchordnern: `i18n/<id>-sync-<lang>.tsv` (Kapitel,
CRC-32, Datum) und je markiertem Kapitel eine Kopie der Quelle in
`i18n/<id>-sync-<lang>/`. Zeilen mit `*Stand:` zählen beim Vergleich nicht;
ein neues Datum allein macht keine Übersetzung veraltet.

**Ablauf beim Nachziehen**

1. `i18n-status.tcl` zeigt veraltete und fehlende Kapitel.
2. Veraltet: `-diff <kapitel>` zeigt die Änderung; nur diese Stellen im
   übersetzten Kapitel nachziehen. Fehlt: Kapitel ganz übersetzen und in die
   `book.tcl` der Übersetzung eintragen.
3. `i18n-fix-anchors.tcl`, `i18n-check.tcl`, `book-check.tcl`.
4. `-mark <kapitel>`.

---

## index-dedupe.tcl

Behält je Datei nur den **ersten** `[begriff]{.index}`-Marker pro Begriff; weitere
Vorkommen desselben Begriffs in derselben Datei werden zu reinem Text entschärft.
Hält das Stichwortverzeichnis pro Seite frei von Dubletten.

**Aufruf**

```
tclsh bookkit/tools/index-dedupe.tcl <book-root>
```

Arbeitet über alle `.md`-Dateien unter `<book-root>` und schreibt sie an Ort und
Stelle um. Vor dem Lauf committen/sichern.

---

## book-check.tcl

Prüft, was sonst von Hand läuft: ohne Argumente alle Quelle-Pfade aus
`bookkit/doc/de/REGISTRY.md` (fehlendes Verzeichnis = Fehler), sonst die
übergebenen Ordner. Danach: `index-dedupe -n`, Manifest gegen `*.md`,
genau eine H1 je Kapitel, relative `.md`-Links, `{.index}` in Tabellenzeilen
(Warnung), Glossarname (Warnung). Baut **kein** PDF.

**Aufruf**

```
tclsh bookkit/tools/book-check.tcl
tclsh bookkit/tools/book-check.tcl <bookdir> [<bookdir> ...]
```

Exit 1 bei Fehler. Warnungen allein nicht.

---


## book-webindex.tcl

Erzeugt die **Web-Ausgabe** eines Buchs für einen Markdown-Server (mdserver):
eine Landeseite `index.md` mit Kapitel-Inhaltsverzeichnis und – bei
`[begriff]{.index}`-Markern – ein `stichwortverzeichnis.md` mit Sprungmarken
auf die genauen Stellen. Es werden nur **verwaltete Blöcke** geschrieben; eigene
Prosa darum bleibt erhalten (Variante B). Reines Tcl, dual 8.6/9.

**Aufruf**

```
tclsh bookkit/tools/book-webindex.tcl <bookdir> [--dry-run] [--no-index]
```

| Option | Wirkung |
|---|---|
| `--dry-run` | nur anzeigen, nichts schreiben |
| `--no-index` | kein Stichwortverzeichnis erzeugen |

**Erzeugt**

```
<bookdir>/index.md                 # <!-- bookkit:toc:begin/end -->  (Kapitel-TOC + Register-Link)
<bookdir>/stichwortverzeichnis.md  # <!-- bookkit:index:begin/end --> (nur bei {.index}-Markern)
```

Reihenfolge und Titel kommen aus `book.tcl` (`chapters`, `title`, `tocTitle`,
`indexTitle`); ohne `book.tcl` aus der `NNN-`-Präfix-Ordnung. Die Register-Links
zeigen auf `kapitel.md#idx-N` – die Anker, die der Renderer (docir) den
`{.index}`-Spans vergibt (1-basiert, in Dokumentreihenfolge, inkl.
Überschriften). Je Kapitel wird nur das **erste** Vorkommen eines Begriffs
gelistet (wie `index-dedupe.tcl`).

**Zusammenspiel mit `mdstack::indexgen`.** Verzeichnisse mit `book.tcl` (oder
einem `bookkit:toc`-Block) gehören bookkit; `mdstack::indexgen` erzeugt dort
keine eigene `index.md`, listet das Buch aber im Eltern-Index. Deshalb die
Reihenfolge: **erst `book-webindex.tcl`, dann `mdstack::indexgen`.**

---

## Typischer Ablauf

Neues, zweisprachiges Buch von Grund auf:

```
# 1. Gerüst anlegen
tclsh bookkit/tools/book-new.tcl mein-buch "Mein Buch" -lang de -tr en

# 2. Kapitel schreiben in mein-buch/ (Quelle) und mein-buch-en/ (Übersetzung),
#    Glossar und Anker-Map füllen

# 3. Index-Dubletten je Datei ausdünnen
tclsh bookkit/tools/index-dedupe.tcl mein-buch/

# 4. Übersetzungs-Anker angleichen (erst trocken)
tclsh bookkit/tools/i18n-fix-anchors.tcl mein-buch-en/ i18n/mein-buch-anchors-en.tsv -n
tclsh bookkit/tools/i18n-fix-anchors.tcl mein-buch-en/ i18n/mein-buch-anchors-en.tsv

# 5. Übersetzung auf Restdeutsch prüfen
tclsh bookkit/tools/i18n-check.tcl mein-buch-en/

# 6. Bauen (beide Sprachen)
tclsh bookkit/tools/book-build.tcl mein-buch/    -number
tclsh bookkit/tools/book-build.tcl mein-buch-en/ -number

# 7. Web-Ausgabe fuer den mdserver (Kapitel-TOC + Stichwortverzeichnis)
tclsh bookkit/tools/book-webindex.tcl mein-buch/
```

Bestehendes Buch einpassen: statt Schritt 1 die Checkliste in MIGRATION.md
(flach 1 Kapitel/Datei, H1-Nummern raus, `manifest` erzeugen, `book-migrate.tcl`,
Glossar mehrspaltig), dann ab Schritt 3.
