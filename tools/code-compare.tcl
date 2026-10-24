#!/usr/bin/env tclsh
# code-compare.tcl -- Codebloecke zweier Fassungen eines Buchs vergleichen.
#
#   tclsh bookkit/tools/code-compare.tcl ?-v? ?-strict? ALT NEU
#
#   ALT, NEU  Buchordner (oder einzelne .md-Dateien) vor und nach einer
#             Ueberarbeitung, etwa nach dem Umstellen auf einen Buchtyp
#             (doc/de/STYLE.md, Abschnitt "Ein Buch umstellen").
#   -v        bei geaenderten Bloecken die Zeilen zeigen (- alt, + neu)
#   -strict   auch geaenderte Kommentare zaehlen als Fehler
#
# Eine Ueberarbeitung des Texts darf Codebloecke nicht veraendern. Das
# Werkzeug liest alle Bloecke (``` und ~~~, auch eingerueckt in Listen) aus
# ALT und sucht jeden in NEU:
#
#   gleich        unveraendert in derselben Datei
#   verschoben    unveraendert, aber in einer anderen Datei (etwa in einen
#                 Anhang): erlaubt, wird gemeldet
#   Kommentar     nur Kommentare geaendert (# ... und ;# ... am Zeilenende,
#                 // ...): erlaubt, wird gemeldet; mit -strict ein Fehler
#   FEHLT         fehlt im Code oder ist dort geaendert
#
# Die Einrueckung des ganzen Blocks zaehlt nicht (ein Block kann in eine
# Liste wandern). Exit 0: nichts fehlt; 1: mindestens ein Block fehlt;
# 2: Aufruf.

proc usage {} {
    puts stderr "Aufruf: tclsh code-compare.tcl ?-v? ?-strict? ALT NEU"
    exit 2
}
set verbose 0; set strict 0; set paths {}
foreach a $argv {
    switch -- $a {
        -v      { set verbose 1 }
        -strict { set strict 1 }
        default { if {[string match -* $a]} usage; lappend paths $a }
    }
}
if {[llength $paths] != 2} usage
lassign $paths oldP newP

proc mdFiles {p} {
    if {[file isfile $p]} { return [list $p] }
    if {![file isdirectory $p]} { puts stderr "nicht gefunden: $p"; exit 2 }
    return [lsort [glob -nocomplain -directory $p *.md]]
}
proc lies {f} {
    set h [open $f r]; fconfigure $h -encoding utf-8
    set t [read $h]; close $h; return $t
}
# Bloecke einer Datei: Liste von {zeile text}; Einrueckung des Zauns entfernt
proc blocks {f} {
    set out {}
    set in 0; set n 0
    foreach line [split [lies $f] \n] {
        incr n
        if {!$in} {
            if {[regexp {^([ \t]*)(```|~~~)} $line -> ind fence]} {
                set in 1; set start $n; set body {}
                set indLen [string length $ind]
            }
            continue
        }
        if {[regexp "^\[ \t\]*$fence\[ \t\]*\$" $line]} {
            lappend out [list $start [join $body \n]]
            set in 0
            continue
        }
        # Einrueckung des Zauns abziehen, soweit vorhanden
        set k 0
        while {$k < $indLen && [string index $line $k] in {" " "\t"}} { incr k }
        lappend body [string range $line $k end]
    }
    return $out
}
# ohne Kommentare und Leerraum am Zeilenende
proc stripComments {s} {
    set out {}
    foreach line [split $s \n] {
        if {[regexp {^\s*(#|//)} $line]} continue
        regsub {\s*;\s*#.*$} $line {} line
        regsub {\s+(#|//)\s.*$} $line {} line
        set line [string trimright $line]
        if {$line ne ""} { lappend out $line }
    }
    return [join $out \n]
}

# Index der neuen Fassung: Text -> Dateien, Kommentarform -> Dateien
array set newExact {}
array set newLoose {}
array set newBlocks {}
foreach f [mdFiles $newP] {
    set tail [file tail $f]
    foreach b [blocks $f] {
        set t [lindex $b 1]
        lappend newExact($t) $tail
        lappend newLoose([stripComments $t]) [list $tail $t]
        lappend newBlocks($tail) $t
    }
}

set nAll 0; set nSame 0; set nMoved 0; set nComment 0; set nMissing 0
foreach f [mdFiles $oldP] {
    set tail [file tail $f]
    foreach b [blocks $f] {
        lassign $b line t
        incr nAll
        if {[info exists newExact($t)]} {
            if {$tail in $newExact($t)} {
                incr nSame
            } else {
                incr nMoved
                puts "verschoben  $tail:$line -> [join [lsort -unique $newExact($t)] {, }]"
            }
            continue
        }
        set loose [stripComments $t]
        if {$loose ne "" && [info exists newLoose($loose)]} {
            incr nComment
            lassign [lindex $newLoose($loose) 0] where nt
            puts "Kommentar   $tail:$line ([expr {$where eq $tail ? "gleiche Datei" : "jetzt in $where"}])"
            if {$verbose} {
                foreach a [split $t \n] b [split $nt \n] {
                    if {$a ne $b} { puts "    - $a"; puts "    + $b" }
                }
            }
            continue
        }
        incr nMissing
        set first [lindex [split [string trim $t] \n] 0]
        puts "FEHLT       $tail:$line  [string range $first 0 70]"
        if {$verbose} {
            foreach l [split $t \n] { puts "    - $l" }
        }
    }
}
puts "------------------------------------------"
puts "Bloecke $nAll: gleich $nSame, verschoben $nMoved, nur Kommentar $nComment, FEHLT $nMissing"
if {$nMissing || ($strict && $nComment)} { exit 1 }
exit 0
