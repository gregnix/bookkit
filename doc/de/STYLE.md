# bookkit — Sprachstil nach Buchtyp

Gemeinsame Regeln für alle Bücher, angewendet je nach Buchtyp. Ergänzt
`SPEC.md` (Format) um den Text selbst. Prüfen lässt sich ein Teil davon mit
`tools/style-check.tcl` (siehe `TOOLS.md`). Das Werkzeug gibt Hinweise, die
Entscheidung trifft der Autor.

---

## 1. Buchtypen

Jedes Buch hat einen Typ. Er steht in `book.tcl`:

```tcl
set booktype workshop     ;# textbook | workshop | manual | reference | developer
```

| `booktype` | Buchtyp | Sprachstil | Was hineingehört |
|---|---|---|---|
| `textbook` | Lehrbuch | erklärend, verständlich, aufbauend | Grundlagen, Zusammenhänge, aufbauende Beispiele, Übungen |
| `workshop` | Werkstattbuch | praktisch, direkt, lösungsorientiert | Vorgehen, Befehle, Fehlersuche, Erfahrungen |
| `manual` | Handbuch | sachlich, präzise, systematisch | Funktionen, Optionen, Konfiguration, Anwendungsfälle |
| `reference` | Referenz | knapp, eindeutig, vollständig | Syntax, Parameter, Rückgabewerte, Fehler |
| `developer` | Entwicklerbuch | technisch, begründend | Architektur, Umsetzung, Entwurfsentscheidungen |

Der Typ in `book.tcl` und die Selbstbeschreibung im README („Ein
deutschsprachiges Werkstattbuch für …“) stimmen überein. Ein Buch bleibt bei
seinem Typ: Ein Lehrbuch wird nicht zum Testprotokoll, eine Referenz nicht
zur Erzählung.

### Derselbe Inhalt in vier Typen

*Lehrbuch:*

> Tcl/Tk kann unter macOS aus den Quellen erstellt werden. Dazu brauchen wir
> die Apple-Entwicklungswerkzeuge und die Tcl/Tk-Quellen. Im folgenden
> Abschnitt richten wir die Umgebung ein und erstellen dann eine erste
> Tk-Anwendung.

*Werkstattbuch:*

> Für den Bau von Tcl/Tk 9.0.4 verwenden wir BAWT. Installiert wird nach
> `/opt/tcl9`. Zuerst prüfen wir, ob Xcode und die Kommandozeilenwerkzeuge
> vorhanden sind.

*Handbuch:*

> Das Installationsverzeichnis `/opt/tcl9` enthält die Tcl/Tk-Laufzeit.
> Weitere Pakete liegen in einem eigenen Verzeichnis und werden über den
> Paketsuchpfad eingebunden.

*Referenz:*

```tcl
puts $::tcl_version
puts $::auto_path
puts [tcl::tm::path list]
```

---

## 2. Gemeinsame Regeln

Diese Regeln gelten für jedes Buch.

**Wortwahl.**

- „Messung“, „messen“, „gemessen“ nur, wenn eine Größe gemessen wird:
  Zeit, Größe in Byte, Anzahl, Speicher. Ein Funktionstest ist keine
  Messung. Dafür: „geprüft“, „getestet“, „ausprobiert“, „beobachtet“, oder
  einfach die Aussage selbst („`wish9.0` meldet `aqua`“).
- Natürliche Sätze statt konstruierter: „Dieses Buch behandelt die
  Besonderheiten von Tcl/Tk unter macOS“, nicht „Dieses Buch trennt Tcl/Tk
  unter macOS von Linux und Windows“.

**Was nicht in die Kapitel gehört.**

- Die Entstehung des Buchs. Kein Kapitel beginnt damit, wie es entstanden
  ist. Der Hinweis auf KI-Unterstützung steht **einmal**, im README
  (Impressum) oder in einem Vorwort.
- Zeitstempel und Uhrzeiten von Testläufen, Build-Ordner, Zählungen ohne
  Nutzen für den Leser („alle 141 Bibliotheken“).
- Verwaltung: Kennungen anderer Bücher (`book-anderes-buch`) im Fließtext,
  Listen von Nachbarbüchern am Kapitelanfang. Verweise auf andere Bücher
  stehen mit Titel dort, wo sie inhaltlich helfen, die Liste im README.
- Wiederholte Zusammenfassungen, die nur den Kapiteltext noch einmal
  aufzählen.

**Was bleiben muss.**

- Technische Einschränkungen und wichtige Testergebnisse: was nicht
  funktioniert, unter welcher Version etwas gilt, was nicht geprüft ist und
  deshalb unsicher bleibt. Das ist Information für den Leser, nicht
  Protokoll. Es wird nur anders untergebracht (Abschnitt 3).
- Quellen (Anhang Quellen) und Fallen (Anhang Fallen).

**Datum.** Ein `*Stand: …*` je Buch, im README und in `book.tcl`
(`set date`), nicht unter jeder Kapitelüberschrift. Ein Datum im
Fließtext nur, wenn es für den Leser etwas bedeutet: Erscheinen einer
Version („Tcl/Tk 9.1.0 erschien im September 2026“), eine Frist, das Alter
einer Quelle („Wiki-Seite von 2013“).

---

## 3. Wohin mit Tests und Prüfständen

| Ort | Was |
|---|---|
| Haupttext | nur Ergebnisse, die für Verständnis oder Anwendung wichtig sind, als Aussage formuliert |
| am Beispiel oder Kapitelende | ein Kasten „Getestet mit“, siehe unten |
| Anhang „Testumgebung“ | Rechner, Betriebssystem, genaue Versionen, Prüfskripte, was offen ist |
| Repository | ausführliche Protokolle, Zeitstempel, vollständige Ausgaben, Entstehungsgeschichte (`CHANGES.md`) |

Der Kasten fasst zusammen, was in einem Kapitel geprüft ist und was nicht.
Er steht einmal, am Ende des Kapitels oder nach dem Beispiel, auf das er
sich bezieht:

```markdown
::: {.info}
**Getestet mit** Tcl/Tk 9.0.4 auf macOS 27 (Apple Silicon).

**Nicht getestet:** Start per Doppelklick im Finder, Weitergabe an einen
zweiten Mac.
:::
```

Statt „gemessen am 19. Oktober: …“ mitten im Satz steht die Aussage („Tk
lädt `AppMain.tcl` auch beim BAWT-`wish9.0`“), und der Kasten sagt, womit
geprüft wurde.

---

## 4. Regeln je Buchtyp

### Lehrbuch (`textbook`)

- Ein Kapitel beantwortet: Was ist das? Wofür brauche ich es? Wie
  funktioniert es? Was muss ich beachten?
- Begriffe erklären, bevor sie benutzt werden. Beispiele bauen
  aufeinander auf. Übungen am Kapitelende sind erwünscht.
- „Wir“ ist erlaubt („Wir legen zuerst …“), „du“ nicht.
- Keine Prüfstände im Haupttext, höchstens der Kasten am Kapitelende.
- Zusammenfassung am Kapitelende: ja, kurz, als Lernziele.

### Werkstattbuch (`workshop`)

- Direkt zum Vorgehen: Voraussetzungen, Schritte, Ergebnis, Fehlersuche.
- Darf zeigen, was nicht funktioniert hat und warum, wenn der Leser daraus
  etwas lernt. Keine Chronologie der Entwicklung.
- Befehle vollständig und ausführbar, mit erwarteter Ausgabe.
- Prüfstände im Kasten. „Gemessen“ nur für echte Messungen (Laufzeit,
  Größe).
- Zusammenfassung: nur, wenn das Kapitel lang ist; dann als Checkliste
  „Kurz“ mit den Schritten, nicht als Wiederholung des Texts.

### Handbuch (`manual`)

- Systematisch nach Funktionen oder Optionen geordnet, jede mit Zweck,
  Werten, Standard, Wirkung.
- Präsens, sachlich, ohne Erzählung. Keine Ich- oder Wir-Form.
- Prüfstände nur, wo sie eine Einschränkung begründen.
- Zusammenfassung nur als kurze Merkliste, nicht als Wiederholung;
  Optionen und Werte lieber in Tabellen.

### Referenz (`reference`)

- Syntax, Parameter, Rückgabewerte, Fehler. Vollständig, knapp,
  einheitlich aufgebaut.
- Keine Prüfstände, keine Datumsangaben, keine Zusammenfassung.
- Beispiele kurz und ohne Erklärung, die schon im Text steht.

### Entwicklerbuch (`developer`)

- Architektur, Umsetzung und Entwurfsentscheidungen, jeweils mit
  Begründung und verworfenen Alternativen.
- Darf Messungen enthalten (Laufzeit, Speicher), dann mit Methode und
  Zahl.
- Versionsgeschichte des Werkzeugs gehört in `CHANGES.md`, nicht in die
  Kapitel.

---

## 5. Prüfen

```bash
tclsh bookkit/tools/style-check.tcl book-mein-buch/Mein-Buch-de/
```

Das Werkzeug zählt je Kapitel die Hinweise aus Abschnitt 2 und 3 und
bewertet sie nach dem `booktype`. Gehört ein gezählter Punkt zum Thema
des Buchs, schaltet `book.tcl` ihn ab: Ein Buch über bookkit nennt
Buchkennungen, also `set styleallow {buchid}`. Es findet Häufungen, keine Stilfehler im
Einzelnen: Ein Treffer kann richtig sein („die Laufzeit gemessen mit
`time`“). Schalter und Ausgabe: `TOOLS.md`.

---

## 6. Vorher und nachher

Vorher (Einführung eines Werkstattbuchs):

> Am 17. Oktober um 22:25 Uhr lief auf dem Testrechner BAWT 3.3.0 mit `update`,
> Tcl/Tk **9.0.4**, Wurzel `../Bawt9.0.4`. Stufe **None** für alle 141
> Bibliotheken. Die Distribution liegt unter `/opt/tcl9`. Dort gemessen mit
> `wish9.0`: Patchlevel **9.0.4**, `tk windowingsystem` **aqua**.

Nachher:

> Die Beispiele verwenden Tcl/Tk 9.0.4, mit BAWT gebaut und unter
> `/opt/tcl9` installiert. Die Programme sind native ARM64-Programme und
> verwenden das Fenstersystem Aqua (`tk windowingsystem` liefert `aqua`).

Der Rest (BAWT-Version, Build-Ordner, Datum) steht im Anhang
„Testumgebung“.

---

## 7. Ein Buch umstellen

Vorgehen, wenn ein vorhandenes Buch auf seinen Buchtyp gebracht wird. Das
Ergebnis bei einem Werkstattbuch: ein neues Kapitel 010 (Einführung, womit
die Beispiele arbeiten, wie das Buch zu lesen ist) und ein Anhang
`860-anhang-testumgebung.md`.

### Vorher

1. **Kopie des Buchordners** anlegen (außerhalb des Buchs). Sie ist die
   Grundlage für `code-compare.tcl` am Ende.
2. **Typ festlegen.** Was das Buch tut, entscheidet, nicht wie es sich
   nennt: Eine Installationsanleitung ist ein Werkstattbuch, auch wenn
   das README „Lehrbuch“ sagt. Im Zweifel `style-check.tcl -type …` mit
   mehreren Typen laufen lassen und den Inhalt ansehen.
3. **Ausgangslage zählen:** `style-check.tcl <buch>` und
   `book-check.tcl <buch>/`. Fehler, die schon im Original sind,
   festhalten, damit sie nicht der Überarbeitung zugeschrieben werden.

### Ändern

4. **`book.tcl`:** `set booktype <typ>` mit Kommentar. Gehört ein
   gezählter Punkt zum Thema, zusätzlich `set styleallow {…}`.
5. **Stand-Zeilen** `*Stand: …*` unter den Kapitelüberschriften
   entfernen. Ein Stand bleibt im README.
6. **Jedes Kapitel durchgehen**, nach Abschnitt 2 und 4:
   - „gemessen“, „Messung“, „Messprobe“ nur für Größen; sonst die
     Aussage selbst oder „geprüft“, „getestet“, „ausprobiert“,
     „beobachtet“. Ein Prüfskript heißt im Text „Prüfskript“, auch wenn
     die Datei `messprobe-*.tcl` heißt.
   - Datum und Uhrzeit von Testläufen aus dem Fließtext. Erscheinungs-
     und Quellendaten bleiben, im Text als Monat und Jahr.
   - Buchkennungen `book-…` durch den Buchtitel ersetzen.
   - Keine Entstehung und keine KI im Kapitel. Der Hinweis auf
     KI-Unterstützung steht einmal im Impressum (README), und nur, wenn
     das Buch ihn schon enthält.
   - Versionsgeschichte („seit …“, „behoben am …“, „Version 1, erster
     Lauf …“) wird zum aktuellen Stand. Im Werkstattbuch werden lehrreiche
     Fehlschläge zu einem Abschnitt „Stolpersteine“; alte Fassungen
     verweisen auf `CHANGES.md`.
7. **Kapitel 010 neu fassen**, je nach Typ:
   - Werkstattbuch: Einführung (worum es geht, für wen), „Womit die
     Beispiele arbeiten“ (Versionen, Rechner in einem Satz, Verweis auf
     den Anhang), „Wie das Buch zu lesen ist“ (Teile, Anhänge).
   - Handbuch: Zweck, Zielgruppe, Grundlage der Angaben, Aufbau.
   - Lehrbuch: was gelernt wird, Voraussetzungen, Weg durch das Buch,
     Kasten „Getestet mit“ am Ende.
8. **Anhang „Testumgebung“** (`860-anhang-testumgebung.md`, nächster
   freier Buchstabe), wenn das Buch Prüfstände hat: Rechner und
   Versionen, Prüfskripte, Tabelle „Noch nicht getestet“ je Kapitel,
   gesammelt aus allen „nicht geprüft“ des Buchs. Hat das Buch schon
   einen Protokoll-Anhang, dorthin statt doppelt. Ein Lehrbuch braucht
   ihn selten; dort genügt der Kasten am Kapitelende.
9. **Anhänge 800–899:** nur das Wortfeld anpassen; Daten dürfen bleiben.
10. **README, BUCHSTRUKTUR, Zählung:** Buchtyp in der Selbstbeschreibung,
    statt eines Testprotokolls ein kurzer Absatz zu den Versionen, neuer
    Anhang in Lesereihenfolge und Zählung.

### Nicht tun

- **Codeblöcke nicht ändern**, höchstens Kommentare darin („;# gemessen:
  5.2.0“ → „;# -> 5.2.0“). Ein Block darf in einen Anhang wandern.
- **Nichts erfinden.** Was das Buch nicht sagt (Betriebssystem eines
  Rechners, eine Version, dass etwas gelaufen ist), kommt nicht hinein;
  stattdessen offen lassen und als offene Frage festhalten.
- **Keine Fakten streichen.** Einschränkungen und Testergebnisse ziehen
  um (Kasten, Anhang), sie verschwinden nicht.
- Widersprüche zwischen Kapiteln oder Büchern nicht still auflösen,
  sondern melden.

### Nachher

```bash
tclsh bookkit/tools/style-check.tcl <buch>             # 0 mit Hinweisen, Rest begründen
tclsh bookkit/tools/code-compare.tcl <kopie> <buch>    # FEHLT 0
tclsh bookkit/tools/book-check.tcl <buch>/             # 0 Fehler, 0 Warnungen
tclsh bookkit/tools/book-build.tcl <buch>/ -number     # PDF und HTML
```

Hat das Buch eine Übersetzung, diese mitziehen und danach
`i18n-status.tcl <quelle> <übersetzung> -mark-all`.

Zum Schluss festhalten: Buchtyp, Hinweise vorher und nachher,
neue Dateien, was bewusst stehen blieb (echte Messungen), was unsicher
oder widersprüchlich ist.
