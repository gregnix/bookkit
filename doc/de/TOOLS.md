# bookkit — Werkzeuge

Referenz zu den vierzehn Werkzeugen in `tools/`. Ergänzt SPEC.md §9 (dort nur ein
Überblick). **Diese Datei ist die verbindliche Liste der Schalter**; SPEC.md
und das Bookkit-Buch verweisen hierher. Alle Werkzeuge sind reines Tcl und
laufen mit `tclsh` (Tcl 8.6 oder 9.0). Ausnahme: `book-search-gui.tcl` braucht
Tk. `book-build.tcl` und `manual-build.tcl` brauchen zusätzlich `docir`,
`mdstack` und `pdf4tcl`, `book-search.tcl` und die GUI das Paket `sqlite3`
mit FTS5.

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
| `index-gesamt.tcl` | ein Gesamtindex-PDF über mehrere Handbuch-PDFs (Verweise in die PDFs) |
| `i18n-fix-anchors.tcl` | Anker in einer Übersetzung per Map umschreiben |
| `i18n-check.tcl` | vergessene Quellsprache in einer Übersetzung finden |
| `i18n-status.tcl` | welche übersetzten Kapitel hinter der Quelle zurück sind; Diff seit der letzten Übersetzung |
| `index-dedupe.tcl` | doppelte `[begriff]{.index}` je Datei ausdünnen |
| `book-check.tcl` | SPEC-Prüfung: Registerpfade, `index-dedupe -n`, Manifest, eine H1, `.md`-Links |
| `book-webindex.tcl` | Web-Ausgabe für mdserver: `index.md` (Kapitel-TOC) + `stichwortverzeichnis.md` |
| `style-check.tcl` | Sprachstil nach Buchtyp prüfen: Messung, Datum, Entstehung je Kapitel |
| `code-compare.tcl` | Codeblöcke zweier Fassungen eines Buchs vergleichen (nach einer Überarbeitung) |
| `publish-check.tcl` | vor dem Veröffentlichen: keine Notizen, privaten Pfade oder gebauten Dateien im Baum |

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
| `-allow-missing` | ein in `book.tcl` genanntes Kapitel, das fehlt, gibt nur eine Warnung (Entwürfe); ohne den Schalter bricht der Bau ab. |
| `-no-license` | kein Lizenzkapitel. Ohne den Schalter wird eine `LICENSE` (oder `LICENSE.md`, `LICENSE.txt`, `license.terms`) im Buchordner das letzte Kapitel, wörtlich: „Lizenz“ bei `lang de`, sonst „License“. |

**Subkommando `manifest`.** `book-build.tcl manifest <bookdir>` schreibt eine
`book.tcl` aus den vorhandenen `NNN-`-Präfixen (Startpunkt nach einer Migration;
danach von Hand feinjustieren). Namen mit Leerzeichen oder Klammern werden als
Tcl-Listenelemente geschrieben (`{010-mein kapitel.md}`).

**Kapitel und Anker.** Jedes Kapitel wird für sich gelesen. Eine
Überschriften-ID, die ein früheres Kapitel schon hat, bekommt eine Endung
(`-2`, `-3` …), sodass jedes Ziel in HTML und PDF eindeutig ist. `#anker`
wird zuerst im selben Kapitel gesucht, dann im ganzen Buch; `datei.md#anker`
nur in `datei.md`. `book-search.tcl` zählt seine Anker genauso.

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
                                     [-no-cid] [-index-tsv datei] [-label NAME]
                                     [-header VORLAGE | -no-header] [-no-groups]
                                     [-lang KENNUNG] [-author A] [-subject S]
```

Im PDF steht oben links der Titel des Handbuchs, rechts, wo die Seite
liegt: die Manpage, die auf der Seite beginnt, sonst die laufende, mit
Pfad und Nachbarn, so viel davon in die Zeile passt
(`‹ disjointset  |  struct / graph  |  graph1 ›`, sonst `struct / graph`,
sonst `graph`). Das braucht ein docir mit Kolumnentitel (`%c`); mit
älterem docir fällt die Kopfzeile weg. `-header` setzt eine andere
docir-Vorlage (`%t` Titel, `%c` Kolumnentitel, `%p` Seite, Tabulator
zwischen links und rechts), `-no-header` schaltet sie ab.

**Teile.** Liegen die Handbuchseiten in mehr als einem Ordner unter
`<dir>`, wird jeder Ordner ein Teil: `# Tcl`, `# Tk`, `# Ttk` (die
`ttk_*`-Seiten unter `tk/`), in tcllib ein Teil je Modul. Die Seiten stehen
eine Ebene darunter (`## after`), ihre Abschnitte zwei (`### DESCRIPTION`);
das Inhaltsverzeichnis zeigt Teile und Seiten, die Kopfzeile die Seite.
`-no-groups` lässt es flach.

**Metadaten.** `-lang KENNUNG` (`de`, `en`) setzt die Sprache des
Dokuments, `-author` und `-subject` die passenden PDF-Felder; als Ersteller
steht `bookkit manual-build.tcl`, das Erstelldatum wird immer gesetzt. Die
Sprache braucht pdf4tcl 0.9.4.73. Die aktuelle Seite steht in der
Kopfzeile fett, wenn docir `**...**` in der Kopfzeile kann.

`-index` hängt ein Stichwortverzeichnis an. Die Begriffe sind der
Befehlsname und die `Keywords:` aus dem YAML-Kopf jeder Seite (TIP 700);
jedes Kapitel endet mit einer Zeile „*Stichwörter:* after, cancel, …“, deren
Einträge als `[begriff]{.index}` ins Verzeichnis gehen. `-index-label`
ändert „Stichwörter“, `-index-title` „Stichwortverzeichnis“. Beim
Tcl/Tk-9.0-Handbuch (221 Seiten) ist das Verzeichnis 12 Seiten lang.

Das PDF nutzt wie bei `book-build.tcl` die CID-Schrift mit vollem
Unicode-Vorrat; die 256-Zeichen-Teilmenge machte Zeichen wie das schmale
Leerzeichen in „z. B.“ zu „?“. `-no-cid` schaltet auf die Teilmenge
zurück.

`<verzeichnis>` wird rekursiv nach `*.md` durchsucht. Der Kapiteltext wird
wörtlich aus dem Quell-Markdown genommen (kein Umweg über docir).
Laufzeit-Abhängigkeiten wie bei `book-build.tcl`: `docir`, `mdstack`,
`pdf4tcl` auf dem Pfad (Umgebungsvariablen `DOCIR_HOME` / `MDSTACK_HOME` /
`PDF4TCL_HOME`, oder Suche in Nachbarverzeichnissen).

`-index-tsv datei` (mit `-pdf` und `-index`) schreibt das fertige
Stichwortverzeichnis zusätzlich als Tabelle: Kopfzeilen `# pdf`, `# label`,
`# title`, dann je Begriff `begriff<TAB>seiten` mit den gedruckten
Seitenzahlen. `-label` ist der Name des Handbuchs im Gesamtindex (Vorgabe:
`-title`, sonst der PDF-Name). Die Seiten liefert nach dem Rendern
`docir::pdf::indexEntries` (bei einem docir ohne diese Abfrage der
interne Zustand `st indexEntries`), sie sind also dieselben wie im
gedruckten Verzeichnis.

---

## index-gesamt.tcl

Ein Gesamtindex über mehrere Handbuch-PDFs: ein eigenes PDF, in dem jeder
Begriff einmal steht, dahinter je Handbuch die Seiten.

```
after — Tcl/Tk 9.0: 75, 210 · Tcl/Tk 8.6: 71, 198
```

**Aufruf**

```
tclsh bookkit/tools/index-gesamt.tcl -pdf gesamt.pdf [-title T] [-links 0|1] [-lang de|en] [-md gesamt.md] \
      a.index.tsv b.index.tsv ...
```

Die Eingaben schreibt `manual-build.tcl -index -index-tsv`. Die Reihenfolge
der Handbücher je Begriff ist die der Eingaben. Mit `-links 1` (Vorgabe) ist
jede Seitenzahl ein Verweis auf die Seite im anderen PDF (PDF-Aktion
`GoToR`, Datei relativ zum Gesamtindex). Alle PDFs gehören dafür in
denselben Ordner wie beim Bauen. Acrobat, Okular und Evince folgen solchen
Verweisen, manche Betrachter im Browser nicht. Den Sprung setzt docir
über pdf4tcl `fileLinkAdd` (ab 0.9.4.73). Fehlt das, ergänzt
`index-gesamt.tcl` es selbst über einen Mixin auf
`pdf4tcl::pdf4tcl`.

Die Seitenzahlen gelten nur für genau diesen Stand der PDFs. Nach jedem
neuen Handbuch-PDF den Gesamtindex neu bauen.

---

## book-new.tcl

Legt ein neues Buch samt optionaler Übersetzungen an: Quellordner mit
`book.tcl` und zwei Beispielkapiteln, je einen Ordner pro Zielsprache
(gleiche Dateinamen), ein mehrspaltiges Glossar und je eine Anker-Map-Vorlage.

**Aufruf**

```
tclsh bookkit/tools/book-new.tcl <book-id> "Titel" [-lang de] [-author Name] [-tr en,fr]
```

**Argumente/Optionen**

| Argument | Wirkung |
|---|---|
| `<book-id>` | Buch-ID (kleingeschrieben, Bindestriche); zugleich Verzeichnisname. |
| `"Titel"` | Buchtitel (in Anführungszeichen). |
| `-lang <xx>` | Quellsprache (Standard `de`); wird als `lang` in `book.tcl` gesetzt. |
| `-author <Name>` | Autor. Steht in `book.tcl` und ersetzt `<Name>` in `LICENSE`. Ohne die Option bleibt der Platzhalter. |
| `-tr <a,b,…>` | kommagetrennte Zielsprachen; je eine `<book-id>-<xx>/` wird angelegt. |

**Ergebnis** (eine Ebene über `tools/`):

```
<book-id>/                        Quellkapitel + book.tcl + LICENSE (lang = -lang)
<book-id>-<xx>/                   je -tr-Sprache, gleiche Dateinamen, eigene LICENSE
glossary/<book-id>-glossary.tsv   mehrspaltiges TSV (Quelle + Übersetzungen)
i18n/<book-id>-anchors-<xx>.tsv   Anker-Map-Vorlage je Übersetzung
```

`LICENSE` kommt aus `template/my-book` (deutsch bei `-lang de`) bzw.
`template/my-book-en` (jede andere Sprache). Text CC BY-SA 4.0, eigene
Codebeispiele MIT. Der Inhaber ist der Platzhalter `<Name>`, sofern
nicht `-author` gesetzt ist.

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

Migration von Altbestand: Verweise auf andere Kapiteldateien werden zu
Verweisen auf den Anker des Kapitels. Den Anker jeder `*.md` in `<bookdir>`
liefert ihre erste `# `-Überschrift, gebildet wie bei docir (klein, jede
Folge außerhalb `a-z0-9` wird `-`). Aus `](andere.md)` wird `](#anker)`,
aus `](andere.md#x)` wird `](#x)`; Verweise auf Dateien, die keine Kapitel
sind, bleiben.

**Aufruf**

```
tclsh bookkit/tools/book-migrate.tcl <bookdir> [-n]
```

`-n` nennt nur die Dateien, die sich ändern würden. `book-build.tcl` löst
`datei.md`-Verweise selbst auf, der Schritt ist also freiwillig; er hilft,
wenn Kapitel auch einzeln gelesen werden. Ablauf-Kontext in MIGRATION.md.

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

Prüft, was sonst von Hand läuft: ohne Argumente alle Quelle-Pfade aus dem
Register (fehlendes Verzeichnis = Fehler), sonst die
übergebenen Ordner. Danach: `index-dedupe -n`, Manifest gegen `*.md`,
genau eine H1 je Kapitel, relative `.md`-Links, `{.index}` in Tabellenzeilen
(Warnung), Glossarname (Warnung), Buchtyp: fehlt `booktype` in `book.tcl`, ist
er unbekannt oder weicht er von der Spalte Buchtyp im Register ab
(Warnung). Baut **kein** PDF.

Das Register ist das erste, das es gibt: `$BOOKKIT_REGISTRY`,
`bookkit-privat/REGISTRY.md` neben `bookkit/`, `bookkit/doc/de/REGISTRY.md`,
`bookkit/doc/REGISTRY.md`. Format: `doc/de/REGISTRY.example.md`.

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

## book-search.tcl

Volltextsuche über alle Bücher der Registry. Legt eine SQLite-Datenbank an
(`bibliothek-suche.db` neben `bookkit/`); jedes Kapitel wird an den
Überschriften zerlegt, ein Abschnitt ist eine Zeile. Zwei FTS5-Indizes: Wörter
(ohne Groß/Klein, Akzente gefaltet) und Trigramme für Teilwörter.
`[begriff]{.index}`-Marker und die Glossar-TSV bilden eine eigene
Begriffstabelle; ein Begriffstreffer steht vor den Volltexttreffern.

**Aufruf**

```
tclsh bookkit/tools/book-search.tcl index ?Optionen?
tclsh bookkit/tools/book-search.tcl query ?Optionen? wort ?wort ...?
tclsh bookkit/tools/book-search.tcl stats ?-db datei?
```

**Optionen für `index`**

| Option | Wirkung |
|---|---|
| `-root dir` | Arbeitsverzeichnis mit den Büchern (Vorgabe: über `bookkit/`) |
| `-registry datei` | Vorgabe: das Register wie bei `book-check.tcl` |
| `-db datei` | Vorgabe `<root>/bibliothek-suche.db` |
| `-book id` | nur dieses Buch (mehrfach) |
| `-dir pfad` | zusätzlicher Buchordner außerhalb der Registry (mehrfach) |
| `-lang l` | nur Ordner dieser Sprache |
| `-pdf dir` | jede PDF unter `dir` mit aufnehmen, ein Treffer je Seite (braucht `tclutils::tupdftext`) |
| `-tclutils dir` | wo tclutils liegt, falls nicht im Modulpfad |

**Optionen für `query`**

| Option | Wirkung |
|---|---|
| `-db datei` | wie oben |
| `-book id` | nur dieses Buch (mehrfach) |
| `-limit n` | Zahl der Abschnittstreffer (Vorgabe 20) |
| `-sub` | Teilwortsuche (Trigramme) statt Wörter |
| `-prefix` | Wörter als Präfix (`nativ` findet `nativename`) |
| `-raw` | die Wörter sind ein FTS5-Ausdruck (`'Mausrad NOT Linux'`) |
| `-format f` | `text` (Vorgabe) oder `tsv` |

Ohne `-sub` wird eine Wortsuche ohne Treffer als Teilwortsuche wiederholt.
Der Index aktualisiert sich nicht selbst: nach dem Bauen `index` neu laufen
lassen.

---

## book-search-gui.tcl

Fenster zu `book-search.tcl`, das einzige Werkzeug mit Tk. Sucht beim
Tippen in derselben Datenbank; links die Treffer (Begriffe zuerst), rechts
der ganze Abschnitt mit markierten Suchwörtern.

```
wish  bookkit/tools/book-search-gui.tcl ?-db datei? ?-root dir? ?wort ...?
tclsh bookkit/tools/book-search-gui.tcl ...      (lädt Tk selbst)
```

Tasten: Return sucht sofort, Strg+F oder Escape zum Suchfeld, Return oder
Doppelklick in der Liste öffnet das gebaute HTML am Anker, Strg+E die
Kapiteldatei, Strg+C kopiert `datei:zeile`. „Index neu“ startet
`book-search.tcl index` in einem zweiten Prozess. Braucht Tcl/Tk 8.6 oder 9
und `sqlite3` mit FTS5.

---

## style-check.tcl

Prüft den Sprachstil eines Buchs nach seinem Buchtyp. Zählt je
Kapitel Hinweise und bewertet sie nach `booktype` aus `book.tcl`. Findet
Häufungen, keine Einzelfehler: ein Treffer kann richtig sein.

**Aufruf**

```
tclsh bookkit/tools/style-check.tcl ?-type T? ?-strict? ?-all? <bookdir>
```

| Schalter | Bedeutung |
|---|---|
| `-type T` | Buchtyp, wenn `book.tcl` keinen nennt oder zum Übersteuern: `textbook`, `workshop`, `manual`, `reference`, `developer` (auch `lehrbuch`, `werkstatt`, `handbuch`, `referenz`, `entwickler`). Ohne beides: Lehrbuch, mit Hinweis |
| `-strict` | Exit 1, wenn es Hinweise gibt |
| `-all` | auch Kapitel ohne Hinweis auflisten |

Gezählt wird im Fließtext (ohne YAML-Kopf, Codeblöcke, Inline-Code,
Linkziele): das Wortfeld „Messung“ (je 1000 Wörter), Datumsangaben,
Datum mit Uhrzeit, „nicht gemessen/geprüft/ausgeführt/getestet“, Zeilen
`*Stand: …*`, Erwähnungen von KI und Entstehung (erlaubt im ersten
Kapitel, das sie nennt), Buchkennungen `` `book-…` `` und Abschnitte
„Zusammenfassung“ (bei Handbuch und Referenz). Anhänge (`8nn-`, `9nn-`,
„anhang“) werden gezählt, nicht bewertet: Dort gehören Testumgebung und
Quellen hin.

| Typ | Messung je 1000 W. | Datum | „nicht geprüft“ | Buch-ID | Zusammenfassung |
|---|---|---|---|---|---|
| `textbook` | 1 | 1 | 2 | 0 | ja |
| `workshop` | 3 | 2 | 4 | 2 | ja |
| `manual` | 1 | 1 | 2 | 0 | ja |
| `reference` | 0 | 0 | 0 | 0 | nein |
| `developer` | 5 | 2 | 4 | 2 | ja |

Werte je Kapitel; „Uhrzeit“ ist immer ein Hinweis. Dateinamen wie
`` `book-build.tcl` `` zählen nicht als Buchkennung. Gehört ein Punkt zum
Thema des Buchs, schaltet ihn `book.tcl` ab:
`set styleallow {buchid}` (möglich: `mess`, `datum`, `nicht`, `buchid`,
`summary`, `ki`, `stand`). Exit 0 (mit `-strict` 1
bei Hinweisen), 2 bei falschem Aufruf. Die Wortlisten sind deutsch.

---

## code-compare.tcl

Vergleicht die Codeblöcke zweier Fassungen eines Buchs, etwa vor und nach
dem Umstellen auf einen Buchtyp. Eine
Überarbeitung des Texts darf Code nicht verändern.

```
tclsh bookkit/tools/code-compare.tcl ?-v? ?-strict? <alt> <neu>
```

`<alt>` und `<neu>` sind Buchordner oder einzelne `.md`-Dateien. Jeder
Block aus `<alt>` (```` ``` ```` und `~~~`, auch eingerückt) wird in
`<neu>` gesucht:

| Ergebnis | Bedeutung |
|---|---|
| gleich | unverändert in derselben Datei (nicht einzeln gemeldet) |
| `verschoben` | unverändert in einer anderen Datei, etwa einem Anhang |
| `Kommentar` | nur Kommentare geändert (`#`, `;#`, `//`); mit `-strict` ein Fehler |
| `FEHLT` | nicht mehr da oder im Code geändert |

Die Einrückung des ganzen Blocks zählt nicht. `-v` zeigt die Zeilen.
Exit 0, wenn nichts fehlt; 1 sonst; 2 bei falschem Aufruf.

---

## publish-check.tcl

Prüft einen Baum vor dem Veröffentlichen: keine Arbeitsnotizen, privaten
Pfade oder gebauten Dateien darin.

```
tclsh bookkit/tools/publish-check.tcl ?-privat dir? ?-deny datei? ?-allow datei? ?-quiet? <pfad> ...
```

`<pfad>` ist, was veröffentlicht wird, etwa `bookkit` und ein Buchordner.
Die allgemeinen Muster stehen in `tools/publish-deny.tsv`, Ausnahmen in
`tools/publish-allow.tsv`:

| Prüfung | Findet |
|---|---|
| `datum` | ein ISO-Datum (Entstehung gehört nach `CHANGES.md`) |
| `stand` | eine Zeile `*Stand:*` / `*As of:*` (erlaubt in `README.md` und `BUCHSTRUKTUR.md`) |
| `review`, `review-id` | Review-Verweise wie „Review 2026-…“, „(B04)“ |
| `ki` | Namen von KI-Werkzeugen (außerhalb des ersten Kapitels, das sie nennt) |
| `heim` | `~/`, `/home/`, `/Users/` |
| `messung` | „gemessen am <Datum>“ |
| `kommentar:historie` | Entstehungsgeschichte in Tcl-Kommentaren („bisher“, „nicht mehr“, „behoben“) |
| `datei:erzeugt` | `.pdf`, `.html`, `.epub`, `.docx` im Quellbaum |
| `datei:notiz` | `TODO.md`, `NOTES.md`, `UEBERGABE.md`, … |

Der private Teil (`-privat`, Vorgabe `bookkit-privat/` neben `bookkit/`)
ergänzt eigene `publish-deny.tsv` und `publish-allow.tsv` (Namen eigener
Projekte und Rechner, die nicht in der öffentlichen Liste stehen dürfen)
und die Quellordner aller Bücher aus seinem `REGISTRY.md` (Prüfung `buch`),
außer den Büchern, die selbst geprüft werden.

Musterdatei: `name<TAB>regex<TAB>hinweis`; ein Name mit `datei:` prüft den
relativen Pfad, einer mit `kommentar:` nur Kommentarzeilen in `.tcl`.
Ausnahmedatei: `glob<TAB>name<TAB>regex` (regex frei, schränkt auf passende
Zeilen ein). Exit 0 sauber, 1 Treffer, 2 Aufruffehler.

---

## Tests

```
tclsh bookkit/tests/run.tcl
```

Baut kleine Bücher in einem Temp-Ordner und prüft: Verweise zwischen
Kapiteln (`datei.md`, `datei.md#anker`, Umlaut-Anker über die Umschrift),
die Warnung bei Verweisen ohne Ziel, CID-Schrift gegen `-no-cid` (PDF-Teil
wird übersprungen, wenn pdf4tcl fehlt) und `manual-build.tcl -index` mit
`-index-label`/`-index-title` und `-index-tsv`, `index-gesamt.tcl`
(Zusammenführen, `GoToR`-Verweise, `-links 0`), `style-check.tcl` (Zählung, Buchtyp, `-strict`), `code-compare.tcl`. Gleiche Umgebung wie beim Bauen.

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

# 8. Suchindex neu bauen
tclsh bookkit/tools/book-search.tcl index
```

Bestehendes Buch einpassen: statt Schritt 1 die Checkliste in MIGRATION.md
(flach 1 Kapitel/Datei, H1-Nummern raus, `manifest` erzeugen, `book-migrate.tcl`,
Glossar mehrspaltig), dann ab Schritt 3.
