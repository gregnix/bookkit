#!/usr/bin/env tclsh
# run.tcl -- Tests fuer bookkit: Verweise und -no-cid in book-build.tcl,
# Stichwoerter aus YAML-Keywords in manual-build.tcl, style-check.tcl.
#
# Aufruf (Pfade zu docir, mdstack, pdf4tcl wie beim Bauen, also Umgebung
# DOCIR_HOME / MDSTACK_HOME / PDF4TCL_HOME / PDF4TCLLIB_HOME oder Nachbarordner):
#   tclsh bookkit/tests/run.tcl
#
# Jede Pruefung baut ein kleines Buch in einem Temp-Ordner und ruft das
# Werkzeug als eigenen Prozess auf. PDF-Pruefungen werden uebersprungen,
# wenn pdf4tcl nicht ladbar ist. Exit 1 bei einem Fehler.

set here  [file dirname [file normalize [info script]]]
set tools [file join [file dirname $here] tools]
set tclsh [info nameofexecutable]

set pass 0; set fail 0; set skip 0
proc check {name cond} {
    if {[uplevel 1 [list expr $cond]]} {
        puts "ok    $name"; incr ::pass
    } else {
        puts "FAIL  $name"; incr ::fail
    }
}
proc skip {name why} { puts "skip  $name ($why)"; incr ::skip }

proc schreib {f text} {
    file mkdir [file dirname $f]
    set fh [open $f w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $text
    close $fh
}
proc lies {f {enc utf-8}} {
    set fh [open $f r]
    fconfigure $fh -encoding $enc
    set t [read $fh]
    close $fh
    return $t
}
# Werkzeug aufrufen; Ergebnis: {exitcode stdout+stderr}
proc lauf {tool args} {
    set rc [catch {exec $::tclsh [file join $::tools $tool] {*}$args 2>@1} out opts]
    if {$rc} {
        set code 1
        if {[lindex [dict get $opts -errorcode] 0] eq "CHILDSTATUS"} {
            set code [lindex [dict get $opts -errorcode] 2]
        } elseif {[lindex [dict get $opts -errorcode] 0] eq "NONE"} {
            set code 0   ;# nur stderr-Ausgabe, kein Fehler
        }
        return [list $code $out]
    }
    return [list 0 $out]
}

set tmpBase /tmp
if {[info exists env(TMPDIR)]} { set tmpBase $env(TMPDIR) }
set tmp [file join $tmpBase bookkit-test-[pid]]
file delete -force $tmp
file mkdir $tmp
set old [pwd]
cd $tmp

# ------------------------------------------------------------------
# book-build.tcl: Verweise zwischen Kapiteln
# ------------------------------------------------------------------
schreib buch/010-eins.md {# Eins

Siehe [zweites Kapitel](020-zwei.md), genauer
[den Abschnitt](020-zwei.md#zweiter-abschnitt), [mit Umlaut](#ueber-uns)
und [ins Leere](fehlt.md).

Ein [Stichwort]{.index} und ein Zeichen: ⌘.

## Über uns

Text.
}
schreib buch/020-zwei.md {# Zwei

Einleitung.

## Zweiter Abschnitt

Zurück zu [Eins](010-eins.md).
}

lassign [lauf book-build.tcl buch/ -html buch.html] rc out
check "book-build -html laeuft"                {$rc == 0 && [file exists buch.html]}
if {[file exists buch.html]} {
    set h [lies buch.html]
    check "Verweis auf Kapitel -> erste Ueberschrift" {[string first {href="#zwei"} $h] >= 0}
    check "Verweis auf Kapitel#Anker"           {[string first {href="#zweiter-abschnitt"} $h] >= 0}
    check "Umlaut-Anker ueber Umschrift (ueber -> ber-uns)" {
        [regexp {href="#([^"]*ber-uns)"} $h -> a] && [string first "id=\"$a\"" $h] >= 0}
    check "Ruecksprung auf Kapitel 1"            {[string first {href="#eins"} $h] >= 0}
    check "nur der Verweis ohne Ziel bleibt .md" {
        [lsort -unique [regexp -all -inline {href="[^"#]*\.md[^"]*"} $h]] eq [list {href="fehlt.md"}]}
    check "Stichwort im HTML-Index"              {[string first Stichwort $h] >= 0}
}
check "Warnung fuer Verweis ohne Ziel"          {[regexp {WARNUNG: 1 Verweis\(e\) ohne Ziel: fehlt\.md} $out]}

# ------------------------------------------------------------------
# book-build.tcl: Leerzeichen im Kapitelnamen, gleiche Ueberschrift in
# zwei Kapiteln, fehlendes Kapitel
# ------------------------------------------------------------------
schreib b2/010-ein\ kapitel.md {# Einleitung

Hier [lokal](#einleitung), [drueben](020-zwei.md#einleitung), [Kapitel](020-zwei.md).
}
schreib b2/020-zwei.md {# Zwei

## Einleitung

Hier [lokal](#einleitung) und [nach vorn](#einleitung-gibt-es-nicht).
}
# book-build.tcl: LICENSE im Buchordner wird das letzte Kapitel
schreib lic/book.tcl "set lang de\nset chapters {010-a.md}\n"
schreib lic/010-a.md "# A\n\nText.\n"
schreib lic/LICENSE "Lizenztext CC BY-SA 4.0\n"
lassign [lauf book-build.tcl lic/ -html lic.html] rc out
check "book-build: LICENSE als Kapitel Lizenz"   {$rc == 0 && [string match "*Lizenztext CC BY-SA 4.0*" [lies lic.html]] && [string match "*>Lizenz<*" [lies lic.html]]}
lassign [lauf book-build.tcl lic/ -html lic2.html -no-license] rc out
check "book-build -no-license laesst sie weg"    {$rc == 0 && ![string match "*Lizenztext*" [lies lic2.html]]}

# book-new.tcl: LICENSE aus der Vorlage, <Name> nur mit -author ersetzt
set deTpl [file join [file dirname $here] template my-book LICENSE]
set enTpl [file join [file dirname $here] template my-book-en LICENSE]
check "Vorlage de: Platzhalter Name" {[string match "*<Name>*" [lies $deTpl]] && [string first "Gregor" [lies $deTpl]] < 0}
check "Vorlage en: Platzhalter Name" {[string match "*<Name>*" [lies $enTpl]] && [string match "*The author's code examples*" [lies $enTpl]]}
lassign [lauf book-new.tcl probe "Probe" -lang de -tr en -author "Ada Lovelace"] rc out
check "book-new legt LICENSE an" {$rc == 0 && [file exists probe/LICENSE] && [file exists probe-en/LICENSE]}
check "book-new de: Autor ersetzt Name" {
    [string first "Ada Lovelace" [lies probe/LICENSE]] >= 0
    && [string first "<Name>" [lies probe/LICENSE]] < 0
    && [string match "*legalcode.de*" [lies probe/LICENSE]]}
check "book-new en: englische Fassung" {
    [string first "Ada Lovelace" [lies probe-en/LICENSE]] >= 0
    && [string match "*The author's code examples*" [lies probe-en/LICENSE]]}
check "book-new: author in book.tcl" {[string match {*set author    "Ada Lovelace"*} [lies probe/book.tcl]]}
lassign [lauf book-new.tcl leer "Leer" -lang de] rc out
check "book-new ohne -author laesst <Name>" {[string first "<Name>" [lies leer/LICENSE]] >= 0}

lassign [lauf book-build.tcl manifest b2] rc out
check "manifest: Name mit Leerzeichen als ein Listenelement" {
    $rc == 0 && [string first "\{010-ein kapitel.md\}" [lies b2/book.tcl]] >= 0}
lassign [lauf book-build.tcl b2/ -html b2.html] rc out
check "book-build liest das eigene Manifest"     {$rc == 0 && [file exists b2.html]}
if {[file exists b2.html]} {
    set h [lies b2.html]
    check "gleiche Ueberschrift: Ziele eindeutig"  {
        [llength [regexp -all -inline {id="einleitung"} $h]] == 1
        && [llength [regexp -all -inline {id="einleitung-2"} $h]] == 1}
    check "#anker zuerst im eigenen Kapitel"       {
        [regexp -all {href="#einleitung"} $h] >= 1 && [regexp -all {href="#einleitung-2"} $h] >= 2}
    check "datei.md#anker nur in dieser Datei"     {[regexp {Hier <a href="#einleitung">lokal</a>, <a href="#einleitung-2">} $h]}
}
schreib b3/book.tcl "set chapters {\n 010-a.md\n 020-fehlt.md\n}\n"
schreib b3/010-a.md "# A\n\nText.\n"
lassign [lauf book-build.tcl b3/ -html b3.html] rc out
check "fehlendes Kapitel: Abbruch"               {$rc != 0 && [regexp {FEHLER: 1 Kapitel aus book.tcl fehlen: 020-fehlt.md} $out]}
lassign [lauf book-build.tcl b3/ -html b3.html -allow-missing] rc out
check "-allow-missing: nur Warnung"              {$rc == 0 && [regexp {WARNUNG: 1 Kapitel fehlen} $out]}

# ------------------------------------------------------------------
# book-build.tcl: -no-cid
# ------------------------------------------------------------------
set havePdf [expr {![catch {exec $tclsh << "package require pdf4tcl; package require pdf4tcllib" 2>@1}]}]
if {!$havePdf} {
    skip "PDF mit CID" "pdf4tcl nicht ladbar"
    skip "PDF -no-cid" "pdf4tcl nicht ladbar"
} else {
    lassign [lauf book-build.tcl buch/ -pdf cid.pdf] rc1 out1
    lassign [lauf book-build.tcl buch/ -pdf sub.pdf -no-cid] rc2 out2
    check "PDF mit CID (Vorgabe)"                {$rc1 == 0 && [file exists cid.pdf]}
    check "PDF -no-cid"                          {$rc2 == 0 && [file exists sub.pdf]}
    if {[file exists cid.pdf] && [file exists sub.pdf]} {
        set c [lies cid.pdf iso8859-1]; set s [lies sub.pdf iso8859-1]
        check "CID-PDF bettet Type0/Identity-H ein" {[string first Identity-H $c] >= 0}
        check "-no-cid-PDF ohne Identity-H"      {[string first Identity-H $s] < 0}
    }
}

# ------------------------------------------------------------------
# manual-build.tcl: Stichwoerter aus YAML-Keywords
# ------------------------------------------------------------------
schreib man/tcl/after.md {---
CommandName: after
ManualSection: n
Keywords:
  - cancel
  - delay
  - After
  - sleep_ms
Copyright:
  - "Copyright (c) 1990 The Regents"
  - "Copyright (c) 1994 Sun Microsystems, Inc."
---

# NAME

after - Execute a command after a time delay

# DESCRIPTION

```
# kein Heading im Code
```
}
schreib man/tk/bell.md {---
CommandName: bell
Keywords:
  - beep
---

# NAME

bell - Ring a display's bell
}

lassign [lauf manual-build.tcl man -md ohne.md] rc out
check "manual-build -md ohne -index"            {$rc == 0 && [string first "{.index}" [lies ohne.md]] < 0}

lassign [lauf manual-build.tcl man -md mit.md -index] rc out
set m [lies mit.md]
check "manual-build -index laeuft"              {$rc == 0}
check "Stichwortzeile: Name zuerst, Keywords, Dublette (After) weg, _ maskiert" {
    [string first "*Stichw\u00f6rter:* \[after\]{.index}, \[cancel\]{.index}, \[delay\]{.index}, \[sleep\\_ms\]{.index}" $m] >= 0}
check "Zeile fuer zweite Seite"                 {[string first "*Stichw\u00f6rter:* \[bell\]{.index}, \[beep\]{.index}" $m] >= 0}
check "Reihenfolge tcl/ vor tk/"                {[string first "# after" $m] < [string first "# bell" $m]}
# Teile: tcl/ und tk/ werden "# Tcl" und "# Tk", die Seiten
# eine Ebene darunter, ihre Abschnitte zwei
check "Teile Tcl und Tk"                        {[string first "\n# Tcl\n" "\n$m"] >= 0 && [string first "\n# Tk\n" $m] >= 0}
check "Seite unter dem Teil, Abschnitte darunter" {[string first "\n## after\n" $m] >= 0 && [string first "\n### DESCRIPTION" $m] >= 0}
lassign [lauf manual-build.tcl man -md flach.md -no-groups] rc out
set fl [lies flach.md]
check "-no-groups: flach wie bisher"             {$rc == 0 && [string first "\n## DESCRIPTION" $fl] >= 0 && [string first "# Tcl\n" $fl] < 0}
check "Code-Block unberuehrt"                   {[string first "\n# kein Heading im Code" $m] >= 0}
check "Copyright als Notiz, YAML weg"           {[string first "*Copyright (c) 1990 The Regents*" $m] >= 0 && [string first "CommandName" $m] < 0}
# zwei Zeilen: " \" vor dem Umbruch, sonst laufen sie zusammen
check "Copyright: zwei Zeilen getrennt"         {[string first "The Regents* \\\n*Copyright (c) 1994 Sun" $m] >= 0}

# Zaeune nach CommonMark: ``` in ```` ist Inhalt
schreib man4/tcl/z.md "# NAME\n\nz\n\n````\n```\n# kein Heading 1\n```\n# kein Heading 2\n````\n\n# DESCRIPTION\n\nText.\n"
lassign [lauf manual-build.tcl man4 -md z.md -no-groups] rc out
set zm [lies z.md]
check "Zaun: kurzer Zaun im langen bleibt Inhalt" {
    $rc == 0 && [string first "\n# kein Heading 1\n" $zm] >= 0 && [string first "\n# kein Heading 2\n" $zm] >= 0
    && [string first "\n## DESCRIPTION" $zm] >= 0}

# Copyright schon im Text (tcllib: "# Copyright"-Abschnitt): keine zweite
# Notiz aus dem YAML-Kopf
schreib man5/m/c.md "---\nCopyright:\n - Copyright (c) 2004, Pat <p@x.org>\n---\n\n# Name\n\nc\n\n# Copyright\n\n```\nCopyright (c) 2004, Pat <p@x.org>\n```\n"
lassign [lauf manual-build.tcl man5 -md c.md] rc out
check "Copyright aus YAML nicht doppelt"         {$rc == 0 && [string first "*Copyright (c) 2004" [lies c.md]] < 0}

lassign [lauf manual-build.tcl man -md en.md -index -index-label Keywords] rc out
check "-index-label"                            {[string first {*Keywords:* [after]{.index}} [lies en.md]] >= 0}

lassign [lauf manual-build.tcl man -html man.html -index -index-title Register] rc out
check "manual-build -html mit Index"            {$rc == 0 && [file exists man.html]}
if {[file exists man.html]} {
    set h [lies man.html]
    check "-index-title im HTML"                {[string first Register $h] >= 0}
    check "Stichwort sleep_ms im HTML-Index"    {[string first sleep_ms $h] >= 0}
}

# manual-build.tcl: CID-Schrift als Vorgabe (die Teilmenge macht U+202F
# in "z. B." zu "?"), -no-cid schaltet zurueck
if {$havePdf} {
    schreib man/tcl/nbsp.md "# NAME\n\nnbsp - z.\u202fB. \u2192 Pfeil\n"
    lassign [lauf manual-build.tcl man -pdf mcid.pdf] rc1 out1
    lassign [lauf manual-build.tcl man -pdf msub.pdf -no-cid] rc2 out2
    check "manual-build -pdf mit CID"          {$rc1 == 0 && [string first Identity-H [lies mcid.pdf iso8859-1]] >= 0}
    check "manual-build: keine Ersatzzeichen"   {[string first "replaced with '?'" $out1] < 0}
    check "manual-build -no-cid"               {$rc2 == 0 && [string first Identity-H [lies msub.pdf iso8859-1]] < 0}
} else {
    skip "manual-build -pdf mit CID" "pdf4tcl nicht ladbar"
}

# manual-build.tcl -index-tsv und index-gesamt.tcl (Gesamtindex ueber
# mehrere PDFs, Verweise als GoToR in die anderen Dateien)
if {$havePdf} {
    file mkdir gi
    lassign [lauf manual-build.tcl man -pdf gi/a.pdf -title Kern -index -index-tsv gi/a.index.tsv -label Kern] rc1 out1
    schreib man2/x/after.md "---\nCommandName: after\nKeywords:\n  - timer\n---\n\n# NAME\n\nafter - noch einmal\n"
    lassign [lauf manual-build.tcl man2 -pdf gi/b.pdf -index -index-tsv gi/b.index.tsv -label Zusatz] rc2 out2
    set t [lies gi/a.index.tsv]
    check "-index-tsv: Kopf und Seiten"         {$rc1 == 0 && [string first "# pdf\ta.pdf" $t] >= 0 && [string first "# label\tKern" $t] >= 0 && [regexp {\nafter\t[0-9]+} $t]}
    lassign [lauf index-gesamt.tcl -pdf gi/gesamt.pdf -md gi/gesamt.md gi/a.index.tsv gi/b.index.tsv] rc out
    set g [lies gi/gesamt.md]
    check "index-gesamt laeuft"                  {$rc == 0 && [file exists gi/gesamt.pdf]}
    check "Begriff aus zwei Handbuechern zusammen" {[regexp "\\*\\*after\\*\\* \u2014 Kern: \\\[\[0-9\]+\\\]\\(a\\.pdf#page=\[0-9\]+\\) \u00b7 Zusatz: " $g]}
    check "Verweis als GoToR in die andere Datei" {[regexp {/S /GoToR /F \(a\.pdf\) /D \[[0-9]+ /Fit\]} [lies gi/gesamt.pdf iso8859-1]]}
    lassign [lauf index-gesamt.tcl -links 0 -md gi/ohne.md gi/a.index.tsv] rc out
    check "-links 0: ohne Verweise"              {$rc == 0 && [string first "#page=" [lies gi/ohne.md]] < 0}
    # Kopfzeile mit Pfad und Nachbarn
    if {[string match "*ohne Kolumnentitel*" $out1]} {
        skip "manual-build: Kopfzeile" "docir ohne Kolumnentitel"
    } elseif {[auto_execok pdftotext] ne ""} {
        set k [exec pdftotext -enc UTF-8 -layout -f 2 -l 2 gi/a.pdf -]
        check "manual-build: Kopfzeile Titel und Kapitel" {[regexp "Kern.*tcl / after" [lindex [split [string trim $k] \n] 0]]}
    }
    lassign [lauf index-gesamt.tcl -lang en -links 0 -md gi/en.md gi/a.index.tsv] rc out
    check "-lang en"                             {$rc == 0 && [string first "# Combined index" [lies gi/en.md]] >= 0 && [string first "Terms from 1 manuals" [lies gi/en.md]] >= 0}
} else {
    skip "index-gesamt" "pdf4tcl nicht ladbar"
}


# style-check.tcl: Hinweise nach Buchtyp
set ue \u00fc
schreib stil/book.tcl "set title T\nset booktype workshop\nset chapters {010-a.md 020-b.md 800-anhang.md}\n"
schreib stil/010-a.md "# A\n\n*Stand: 2026-10-19*\n\nAm 2026-10-17, 22:25, gemessen: die Messprobe lief. Gemessen am 2026-10-18 und am 2026-10-19.\nText von Claude.\nNicht gemessen, nicht gepr${ue}ft, nicht ausgef${ue}hrt, nicht getestet, nicht gemessen.\nSiehe `book-x` und `book-y` und `book-z`.\n\n```\ngemessen 2026-01-01 im Code z\u00e4hlt nicht\n```\n"
schreib stil/020-b.md "# B\n\n*Stand: 2026-10-19*\n\nTk l\u00e4dt das Skript. Ein Satz ohne Auff\u00e4lligkeit.\nEntstanden mit Claude.\n"
schreib stil/800-anhang.md "# Anhang\n\nGemessen am 2026-10-17, 22:25 mit Claude.\n"
lassign [lauf style-check.tcl stil] rc out
check "style-check: Typ aus book.tcl"         {[string match "*workshop (Werkstattbuch)*" $out]}
check "style-check: Messung, Uhrzeit, Datum"  {[regexp {010-a\.md.*Messung 5 .*Uhrzeit 1.*Datum 3} $out]}
check "style-check: nicht gepr\u00fcft, Buch-ID" {[regexp {010-a\.md.*nicht gepr\u00fcft\" 5.*Buch-ID 3} $out]}
check "style-check: KI nur einmal je Buch"     {[regexp {020-b\.md.*Entstehung/KI} $out] && ![regexp {010-a\.md[^\n]*Entstehung} $out]}
check "style-check: Anhang nicht bewertet"     {![regexp {800-anhang\.md} $out]}
check "style-check: Stand-Zeilen"              {[string match "*2 Zeilen \\*Stand*" $out]}
check "style-check: Exit 0 ohne -strict"       {$rc == 0}
lassign [lauf style-check.tcl -strict -type referenz stil] rc out
check "style-check -strict, -type referenz"    {$rc == 1 && [string match "*reference (Referenz)*" $out]}
schreib stil2/book.tcl "set booktype manual\nset styleallow {buchid}\nset chapters {010-a.md}\n"
schreib stil2/010-a.md "# A\n\nSiehe `book-build.tcl` und `book-x`, `book-y`.\n\n## Zusammenfassung\n\n- kurz\n"
lassign [lauf style-check.tcl stil2] rc out
check "style-check: styleallow, Dateiname keine Buch-ID" {$rc == 0 && [string match "*0 mit Hinweisen*" $out]}
schreib stil2/book.tcl "set booktype manual\nset chapters {010-a.md}\n"
lassign [lauf style-check.tcl stil2] rc out
check "style-check: book-build.tcl zaehlt nicht"  {[regexp {Buch-ID 2 } $out]}
# book-check.tcl: Buchtyp
schreib bt/ohne/book.tcl "set title T\nset chapters {010-a.md}\n"
schreib bt/ohne/010-a.md "# A\n\nText.\n"
lassign [lauf book-check.tcl bt/ohne] rc out
check "book-check: fehlender booktype warnt"     {$rc == 0 && [string match "*WARN: kein booktype*" $out]}
schreib bt/ohne/book.tcl "set title T\nset booktype lehrbuch\nset chapters {010-a.md}\n"
lassign [lauf book-check.tcl bt/ohne] rc out
check "book-check: unbekannter booktype warnt"   {[string match "*WARN: unbekannter booktype 'lehrbuch'*" $out]}
schreib bt/ohne/book.tcl "set title T\nset booktype manual\nset chapters {010-a.md}\n"
lassign [lauf book-check.tcl bt/ohne] rc out
check "book-check: gueltiger booktype ohne Warnung" {[string match "*Warnungen 0*" $out]}

# code-compare.tcl: Codebloecke vor und nach einer Ueberarbeitung
schreib cc/alt/010-a.md "# A\n\nText.\n\n```tcl\nputs a ;# gemessen: 1\n```\n\n```\nzeile eins\n```\n\n- Liste:\n\n  ```\n  eingerueckt\n  ```\n\n```\nweg\n```\n"
schreib cc/neu/010-a.md "# A\n\nAnderer Text.\n\n```tcl\nputs a ;# -> 1\n```\n\n```\neingerueckt\n```\n"
schreib cc/neu/860-anhang.md "# Anhang\n\n```\nzeile eins\n```\n"
lassign [lauf code-compare.tcl cc/alt cc/neu] rc out
check "code-compare: Kommentar, verschoben, FEHLT" {$rc == 1 && [string match "*gleich 1, verschoben 1, nur Kommentar 1, FEHLT 1*" $out]}
check "code-compare: fehlender Block benannt"   {[string match "*FEHLT*010-a.md:* weg*" $out]}
file delete cc/alt/010-a.md
schreib cc/alt/010-a.md "# A\n\n```tcl\nputs a ;# gemessen: 1\n```\n"
lassign [lauf code-compare.tcl cc/alt cc/neu] rc out
check "code-compare: nur Kommentar -> Exit 0"   {$rc == 0}
lassign [lauf code-compare.tcl -strict cc/alt cc/neu] rc out
check "code-compare -strict -> Exit 1"          {$rc == 1}
lassign [lauf style-check.tcl -type unsinn stil] rc out
check "style-check: unbekannter Typ -> Exit 2" {$rc == 2}
schreib stil3/book.tcl "set booktype manual\nset chapters {010-a.md 020-b.md}\n"
schreib stil3/010-a.md "# A\n\n*As of: 2026-10-19*\n\nText.\n"
schreib stil3/020-b.md "# B\n\n*As of: 2026-10-19*\n\nText.\n"
lassign [lauf style-check.tcl stil3] rc out
check "style-check: englische Stand-Zeile"     {[string match "*2 Zeilen \\*Stand*" $out]}

# publish-check.tcl: Datum im Kommentar, privater Pfad, gebaute Datei,
# Buch aus dem privaten Register; Ausnahmen; sauberer Baum
schreib pub/kit/tools/a.tcl "# Review 2026-10-24 (B04): repariert\nputs ok\n"
schreib pub/kit/doc/x.md "# X\n\nAufruf: tclsh tool.tcl ~/daten\nSiehe book-geheim/Geheim-de.\n"
schreib pub/kit/out.pdf "%PDF-1.4\n"
schreib pub/privat/REGISTRY.md "| book-id | Quelle |\n|---|---|\n| geheim | `book-geheim/Geheim-de/` |\n"
schreib pub/privat/publish-deny.tsv "rechner\t\\mmeinpc\\M\teigener Rechner\n"
schreib pub/kit/doc/y.md "# Y\n\nAuf meinpc gebaut.\n"
lassign [lauf publish-check.tcl -privat pub/privat pub/kit] rc out
check "publish-check: Treffer -> Exit 1"         {$rc == 1}
check "publish-check: Datum und Review im Kommentar" {[string match "*a.tcl:1: \\\[datum\\\]*" $out] && [string match "*a.tcl:1: \\\[review\\\]*" $out]}
check "publish-check: persoenlicher Pfad"       {[string match "*x.md:3: \\\[heim\\\]*" $out]}
check "publish-check: Buch aus privatem Register" {[string match "*x.md:4: \\\[buch\\\]*" $out]}
check "publish-check: privates Muster"          {[string match "*y.md:3: \\\[rechner\\\]*" $out]}
check "publish-check: gebaute Datei"            {[string match "*out.pdf: \\\[datei:erzeugt\\\]*" $out]}
schreib pub/allow.tsv "*/doc/y.md\trechner\n"
lassign [lauf publish-check.tcl -privat pub/privat -allow pub/allow.tsv pub/kit] rc out
check "publish-check: Ausnahme greift"          {![string match "*y.md*" $out]}
schreib pub/kit/buch/book.tcl "set date      \"2026-10-25\"\n# Stand 2026-10-25\n"
lassign [lauf publish-check.tcl -privat pub/privat pub/kit] rc out
check "publish-check: set date in book.tcl erlaubt" {![string match "*book.tcl:1:*" $out] && [string match "*book.tcl:2: \\\[datum\\\]*" $out]}
file delete -force pub/kit/buch
schreib pub/kit/.gitignore "# gebaut\n*.pdf\n"
lassign [lauf publish-check.tcl -privat pub/privat pub/kit] rc out
check "publish-check: .gitignore schliesst aus" {![string match "*out.pdf*" $out]}
file delete pub/kit/.gitignore
file delete pub/kit/out.pdf
schreib pub/kit/tools/a.tcl "# Code-Fences nach CommonMark\nputs ok\n"
schreib pub/kit/doc/x.md "# X\n\nAufruf: tclsh tool.tcl /pfad/daten\n"
file delete pub/kit/doc/y.md
lassign [lauf publish-check.tcl -privat pub/privat pub/kit] rc out
check "publish-check: sauberer Baum -> Exit 0"  {$rc == 0 && [string match "*sauber*" $out]}

# book-check.tcl ohne Argumente: Register aus BOOKKIT_REGISTRY
schreib reg/buch/book.tcl "set title T\nset booktype manual\nset chapters {010-a.md}\n"
schreib reg/buch/010-a.md "# A\n\nText.\n"
schreib reg/REGISTRY.md "| book-id | Quelle | Sprachen | book.tcl | Buchtyp | Anmerkung |\n|---|---|---|---|---|---|\n| buch | `reg/buch/` | de | ja | `reference` | x |\n"
set env(BOOKKIT_REGISTRY) [file join $tmp reg REGISTRY.md]
lassign [lauf book-check.tcl] rc out
check "book-check: Register aus BOOKKIT_REGISTRY" {$rc == 0 && [string match "*reg/buch*" $out]}
check "book-check: Buchtyp weicht vom Register ab" {[string match "*REGISTRY.md sagt reference*" $out]}
set env(BOOKKIT_REGISTRY) [file join $tmp reg fehlt.md]
lassign [lauf book-check.tcl] rc out
check "book-check: Register fehlt -> Fehler"    {$rc == 1}
unset env(BOOKKIT_REGISTRY)

# book-migrate.tcl: Verweise auf Kapiteldateien -> Anker der H1
schreib mig/010-a.md "# Die `Grundlagen`\n\n\[b\](020-b.md), \[x\](020-b.md#unter), \[w\](http://x/020-b.md)\n"
schreib mig/020-b.md "# Zweites Kapitel: B\n\n## Unter\n\n\[a\](./010-a.md)\n"
lassign [lauf book-migrate.tcl mig -n] rc out
check "book-migrate -n aendert nichts"          {$rc == 0 && [string first "020-b.md)" [lies mig/010-a.md]] >= 0}
lassign [lauf book-migrate.tcl mig] rc out
set ma [lies mig/010-a.md]
check "book-migrate: Datei -> Anker der H1"     {[string first "(#zweites-kapitel-b)" $ma] >= 0 && [string first "(#unter)" $ma] >= 0}
check "book-migrate: fremde URL bleibt"         {[string first "(http://x/020-b.md)" $ma] >= 0}
check "book-migrate: ./datei.md"                {[string first "(#die-grundlagen)" [lies mig/020-b.md]] >= 0}

cd $old
file delete -force $tmp
puts "------------------------------------------"
puts "PASS $pass   FAIL $fail   SKIP $skip"
exit [expr {$fail > 0}]
