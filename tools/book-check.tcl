#!/usr/bin/env tclsh
# book-check.tcl -- Spec-Pruefung eines bookkit-Buchs (ohne PDF-Vergleich).
#
# Fuehrt zusammen, was sonst von Hand laeuft: index-dedupe -n, Manifest gegen
# Verzeichnis, genau eine H1 je Kapitel, interne .md-Links, {.index} in
# Tabellenzellen, Glossar-Dateiname neben dem Buchordner.
#
# Aufruf (eine Ebene ueber dem inneren Buchordner, wie die anderen Werkzeuge):
#   tclsh bookkit/tools/book-check.tcl
#       ohne Argumente: alle Quelle-Pfade aus bookkit/doc/de/REGISTRY.md
#   tclsh bookkit/tools/book-check.tcl <book-dir>
#   tclsh bookkit/tools/book-check.tcl <book-dir> ...
#
# Fehlendes Registerverzeichnis zaehlt als Fehler. Exit 1, sobald ein
# Fehler zaehlt. Warnungen (Index in Tabelle, Glossarname) setzen den
# Exit-Code nicht.

package require Tcl 8.6-

set here [file dirname [file normalize [info script]]]


# book-ids of an edition: from the BOOKKIT.md table next to the book
# (| `Edition/` | lang | book-id |) and from the REGISTRY.md rows whose
# source column names this edition. The glossary is named after it.
proc bookIds {bookdir} {
    set ed     [file tail [file normalize $bookdir]]
    set parent [file dirname [file normalize $bookdir]]
    set ids {}
    set bk [file join $parent BOOKKIT.md]
    if {[file exists $bk] && ![catch {
            set txt [readUtf $bk]}]} {
        foreach line [split $txt \n] {
            set cells [lmap c [split [string trim $line |] |] {string trim $c}]
            if {[llength $cells] >= 3 && [string trim [lindex $cells 0] {`/}] eq $ed} {
                lappend ids [string trim [lindex $cells end] `]
            }
        }
    }
    global here
    set reg [file join $here .. doc de REGISTRY.md]
    if {[file exists $reg]} {
        foreach row [registryRows $reg] {
            lassign $row id src
            if {[string match "*[file tail $parent]/$ed*" $src]} { lappend ids $id }
        }
    }
    return [lsort -unique [lmap i $ids {if {$i eq ""} continue; set i}]]
}

proc manifestChapters {manifestPath} {
    set ip [interp create -safe]
    interp eval $ip {set chapters {}}
    set fh [open $manifestPath r]
    fconfigure $fh -encoding utf-8
    set script [read $fh]
    close $fh
    if {[catch {interp eval $ip $script} err]} {
        interp delete $ip
        error "book.tcl: $err"
    }
    set chapters [interp eval $ip {set chapters}]
    interp delete $ip
    return $chapters
}

proc skipFile {tail} {
    if {$tail in {
        README.md CONTRIBUTING.md LICENSE.md LICENSE BUCHSTRUKTUR.md
        BOOKKIT.md INHALTSVERZEICHNIS.md
        index.md stichwortverzeichnis.md
    }} {
        return 1
    }
    if {[string match BUCHSTRUKTUR* $tail]} { return 1 }
    if {[string match UPDATES* $tail]} { return 1 }
    return 0
}

proc readUtf {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set t [read $fh]
    close $fh
    return $t
}

proc inFence {inFenceVar line} {
    upvar 1 $inFenceVar inFence
    if {[string match {```*} $line]} {
        set inFence [expr {!$inFence}]
        return 1
    }
    return $inFence
}

proc checkBook {bookdir} {
    global here
    set errors 0
    set warns 0
    puts "== $bookdir"

    set manifest [file join $bookdir book.tcl]
    if {![file exists $manifest]} {
        puts "  ERROR: book.tcl fehlt"
        return 1
    }
    set chapters [manifestChapters $manifest]
    if {[llength $chapters] == 0} {
        puts "  ERROR: chapters-Liste leer"
        incr errors
    }

    foreach f $chapters {
        set path [file join $bookdir $f]
        if {![file exists $path]} {
            puts "  ERROR: Manifest, Datei fehlt: $f"
            incr errors
        }
    }

    foreach path [glob -nocomplain -directory $bookdir *.md] {
        set tail [file tail $path]
        if {[skipFile $tail]} continue
        if {$tail ni $chapters} {
            puts "  ERROR: Datei nicht im Manifest: $tail"
            incr errors
        }
    }

    foreach f $chapters {
        set path [file join $bookdir $f]
        if {![file exists $path]} continue
        set text [readUtf $path]
        set lines [split $text \n]
        set inFence 0
        set h1 0
        set n 0
        foreach line $lines {
            incr n
            if {[string match {```*} $line]} {
                set inFence [expr {!$inFence}]
                continue
            }
            if {$inFence} continue
            if {[regexp {^# } $line]} { incr h1 }
            if {[regexp {^\|.*\{\.index\}} $line]} {
                puts "  WARN: $f:$n Index-Marke in Tabellenzelle"
                incr warns
            }
            foreach {m href} [regexp -all -inline {\]\(([^)]+)\)} $line] {
                if {[string match {*://*} $href]} continue
                if {[string match #* $href]} continue
                set href [lindex [split $href #] 0]
                if {$href eq ""} continue
                if {![string match *.md $href]} continue
                set target [file join $bookdir $href]
                if {![file exists $target]} {
                    puts "  ERROR: $f:$n Link ins Leere: $href"
                    incr errors
                }
            }
        }
        if {$h1 != 1} {
            puts "  ERROR: $f: $h1 H1 (erwartet 1)"
            incr errors
        }
    }

    set dedupe [file join $here index-dedupe.tcl]
    if {[file exists $dedupe]} {
        set cmd [list [info nameofexecutable] $dedupe $bookdir -n]
        if {[catch {exec {*}$cmd 2>@1} out]} {
            append out ""
        }
        foreach line [split $out \n] {
            if {[string match "*Duplikat*" $line] && ![string match "----*" $line] \
                    && ![string match "dry-run*" $line] && ![string match "fertig*" $line]} {
                puts "  ERROR: index-dedupe: $line"
                incr errors
            }
        }
    }

    set gdir [file join [file dirname $bookdir] glossary]
    if {[file isdirectory $gdir]} {
        set tsvs [glob -nocomplain -directory $gdir *-glossary.tsv]
        set parent [file tail [file dirname $bookdir]]
        set ids [bookIds $bookdir]
        if {![llength $ids] && [string match book-* $parent]} {
            # No book-id recorded: fall back to the folder name.
            lappend ids [string range $parent 5 end]
        }
        if {[llength $ids] && [llength $tsvs] > 0} {
            # A translation (<id>-<lang>) shares the glossary of its source
            # book (I18N.md: one glossary per book, all languages).
            set wants {}
            foreach id $ids {
                lappend wants $id-glossary.tsv
                if {[regexp {^(.+)-[a-z][a-z]$} $id -> base]} {
                    lappend wants $base-glossary.tsv
                }
            }
            set found 0
            foreach t $tsvs {
                if {[file tail $t] in $wants} { set found 1 }
            }
            if {!$found} {
                puts "  WARN: Glossar heisst nicht [join $wants { / }] ([join [lmap t $tsvs {file tail $t}] {, }])"
                incr warns
            }
        }
    }

    puts "  -- Fehler $errors, Warnungen $warns"
    return $errors
}

# Zeilen aus REGISTRY.md: {id src} ...  src wie im Register, ohne Backticks.
proc registryRows {regPath} {
    set rows {}
    foreach line [split [readUtf $regPath] \n] {
        if {![string match "| *" $line]} continue
        set raw [string trim $line |]
        set cells {}
        foreach c [split $raw |] {
            lappend cells [string trim $c]
        }
        if {[llength $cells] < 2} continue
        set id [lindex $cells 0]
        if {$id eq "book-id" || [string match {-*} $id] || $id eq ""} continue
        set src [string trim [lindex $cells 1] "`"]
        if {$src eq ""} continue
        lappend rows [list $id $src]
    }
    return $rows
}

proc dirsFromRegistry {} {
    global here
    set reg [file join $here .. doc de REGISTRY.md]
    if {![file exists $reg]} {
        puts "ERROR: Register fehlt: $reg"
        return [list {} 1]
    }
    set dirs {}
    set failed 0
    foreach row [registryRows $reg] {
        lassign $row id src
        if {![file isdirectory $src]} {
            puts "ERROR: Register, Verzeichnis fehlt: $id ($src)"
            incr failed
            continue
        }
        lappend dirs $src
    }
    return [list $dirs $failed]
}

set dirs $argv
set failed 0
if {[llength $dirs] == 0} {
    lassign [dirsFromRegistry] dirs failed
    if {[llength $dirs] == 0 && $failed == 0} {
        puts stderr "Usage: book-check.tcl \[<book-dir> ...\]"
        puts stderr "Ohne Argumente: alle Quelle-Pfade aus bookkit/doc/de/REGISTRY.md"
        exit 1
    }
}

foreach d $dirs {
    if {![file isdirectory $d]} {
        puts "ERROR: kein Verzeichnis: $d"
        incr failed
        continue
    }
    incr failed [checkBook $d]
}
exit [expr {$failed > 0 ? 1 : 0}]
