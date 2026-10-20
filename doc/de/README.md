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
    doc/de/
        SPEC.md       # der verbindliche Format-Standard (Regelwerk)
        MIGRATION.md  # vorhandene Bücher ins Format bringen
        I18N.md       # Mehrsprachigkeit
        REGISTRY.md   # Register aller Bücher (liest book-check.tcl)
        TOOLS.md      # die Werkzeuge im Einzelnen
    doc/          # dieselben Dokumente auf Englisch
    tools/        # book-build, book-new, book-migrate, manual-build, book-check, i18n-*, index-dedupe, book-webindex, book-search(-gui)
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

## Laufzeit

Die Werkzeuge sind Tcl-Skripte. Der Build (`book-build.tcl`) benötigt `docir`,
`mdstack` und `pdf4tcl` erreichbar (über `TCLLIBPATH` bzw. Modulpfad). Die
übrigen Werkzeuge kommen mit reinem Tcl aus.

## Herkunft

Herausgelöst und konsolidiert aus dem docir-Buchformat der Handbücher
*TclTk-Compile-und-Erweiterung* und *TclTk-und-Datenbank* — dieselben Regeln
und Werkzeuge, nur eigenständig und dokumentiert, mit mehrsprachigem Glossar
und sprachneutralen Werkzeugen.
