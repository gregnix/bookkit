#!/usr/bin/env tclsh
# i18n-status.tcl -- which chapters of a translation lag behind the source?
#
# For every translated chapter a snapshot of the source chapter is kept, as it
# was when the chapter was last translated. Comparing source and snapshot
# tells whether the translation is current, outdated or missing; -diff shows
# what changed in the source since then.
#
# Usage (one level above the book folders, like the other tools):
#   tclsh bookkit/tools/i18n-status.tcl <src-dir> <tr-dir>
#   tclsh bookkit/tools/i18n-status.tcl <src-dir> <tr-dir> -diff <chapter>
#   tclsh bookkit/tools/i18n-status.tcl <src-dir> <tr-dir> -mark <chapter> ...
#   tclsh bookkit/tools/i18n-status.tcl <src-dir> <tr-dir> -mark-all
# Option: -id <book-id> (otherwise taken from i18n/<id>-anchors-<lang>.tsv
# or from the source folder name).
#
# Storage next to the book folders:
#   i18n/<id>-sync-<lang>.tsv     chapter, crc32, date of marking
#   i18n/<id>-sync-<lang>/<ch>    snapshot of the source chapter
#
# Lines starting with "*Stand:" are ignored when comparing, so a mere date
# bump in the source does not make a translation outdated.
#
# Pure Tcl, runs with 8.6 and 9.x. Exit 0, also when chapters are outdated.

package require Tcl 8.6-

proc usage {} {
    puts stderr "usage: i18n-status.tcl <src-dir> <tr-dir> \
        ?-id <book-id>? ?-diff <chapter>? ?-mark <chapter> ...? ?-mark-all?"
    exit 2
}

proc readUtf {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8 -translation auto
    set data [read $fh]
    close $fh
    return $data
}

proc writeUtf {path data} {
    file mkdir [file dirname $path]
    set fh [open $path w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $data
    close $fh
}

# Chapter list from book.tcl, evaluated in a safe interpreter.
proc manifestChapters {dir} {
    set path [file join $dir book.tcl]
    if {![file exists $path]} {
        error "book.tcl fehlt in $dir"
    }
    set ip [interp create -safe]
    interp eval $ip {set chapters {}}
    if {[catch {interp eval $ip [readUtf $path]} err]} {
        interp delete $ip
        error "$path: $err"
    }
    set chapters [interp eval $ip {set chapters}]
    interp delete $ip
    return $chapters
}

# Text used for comparison: without "*Stand:" lines, without trailing blanks.
proc normalize {text} {
    set out {}
    foreach line [split [string map {"\r\n" "\n"} $text] \n] {
        if {[string match {\*Stand:*} $line]} continue
        lappend out [string trimright $line]
    }
    return [string trimright [join $out \n]]
}

proc fingerprint {text} {
    format %08x [zlib crc32 [encoding convertto utf-8 [normalize $text]]]
}

# --- line diff (LCS), enough for chapters of a few hundred lines -----------

proc lineDiff {old new {context 2}} {
    set a [split [normalize $old] \n]
    set b [split [normalize $new] \n]
    set n [llength $a]
    set m [llength $b]
    # L(i,j) = LCS length of a[i..] and b[j..], one flat list per row.
    set next [lrepeat [expr {$m + 1}] 0]
    set rows [list $next]
    for {set i [expr {$n - 1}]} {$i >= 0} {incr i -1} {
        set row [lrepeat [expr {$m + 1}] 0]
        set ai [lindex $a $i]
        for {set j [expr {$m - 1}]} {$j >= 0} {incr j -1} {
            if {$ai eq [lindex $b $j]} {
                lset row $j [expr {[lindex $next [expr {$j + 1}]] + 1}]
            } else {
                set x [lindex $next $j]
                set y [lindex $row [expr {$j + 1}]]
                lset row $j [expr {$x > $y ? $x : $y}]
            }
        }
        lappend rows $row
        set next $row
    }
    # rows were built bottom-up: row for index i is at position n-i.
    set ops {}
    set i 0
    set j 0
    while {$i < $n || $j < $m} {
        if {$i < $n && $j < $m && [lindex $a $i] eq [lindex $b $j]} {
            lappend ops [list = $i $j [lindex $a $i]]
            incr i
            incr j
        } elseif {$j < $m && ($i >= $n ||
                [lindex $rows [expr {$n - $i}] [expr {$j + 1}]] >=
                [lindex $rows [expr {$n - $i - 1}] $j])} {
            lappend ops [list + $i $j [lindex $b $j]]
            incr j
        } else {
            lappend ops [list - $i $j [lindex $a $i]]
            incr i
        }
    }
    # Print changed lines with some context; "@@ de line N" marks a hunk.
    set keep {}
    set k 0
    foreach op $ops {
        if {[lindex $op 0] ne "="} {
            for {set c [expr {$k - $context}]} {$c <= $k + $context} {incr c} {
                dict set keep $c 1
            }
        }
        incr k
    }
    set out {}
    set last -2
    set k 0
    foreach op $ops {
        if {[dict exists $keep $k]} {
            lassign $op kind i j line
            if {$k != $last + 1} {
                lappend out "@@ de Zeile [expr {$j + 1}]"
            }
            switch -- $kind {
                = { lappend out "  $line" }
                + { lappend out "+ $line" }
                - { lappend out "- $line" }
            }
            set last $k
        }
        incr k
    }
    return [join $out \n]
}

# --- arguments -------------------------------------------------------------

if {$argc < 2} usage
set srcDir [file normalize [lindex $argv 0]]
set trDir  [file normalize [lindex $argv 1]]
set bookId ""
set diffChapter ""
set markList {}
set markAll 0
set rest [lrange $argv 2 end]
while {[llength $rest]} {
    set rest [lassign $rest opt]
    switch -- $opt {
        -id       { set rest [lassign $rest bookId] }
        -diff     { set rest [lassign $rest diffChapter] }
        -mark-all { set markAll 1 }
        -mark {
            while {[llength $rest] && ![string match -* [lindex $rest 0]]} {
                set rest [lassign $rest ch]
                lappend markList $ch
            }
        }
        default usage
    }
}

foreach d [list $srcDir $trDir] {
    if {![file isdirectory $d]} {
        puts stderr "kein Verzeichnis: $d"
        exit 1
    }
}

set parent [file dirname $trDir]
if {![regexp -- {-([a-z][a-z])$} [file tail $trDir] -> lang]} {
    puts stderr "Sprache nicht erkennbar: [file tail $trDir] (erwartet ...-<lang>)"
    exit 1
}
if {$bookId eq ""} {
    set maps [glob -nocomplain -directory [file join $parent i18n] *-anchors-$lang.tsv]
    if {[llength $maps] == 1} {
        set bookId [string range [file tail [lindex $maps 0]] 0 \
            end-[string length "-anchors-$lang.tsv"]]
    } else {
        regsub -- {-[a-z][a-z]$} [file tail $srcDir] {} bookId
        set bookId [string tolower $bookId]
    }
}

set syncFile [file join $parent i18n $bookId-sync-$lang.tsv]
set snapDir  [file join $parent i18n $bookId-sync-$lang]

# chapter -> {crc date}
set sync [dict create]
if {[file exists $syncFile]} {
    foreach line [split [readUtf $syncFile] \n] {
        if {$line eq "" || [string match #* $line]} continue
        set cells [split $line \t]
        if {[lindex $cells 0] eq "chapter"} continue
        dict set sync [lindex $cells 0] [lrange $cells 1 2]
    }
}

proc saveSync {} {
    global sync syncFile
    set out "# i18n-status.tcl: source chapter as of last translation\n"
    append out "chapter\tcrc32\tmarked\n"
    foreach ch [lsort [dict keys $sync]] {
        append out "$ch\t[join [dict get $sync $ch] \t]\n"
    }
    writeUtf $syncFile $out
}

set srcChapters [manifestChapters $srcDir]
set trChapters  [manifestChapters $trDir]

# --- -mark / -mark-all -----------------------------------------------------

if {$markAll} {
    set markList [lmap ch $srcChapters {
        if {![file exists [file join $trDir $ch]]} continue
        set ch
    }]
}
if {[llength $markList]} {
    set today [clock format [clock seconds] -format %Y-%m-%d]
    set errors 0
    foreach ch $markList {
        set src [file join $srcDir $ch]
        if {![file exists $src]} {
            puts stderr "nicht in der Quelle: $ch"
            incr errors
            continue
        }
        if {![file exists [file join $trDir $ch]]} {
            puts stderr "noch nicht übersetzt: $ch"
            incr errors
            continue
        }
        set text [readUtf $src]
        writeUtf [file join $snapDir $ch] $text
        dict set sync $ch [list [fingerprint $text] $today]
        puts "markiert: $ch"
    }
    saveSync
    exit [expr {$errors ? 1 : 0}]
}

# --- -diff -------------------------------------------------------------------

if {$diffChapter ne ""} {
    set src [file join $srcDir $diffChapter]
    set snap [file join $snapDir $diffChapter]
    if {![file exists $src]} {
        puts stderr "nicht in der Quelle: $diffChapter"
        exit 1
    }
    if {![file exists $snap]} {
        puts "$diffChapter: kein Stand gespeichert, ganzes Kapitel übersetzen."
        exit 0
    }
    set marked ?
    if {[dict exists $sync $diffChapter]} {
        set marked [lindex [dict get $sync $diffChapter] 1]
    }
    set d [lineDiff [readUtf $snap] [readUtf $src]]
    if {$d eq ""} {
        puts "$diffChapter: unverändert seit $marked."
    } else {
        puts "$diffChapter: Änderungen in de seit $marked (- alt, + neu)"
        puts $d
    }
    exit 0
}

# --- status report -------------------------------------------------------------

array set count {aktuell 0 veraltet 0 fehlt 0 unbekannt 0}
foreach ch $srcChapters {
    set src [file join $srcDir $ch]
    if {![file exists $src]} continue
    set inTr [file exists [file join $trDir $ch]]
    if {!$inTr} {
        set state fehlt
        set note "(neu in der Quelle)"
    } elseif {![dict exists $sync $ch]} {
        set state unbekannt
        set note "(übersetzt, aber nie markiert)"
    } else {
        lassign [dict get $sync $ch] crc marked
        if {$crc eq [fingerprint [readUtf $src]]} {
            set state aktuell
            set note ""
        } else {
            set state veraltet
            set changed [clock format [file mtime $src] -format %Y-%m-%d]
            set note "(übersetzt $marked, Quelle geändert $changed)"
        }
    }
    if {$inTr && $ch ni $trChapters} {
        append note " (Datei da, fehlt in book.tcl)"
    }
    incr count($state)
    puts [format "%-36s %-9s %s" $ch $state $note]
}
foreach ch $trChapters {
    if {$ch ni $srcChapters} {
        puts [format "%-36s %-9s %s" $ch entfallen "(nicht mehr in der Quelle)"]
    }
}
puts "---"
puts "aktuell $count(aktuell), veraltet $count(veraltet),\
    fehlt $count(fehlt), unbekannt $count(unbekannt)"
puts "Stand: [file tail $syncFile]"
