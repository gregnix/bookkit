#!/usr/bin/env tclsh
# style-check.tcl -- Sprachstil eines Buchs nach seinem Buchtyp pruefen.
# Zaehlt je Kapitel Hinweise und bewertet sie nach dem
# booktype aus book.tcl. Findet Haeufungen, keine Einzelfehler.
#
#   tclsh bookkit/tools/style-check.tcl ?-type T? ?-strict? ?-all? BOOKDIR
#
#   -type T   Buchtyp, wenn book.tcl keinen nennt (oder um ihn zu uebersteuern):
#             textbook | workshop | manual | reference | developer
#             (auch: lehrbuch, werkstatt, handbuch, referenz, entwickler)
#   -strict   Exit 1, wenn es Hinweise gibt (fuer Skripte)
#   -all      auch Kapitel ohne Hinweis auflisten
#
# Gezaehlt wird im Fliesstext: ohne YAML-Kopf, Codebloecke und Inline-Code.
# Anhaenge (Dateiname 8nn-/9nn- oder "anhang"/"appendix") sind der Ort fuer
# Testumgebung, Daten und Quellen (auch den Hinweis auf KI); dort wird nichts
# bewertet, nur gezaehlt.
#
#   Messung   gemessen, Messung, Messprobe, messen ...  (je 1000 Woerter)
#   Datum     2026-10-19 im Text (ohne die Zeile *Stand: ...*)
#   Uhrzeit   Datum mit Uhrzeit (2026-10-17, 22:25)
#   Nicht     "nicht gemessen/geprueft/ausgefuehrt/getestet/nachgeprueft"
#   Stand     Zeile *Stand: ...* (*As of: ...*) unter der Kapitelueberschrift
#   KI        Claude, Anthropic, KI-Sprachmodell, "entstanden": nur in einem Kapitel
#   Buch-ID   `book-xyz` im Text
#   Zusammenfassung  Abschnitt "Zusammenfassung" (Referenz)
#
# book.tcl kann einzelne Pruefungen abschalten, wenn sie zum Thema gehoeren:
#   set styleallow {buchid}     ;# mess datum nicht buchid summary ki stand
#
# Nur ASCII im Quelltext (Umlaute als \u), damit Tcl 8.6 das Skript in
# jeder Locale gleich liest.

proc usage {} {
    puts stderr "Aufruf: tclsh style-check.tcl ?-type T? ?-strict? ?-all? BOOKDIR"
    exit 2
}

set type ""; set strict 0; set all 0; set dir ""
for {set i 0} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        -type   { set type [lindex $argv [incr i]] }
        -strict { set strict 1 }
        -all    { set all 1 }
        default {
            if {[string match -* $a] || $dir ne ""} usage
            set dir $a
        }
    }
}
if {$dir eq "" || ![file isdirectory $dir]} usage

array set alias {
    lehrbuch textbook werkstatt workshop werkstattbuch workshop
    handbuch manual referenz reference entwickler developer
    entwicklerbuch developer
}
array set typeName [list \
    textbook  "Lehrbuch" \
    workshop  "Werkstattbuch" \
    manual    "Handbuch" \
    reference "Referenz" \
    developer "Entwicklerbuch"]

# Grenzwerte je Typ: Messung je 1000 Woerter, Datum, Nicht, Buch-ID je Kapitel,
# Zusammenfassung erlaubt
array set limit {
    textbook  {mess 1 datum 1 nicht 2 buchid 0 summary 1}
    workshop  {mess 3 datum 2 nicht 4 buchid 2 summary 1}
    manual    {mess 1 datum 1 nicht 2 buchid 0 summary 1}
    reference {mess 0 datum 0 nicht 0 buchid 0 summary 0}
    developer {mess 5 datum 2 nicht 4 buchid 2 summary 1}
}

proc lies {f} {
    set fh [open $f r]; fconfigure $fh -encoding utf-8
    set t [read $fh]; close $fh; return $t
}

# book.tcl als Daten lesen (wie book-build.tcl)
set chapters {}
set bookType ""
set styleAllow {}
set manifest [file join $dir book.tcl]
if {[file isfile $manifest]} {
    set ip [interp create -safe]
    interp eval $ip {set chapters {}; set booktype ""; set styleallow {}}
    if {[catch {interp eval $ip [lies $manifest]} err]} {
        puts stderr "book.tcl: $err"; exit 2
    }
    set chapters [interp eval $ip {set chapters}]
    set bookType [interp eval $ip {set booktype}]
    set styleAllow [interp eval $ip {set styleallow}]
    interp delete $ip
}
if {![llength $chapters]} {
    foreach f [lsort [glob -nocomplain -tails -directory $dir {[0-9]*.md}]] { lappend chapters $f }
}
if {$type eq ""} { set type $bookType }
set type [string tolower $type]
if {[info exists alias($type)]} { set type $alias($type) }
set typeNote ""
if {$type eq ""} {
    set type textbook
    set typeNote "  (book.tcl nennt keinen booktype; gepr${ue}ft als Lehrbuch, -type setzt ihn)"
} elseif {![info exists limit($type)]} {
    puts stderr "unbekannter Buchtyp: $type (textbook workshop manual reference developer)"
    exit 2
}
array set L $limit($type)

# Woerter (Umlaute als \u)
set ae \u00e4; set oe \u00f6; set ue \u00fc
set reMess  "(?i)\\m(gemessen\\w*|messung\\w*|messprobe\\w*|messskript\\w*|messwert\\w*|messen|misst)\\M"
set reNicht "(?i)\\mnicht\\s+(gemessen|gepr${ue}ft|ausgef${ue}hrt|getestet|nachgepr${ue}ft|nachgesehen)\\M"
set reKI    "(?i)\\m(claude|anthropic|ki-sprachmodell|chatgpt|cursor-assistent)\\M|entstanden ist|wie das buch entstand"
set reDatum {\m20[0-9]{2}-[01][0-9]-[0-3][0-9]\M}
set reZeit  {\m20[0-9]{2}-[01][0-9]-[0-3][0-9],?\s+(um\s+)?[0-2]?[0-9]:[0-5][0-9]\M}

# Fliesstext einer Kapiteldatei: {text standZeile buchIds summary}
proc prose {t} {
    set out {}
    set code 0; set yaml 0; set stand 0; set summary 0; set ids 0
    set n 0
    foreach line [split $t \n] {
        incr n
        if {$n == 1 && $line eq "---"} { set yaml 1; continue }
        if {$yaml} { if {$line eq "---"} { set yaml 0 }; continue }
        if {[regexp {^\s*(```|~~~)} $line]} { set code [expr {!$code}]; continue }
        if {$code} continue
        if {[regexp {^\*Stand:.*\*\s*$} $line] || [regexp {^\*(Status|As of):.*\*\s*$} $line]} { incr stand; continue }
        if {[regexp -nocase {^#{2,6}\s+(zusammenfassung|summary)\s*$} $line]} { set summary 1 }
        # `book-xyz` ist eine Buchkennung, `book-build.tcl` ein Dateiname
        foreach m [regexp -all -inline {`book-[A-Za-z0-9.-]+`} $line] {
            if {![regexp {\.(tcl|tm|md|sh|pdf|html|tsv|txt|db)`$} $m]} { incr ids }
        }
        regsub -all {`[^`]*`} $line { } line
        regsub -all {\]\([^)]*\)} $line {]} line   ;# Linkziele
        lappend out $line
    }
    return [list [join $out \n] $stand $ids $summary]
}

set rows {}
set kiChapters {}
set nHints 0
set standTotal 0
foreach ch $chapters {
    set f [file join $dir $ch]
    if {![file isfile $f]} continue
    lassign [prose [lies $f]] text stand ids summary
    incr standTotal $stand
    set words [llength [regexp -all -inline {\S+} $text]]
    set appendix [expr {[regexp {^[89][0-9][0-9]-} $ch] || [regexp -nocase {anhang|appendix} $ch]}]
    set mess  [regexp -all $reMess $text]
    set zeit  [regexp -all $reZeit $text]
    set datum [regexp -all $reDatum $text]
    set nicht [regexp -all $reNicht $text]
    set ki    [regexp -all $reKI $text]
    if {$ki && !$appendix} { lappend kiChapters $ch }   ;# Anhang Quellen darf es nennen
    set hints {}
    if {!$appendix} {
        # book.tcl: set styleallow {buchid ...} schaltet Hinweise ab, die zum
        # Thema des Buchs gehoeren (ein Buch ueber bookkit nennt Buchkennungen)
        foreach k {mess datum nicht buchid summary} {
            if {$k in $styleAllow} { set L($k) 1000000 }
        }
        set dens [expr {$words ? 1000.0 * $mess / $words : 0}]
        if {$mess && $dens > $L(mess)} {
            lappend hints [format "Messung %d (%.1f je 1000 W., max %s)" $mess $dens $L(mess)]
        }
        if {$zeit} { lappend hints "Uhrzeit $zeit" }
        if {$datum > $L(datum)} { lappend hints "Datum $datum (max $L(datum))" }
        if {$nicht > $L(nicht)} { lappend hints "\"nicht gepr${ue}ft\" $nicht (max $L(nicht), Kasten Getestet mit)" }
        if {$ids > $L(buchid)} { lappend hints "Buch-ID $ids (max $L(buchid))" }
        if {$summary && !$L(summary)} { lappend hints "Zusammenfassung" }
    }
    lappend rows [list $ch $words $mess $datum $nicht $ki $appendix $hints]
}
# KI/Entstehung: im ersten Kapitel, das es erwaehnt, erlaubt
set kiExtra [lrange $kiChapters 1 end]

puts "Buch:  $dir"
puts "Typ:   $type ($typeName($type))$typeNote"
puts ""
puts [format "%-34s %6s %5s %5s %5s %3s  %s" Kapitel W${oe}rter Mess Datum Nicht KI Hinweise]
set nWith 0
foreach r $rows {
    lassign $r ch words mess datum nicht ki appendix hints
    if {$ch in $kiExtra && "ki" ni $styleAllow} { lappend hints "Entstehung/KI erw${ae}hnt (nur einmal je Buch)" }
    if {[llength $hints]} { incr nWith; incr nHints [llength $hints] }
    if {!$all && ![llength $hints]} continue
    set name $ch
    if {$appendix} { append name " (A)" }
    puts [format "%-34s %6d %5d %5d %5d %3d  %s" $name $words $mess $datum $nicht $ki [join $hints "; "]]
}
puts ""
if {$standTotal > 1 && "stand" ni $styleAllow} {
    puts "Hinweis: $standTotal Zeilen *Stand: ...* in Kapiteln; ein Stand je Buch reicht (README, book.tcl)."
    incr nHints
}
puts "[llength $rows] Kapitel, $nWith mit Hinweisen. (A) = Anhang, dort nur gez${ae}hlt, nicht bewertet."
if {$strict && $nHints} { exit 1 }
exit 0
