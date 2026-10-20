#!/usr/bin/env tclsh
# index-dedupe.tcl -- thin out duplicate [term]{.index} markers in a book.
#
# Keeps only the FIRST [term]{.index} per term, per chapter file; every later
# occurrence of the same term in the same file loses its {.index} marker but
# keeps its visible text. This is the "one mark per central term per file"
# rule from SPEC.md section 4.
#
# Usage:
#   tclsh index-dedupe.tcl <book-dir> [-n]
#
#   <book-dir>  a bookkit book directory (holds book.tcl and NNN- chapters)
#   -n          dry run: report what would change, write nothing
#
# Chapter selection mirrors book-build.tcl:
#   - if <book-dir>/book.tcl exists, its `chapters` list defines the files;
#   - otherwise every *.md in the directory is processed (README.md and
#     CONTRIBUTING.md are always skipped).
# The build's numeric filename prefixes are irrelevant here.

package require Tcl 8.6-

# ------------------------------------------------------------
# Chapter discovery
# ------------------------------------------------------------

# Read the `chapters` list from book.tcl in a safe interpreter (data, not code).
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

# The chapter files to process, relative to $bookdir.
proc chapterFiles {bookdir} {
    set manifest [file join $bookdir book.tcl]
    if {[file exists $manifest]} {
        return [manifestChapters $manifest]
    }
    set files {}
    foreach f [lsort [glob -nocomplain -directory $bookdir *.md]] {
        set tail [file tail $f]
        if {$tail in {README.md CONTRIBUTING.md}} continue
        lappend files $tail
    }
    return $files
}

# ------------------------------------------------------------
# Dedupe
# ------------------------------------------------------------

# Rewrite one line: drop the {.index} marker on any term already seen in
# this file, keep the term text. Returns {newLine changedCount}.
proc dedupeLine {line seenVar} {
    upvar 1 $seenVar seen
    set changed 0
    set out ""
    set pos 0
    set len [string length $line]
    while {$pos < $len} {
        set start [string first "\[" $line $pos]
        if {$start < 0} {
            append out [string range $line $pos end]
            break
        }
        append out [string range $line $pos [expr {$start - 1}]]
        if {![regexp -start $start {\[([^\]]+)\]\{\.index\}} $line m label]} {
            append out [string index $line $start]
            set pos [expr {$start + 1}]
            continue
        }
        set end [expr {$start + [string length $m]}]
        if {[info exists seen($label)]} {
            append out $label
            incr changed
        } else {
            append out $m
            set seen($label) 1
        }
        set pos $end
    }
    return [list $out $changed]
}

# Dedupe one file; returns the number of markers removed. Writes only when
# something changed and not in dry-run mode.
proc dedupeFile {path dry} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set lines [split [read $fh] \n]
    close $fh
    array set seen {}
    set changed 0
    set out {}
    foreach line $lines {
        lassign [dedupeLine $line seen] line n
        incr changed $n
        lappend out $line
    }
    if {$changed > 0 && !$dry} {
        set fh [open $path w]
        fconfigure $fh -encoding utf-8
        puts -nonewline $fh [join $out \n]
        close $fh
    }
    return $changed
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

set bookdir ""
set dry 0
foreach a $argv {
    switch -- $a {
        -n      { set dry 1 }
        default {
            if {$bookdir eq ""} {
                set bookdir $a
            } else {
                puts stderr "Unbekanntes Argument: $a"
                exit 1
            }
        }
    }
}

if {$bookdir eq "" || ![file isdirectory $bookdir]} {
    puts stderr "Usage: index-dedupe.tcl <book-dir> \[-n\]"
    exit 1
}

set files [chapterFiles $bookdir]
if {[llength $files] == 0} {
    puts stderr "Keine Kapitel-Dateien in $bookdir gefunden."
    exit 1
}

set total 0
set touched 0
foreach f $files {
    set path [file join $bookdir $f]
    if {![file exists $path]} {
        puts stderr "WARNUNG: Kapitel fehlt, uebersprungen: $f"
        continue
    }
    set n [dedupeFile $path $dry]
    if {$n > 0} {
        incr total $n
        incr touched
        puts "  [file tail $f]: $n Duplikat(e)[expr {$dry ? { (dry-run)} : {}}]"
    }
}
puts "----"
puts "[expr {$dry ? {dry-run} : {fertig}}]: $total Duplikat(e) in $touched Datei(en)."
