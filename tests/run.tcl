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
# Teile (2026-10-24): tcl/ und tk/ werden "# Tcl" und "# Tk", die Seiten
# eine Ebene darunter, ihre Abschnitte zwei
check "Teile Tcl und Tk"                        {[string first "\n# Tcl\n" "\n$m"] >= 0 && [string first "\n# Tk\n" $m] >= 0}
check "Seite unter dem Teil, Abschnitte darunter" {[string first "\n## after\n" $m] >= 0 && [string first "\n### DESCRIPTION" $m] >= 0}
lassign [lauf manual-build.tcl man -md flach.md -no-groups] rc out
set fl [lies flach.md]
check "-no-groups: flach wie bisher"             {$rc == 0 && [string first "\n## DESCRIPTION" $fl] >= 0 && [string first "# Tcl\n" $fl] < 0}
check "Code-Block unberuehrt"                   {[string first "\n# kein Heading im Code" $m] >= 0}
check "Copyright als Notiz, YAML weg"           {[string first "*Copyright (c) 1990 The Regents*" $m] >= 0 && [string first "CommandName" $m] < 0}
# zwei Zeilen: " \" vor dem Umbruch, sonst liefen sie zusammen (2026-10-24)
check "Copyright: zwei Zeilen getrennt"         {[string first "The Regents* \\\n*Copyright (c) 1994 Sun" $m] >= 0}

lassign [lauf manual-build.tcl man -md en.md -index -index-label Keywords] rc out
check "-index-label"                            {[string first {*Keywords:* [after]{.index}} [lies en.md]] >= 0}

lassign [lauf manual-build.tcl man -html man.html -index -index-title Register] rc out
check "manual-build -html mit Index"            {$rc == 0 && [file exists man.html]}
if {[file exists man.html]} {
    set h [lies man.html]
    check "-index-title im HTML"                {[string first Register $h] >= 0}
    check "Stichwort sleep_ms im HTML-Index"    {[string first sleep_ms $h] >= 0}
}

# manual-build.tcl: CID-Schrift als Vorgabe (bis 2026-10-22 nur Teilmenge:
# U+202F in "z. B." wurde zu "?"), -no-cid schaltet zurueck
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
    # Kopfzeile mit Pfad und Nachbarn (docir ab 2026-10-23)
    if {[string match "*ohne Kolumnentitel*" $out1]} {
        skip "manual-build: Kopfzeile" "docir ohne Kolumnentitel (vor 2026-10-23)"
    } elseif {[auto_execok pdftotext] ne ""} {
        set k [exec pdftotext -enc UTF-8 -layout -f 2 -l 2 gi/a.pdf -]
        check "manual-build: Kopfzeile Titel und Kapitel" {[regexp "Kern.*tcl / after" [lindex [split [string trim $k] \n] 0]]}
    }
    lassign [lauf index-gesamt.tcl -lang en -links 0 -md gi/en.md gi/a.index.tsv] rc out
    check "-lang en"                             {$rc == 0 && [string first "# Combined index" [lies gi/en.md]] >= 0 && [string first "Terms from 1 manuals" [lies gi/en.md]] >= 0}
} else {
    skip "index-gesamt" "pdf4tcl nicht ladbar"
}


# style-check.tcl: Hinweise nach Buchtyp (doc/de/STYLE.md)
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

cd $old
file delete -force $tmp
puts "------------------------------------------"
puts "PASS $pass   FAIL $fail   SKIP $skip"
exit [expr {$fail > 0}]
