#!/usr/bin/env tclsh
# publish-check.tcl -- vor dem Veroeffentlichen pruefen, ob Arbeitsnotizen,
# private Pfade oder erzeugte Dateien im Quellbaum stehen.
#
#   tclsh bookkit/tools/publish-check.tcl ?-privat DIR? ?-deny FILE? ?-allow FILE?
#                                         ?-quiet? PATH ...
#
#   PATH      Ordner oder Dateien, die veroeffentlicht werden sollen
#             (z. B. bookkit/ und ein Buchordner).
#   -privat   Ordner mit dem privaten Teil (Vorgabe: bookkit-privat/ neben
#             bookkit/, wenn vorhanden). Aus ihm werden gelesen:
#               publish-deny.tsv   weitere Muster (eigene Namen, Rechner ...)
#               publish-allow.tsv  weitere Ausnahmen
#               REGISTRY.md        Quellordner der eigenen Buecher (Spalte 2);
#                                  ihre Namen duerfen nicht im Text stehen
#   -deny F   zusaetzliche Musterdatei (mehrfach moeglich)
#   -allow F  zusaetzliche Ausnahmedatei (mehrfach moeglich)
#   -quiet    nur die Zusammenfassung
#
# Musterdatei (TSV, # = Kommentar): name <TAB> regex <TAB> hinweis
#   Ein name, der mit "datei:" beginnt, prueft den relativen Dateipfad statt
#   der Zeilen. Ein name, der mit "kommentar:" beginnt, prueft nur
#   Kommentarzeilen in .tcl-Dateien.
# Ausnahmedatei (TSV): glob <TAB> name ?<TAB> regex?
#   glob gegen den relativen Pfad ("*" passt auch ueber "/"), name ist der
#   Mustername (oder "*"), regex schraenkt auf passende Zeilen ein.
#
# Die allgemeinen Muster stehen in publish-deny.tsv und publish-allow.tsv neben
# diesem Skript. Eigene Namen gehoeren nur in den privaten Teil, sonst stuende
# die Liste selbst im veroeffentlichten Baum.
#
# Dateien, die eine .gitignore im Baum ausschliesst (einfache Muster), werden
# uebersprungen: sie werden auch nicht veroeffentlicht.
#
# Exit: 0 sauber, 1 Treffer, 2 Aufruffehler.
# Nur ASCII im Quelltext (Umlaute als \u), damit Tcl 8.6 das Skript in jeder
# Locale gleich liest.

package require Tcl 8.6-
fconfigure stdout -encoding utf-8

proc usage {} {
    puts stderr "Aufruf: tclsh publish-check.tcl ?-privat DIR? ?-deny FILE? ?-allow FILE? ?-quiet? PATH ..."
    exit 2
}

set here [file dirname [file normalize [info script]]]
set privat ""; set denyFiles {}; set allowFiles {}; set quiet 0; set paths {}
for {set i 0} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        -privat { set privat [lindex $argv [incr i]] }
        -deny   { lappend denyFiles [lindex $argv [incr i]] }
        -allow  { lappend allowFiles [lindex $argv [incr i]] }
        -quiet  { set quiet 1 }
        default {
            if {[string match -* $a]} usage
            lappend paths $a
        }
    }
}
if {![llength $paths]} usage

proc readUtf {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8 -translation auto
    set data [read $fh]
    close $fh
    return $data
}

proc tsvRows {path} {
    set rows {}
    foreach line [split [readUtf $path] \n] {
        if {[string trim $line] eq "" || [string match "#*" $line]} continue
        lappend rows [split $line \t]
    }
    return $rows
}

# --- Muster und Ausnahmen sammeln --------------------------------------------

set deny {}     ;# {name regex hinweis}
set regBooks {} ;# Quellordner aus dem privaten Register
set allow {}    ;# {glob name regex}

proc addDeny {path} {
    global deny
    foreach r [tsvRows $path] {
        lassign $r name re hint
        if {$name eq "" || $re eq ""} continue
        if {[catch {regexp -- $re ""} err]} {
            puts stderr "$path: Muster $name ist kein gueltiger regex: $err"
            exit 2
        }
        lappend deny [list $name $re $hint]
    }
}
proc addAllow {path} {
    global allow
    foreach r [tsvRows $path] {
        lassign $r glob name re
        if {$glob eq ""} continue
        if {$name eq ""} { set name * }
        lappend allow [list $glob $name $re]
    }
}

foreach f [list [file join $here publish-deny.tsv]] {
    if {[file exists $f]} { addDeny $f }
}
foreach f [list [file join $here publish-allow.tsv]] {
    if {[file exists $f]} { addAllow $f }
}

if {$privat eq ""} {
    set cand [file join [file dirname [file dirname $here]] bookkit-privat]
    if {[file isdirectory $cand]} { set privat $cand }
}
if {$privat ne ""} {
    if {![file isdirectory $privat]} {
        puts stderr "privater Teil nicht gefunden: $privat"
        exit 2
    }
    set f [file join $privat publish-deny.tsv]
    if {[file exists $f]} { addDeny $f }
    set f [file join $privat publish-allow.tsv]
    if {[file exists $f]} { addAllow $f }
    # Quellordner der eigenen Buecher aus dem Register: Spalte 2, `a/b/`.
    set f [file join $privat REGISTRY.md]
    if {[file exists $f]} {
        set seen [dict create]
        foreach line [split [readUtf $f] \n] {
            if {![string match "|*" $line]} continue
            set cells [split $line |]
            set src [string trim [lindex $cells 2] " `"]
            foreach part [file split $src] {
                # nur sprechende Ordnernamen, keine allgemeinen Woerter
                if {[string length $part] < 6 || ![regexp {[-_]} $part]} continue
                if {[dict exists $seen $part]} continue
                dict set seen $part 1
                lappend regBooks $part
            }
        }
    }
} elseif {!$quiet} {
    puts "Hinweis: kein privater Teil (bookkit-privat/) -- nur allgemeine Muster."
}
foreach f $denyFiles  { addDeny $f }
foreach f $allowFiles { addAllow $f }

# --- Dateien -------------------------------------------------------------------

# .gitignore: einfache Muster (ohne "!"), gelten fuer den Ordner und alles
# darunter; "name/" nur fuer Ordner. Was git nicht veroeffentlicht, wird
# nicht geprueft (gebaute PDFs neben dem Buch).
proc ignored {tail isDir pats} {
    foreach pat $pats {
        if {[string index $pat end] eq "/"} {
            if {$isDir && [string match [string trimright $pat /] $tail]} { return 1 }
        } elseif {[string match $pat $tail]} {
            return 1
        }
    }
    return 0
}

proc walk {dir {pats {}}} {
    set gi [file join $dir .gitignore]
    if {[file exists $gi]} {
        foreach line [split [readUtf $gi] \n] {
            set line [string trim $line]
            if {$line eq "" || [string match "#*" $line] || [string match "!*" $line]} continue
            lappend pats [string trimleft $line /]
        }
    }
    set out {}
    foreach p [lsort [glob -nocomplain -directory $dir *]] {
        set t [file tail $p]
        if {$t in {.git bookkit-privat}} continue
        set isDir [file isdirectory $p]
        if {[ignored $t $isDir $pats]} continue
        if {$isDir} {
            lappend out {*}[walk $p $pats]
        } else {
            lappend out $p
        }
    }
    return $out
}

set files {}
foreach p $paths {
    if {[file isdirectory $p]} {
        foreach f [walk $p] { lappend files [list $f [file join [file tail [file normalize $p]] [string range $f [string length $p]+1 end]]] }
    } elseif {[file exists $p]} {
        lappend files [list $p [file tail $p]]
    } else {
        puts stderr "nicht gefunden: $p"
        exit 2
    }
}

# Buecher aus dem Register, die gerade selbst geprueft werden (oder als
# Vorlage darin liegen), sind oeffentlich: ihre Namen sind kein Treffer.
set published [dict create]
foreach fr $files {
    foreach part [lrange [file split [lindex $fr 1]] 0 end-1] { dict set published $part 1 }
}
foreach part $regBooks {
    if {[dict exists $published $part]} continue
    set skip 0
    dict for {p -} $published { if {[string match $p* $part]} { set skip 1; break } }
    if {$skip} continue
    lappend deny [list buch "\\m[string map {. \\. + \\+} $part]\\M" \
        "Quellordner eines eigenen Buchs (REGISTRY)"]
}

proc allowed {rel name line} {
    global allow
    foreach a $allow {
        lassign $a glob aname re
        if {![string match $glob $rel]} continue
        if {$aname ne "*" && $aname ne $name} continue
        if {$re ne "" && ![regexp -- $re $line]} continue
        return 1
    }
    return 0
}

set textExt {.md .tcl .tsv .txt .tm .sh .csv .json .yaml .yml ""}
set hits 0
array set perName {}
array set perFile {}

proc hit {rel lnum name text hint} {
    global hits perName perFile quiet
    incr hits
    incr perName($name)
    incr perFile($rel)
    if {!$quiet} {
        set text [string trim $text]
        if {[string length $text] > 110} { set text "[string range $text 0 106] ..." }
        if {$lnum} {
            puts "$rel:$lnum: \[$name\] $text"
        } else {
            puts "$rel: \[$name\] $hint"
        }
    }
}

foreach fr $files {
    lassign $fr path rel
    # Dateinamen
    foreach d $deny {
        lassign $d name re hint
        if {![string match datei:* $name]} continue
        if {[regexp -- $re $rel] && ![allowed $rel $name ""]} {
            hit $rel 0 $name "" $hint
        }
    }
    set ext [string tolower [file extension $path]]
    if {$ext ni $textExt && [file tail $path] ni {LICENSE README}} continue
    if {[catch {readUtf $path} data]} continue
    if {[string first \x00 $data] >= 0} continue
    set isTcl [expr {$ext in {.tcl .tm}}]
    set lnum 0
    foreach line [split $data \n] {
        incr lnum
        set isComment [regexp {^\s*#} $line]
        set done {}
        foreach d $deny {
            lassign $d name re hint
            if {[string match datei:* $name] || $name in $done} continue
            if {[string match kommentar:* $name] && !($isTcl && $isComment)} continue
            if {![regexp -- $re $line]} continue
            if {[allowed $rel $name $line]} continue
            hit $rel $lnum $name $line $hint
            lappend done $name
        }
    }
}

# --- Zusammenfassung -----------------------------------------------------------

if {$hits == 0} {
    puts "publish-check: sauber ([llength $files] Dateien)."
    exit 0
}
puts ""
puts "publish-check: $hits Treffer in [array size perFile] Dateien."
foreach n [lsort [array names perName]] {
    set hint ""
    foreach d $deny { if {[lindex $d 0] eq $n} { set hint [lindex $d 2]; break } }
    puts [format "  %-22s %4d  %s" $n $perName($n) $hint]
}
exit 1
