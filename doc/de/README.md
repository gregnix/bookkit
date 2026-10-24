# bookkit

Ein eigenständiges Toolkit und Regelwerk für Bücher im **docir + mdstack +
pdf4tcl**-Format: Markdown-Kapitel → PDF und HTML, mit hierarchischer
Nummerierung, Inhalts- und Stichwortverzeichnis — und Mehrsprachigkeit von
Grund auf.

Für **neue** Bücher (Vorlage + Generator) und für das **Überführen vorhandener**
Bücher in das Format.

---

## Aufbau

```
bookkit/
    CHANGES.md        # Änderungen an den Werkzeugen
    doc/de/
        SPEC.md       # der verbindliche Format-Standard (Regelwerk)
        MIGRATION.md  # vorhandene Bücher ins Format bringen
        I18N.md       # Mehrsprachigkeit
        REGISTRY.example.md  # Format des Buchregisters (das eigene bleibt privat)
        TOOLS.md      # die Werkzeuge im Einzelnen
        STYLE.md      # Sprachstil nach Buchtyp (Lehrbuch, Werkstattbuch, ...)
    doc/          # dieselben Dokumente auf Englisch
    tools/        # book-build, book-new, book-migrate, manual-build, index-gesamt, book-check, i18n-*, index-dedupe, book-webindex, book-search(-gui), style-check, code-compare, publish-check
    template/     # zweisprachiges Beispielbuch (Referenz)
```

Ein Buch lebt **neben** `bookkit/`:

```
mein-arbeitsordner/
    bookkit/
    git-und-tcltk/        # Buch (Quelle)
    git-und-tcltk-en/     # Übersetzung
    glossary/  i18n/
```

## Schnellstart

Neues, zweisprachiges Buch anlegen:

```bash
cd mein-arbeitsordner
tclsh bookkit/tools/book-new.tcl mein-buch "Mein Buch" -lang de -tr en
```

Bauen:

```bash
tclsh bookkit/tools/book-build.tcl mein-buch/ -number
```

Vorhandenes Buch überführen: siehe `MIGRATION.md`. Weitere Sprache ergänzen:
siehe `I18N.md`.

## Privater Teil und Veröffentlichen

Das eigene Buchregister, Notizen und gebaute PDFs bleiben außerhalb des
veröffentlichten Baums, in einem Ordner `bookkit-privat/` neben `bookkit/`
(wird nie veröffentlicht):

```
mein-arbeitsordner/
    bookkit/            # wird veröffentlicht
    bookkit-privat/     # privat: REGISTRY.md, publish-deny.tsv, ...
    mein-buch/
```

`book-check.tcl` und `book-search.tcl` lesen das Register von dort
(`doc/de/REGISTRY.example.md` zeigt das Format). Vor dem Veröffentlichen:

```bash
tclsh bookkit/tools/publish-check.tcl bookkit mein-buch
```

Gemeldet werden Datum und Review-Notizen in Kommentaren, persönliche Pfade,
Namen von KI-Werkzeugen, gebaute Dateien (PDF, HTML) im Quellbaum und alles,
was in `bookkit-privat/publish-deny.tsv` steht oder im privaten Register als
Quellordner vorkommt. Exit 1 bei jedem Treffer. Einzelheiten:
`doc/de/TOOLS.md`.

## Laufzeit

Die Werkzeuge sind Tcl-Skripte. Der Build (`book-build.tcl`) benötigt `docir`,
`mdstack` und `pdf4tcl` erreichbar (über `TCLLIBPATH` bzw. Modulpfad). Die
übrigen Werkzeuge kommen mit reinem Tcl aus.

## Herkunft

Herausgelöst aus dem docir-Buchformat und konsolidiert — dieselben Regeln
und Werkzeuge, nur eigenständig und dokumentiert, mit mehrsprachigem Glossar
und sprachneutralen Werkzeugen.
