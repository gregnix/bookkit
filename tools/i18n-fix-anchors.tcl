#!/usr/bin/env tclsh
# i18n-fix-anchors.tcl -- rewrite internal cross-reference anchors in a
# translated book directory, using an external slug map.
#
# When a heading is translated, its anchor changes (source slug -> target slug).
# Cross-reference links copied from the source still point at the source slug
# and break. This tool rewrites them from a per-book map.
#
# Usage:
#   tclsh i18n-fix-anchors.tcl <bookdir> <anchor-map.tsv> [-n]
#
#   <bookdir>        the TRANSLATION directory, e.g. my-book-en/
#   <anchor-map.tsv> lines "source-slug<TAB>target-slug"; # comments ignored
#   -n               dry run (report changes, write nothing)
#
# Only anchors that appear in the map are touched. Identical slugs (heading not
# translated, code/proper-name headings) need no entry. Rewrites match the
# Markdown link form  ](#slug)  so plain text mentioning a slug is left alone.

set bookdir [lindex $argv 0]
set mapfile [lindex $argv 1]
set dry     [expr {"-n" in $argv}]

if {$bookdir eq "" || $mapfile eq ""} {
    puts stderr "Usage: i18n-fix-anchors.tcl <bookdir> <anchor-map.tsv> \[-n\]"
    exit 1
}
if {![file isdirectory $bookdir]} { puts stderr "kein Verzeichnis: $bookdir"; exit 1 }
if {![file exists $mapfile]}      { puts stderr "keine Map: $mapfile"; exit 1 }

# --- read map ---
set map {}
set fh [open $mapfile r]; fconfigure $fh -encoding utf-8
foreach line [split [read $fh] \n] {
    set line [string trim $line]
    if {$line eq "" || [string index $line 0] eq "#"} continue
    set parts [split $line \t]
    if {[llength $parts] < 2} continue
    set from [string trim [lindex $parts 0]]
    set to   [string trim [lindex $parts 1]]
    if {$from eq "" || $to eq "" || $from eq $to} continue
    lappend map $from $to
}
close $fh
if {[llength $map] == 0} { puts "Map leer -- nichts zu tun."; exit 0 }

# --- rewrite each markdown file ---
set totalFiles 0
set totalHits  0
foreach f [lsort [glob -nocomplain -directory $bookdir *.md]] {
    set fh [open $f r]; fconfigure $fh -encoding utf-8
    set text [read $fh]; close $fh
    set orig $text
    set hits 0
    foreach {from to} $map {
        # match the link target form: ](#from)  -> ](#to)
        set needle "](#$from)"
        set repl   "](#$to)"
        set n [regsub -all -- [string map {\\ \\\\ \[ \\\[ \] \\\] ( \\( ) \\) # \\# . \\. * \\* + \\+ ? \\?} $needle] $text $repl text]
        incr hits $n
    }
    if {$hits > 0} {
        incr totalFiles
        incr totalHits $hits
        if {$dry} {
            puts "  [file tail $f]: $hits Anker (dry-run)"
        } else {
            set out [open $f w]; fconfigure $out -encoding utf-8
            puts -nonewline $out $text; close $out
            puts "  [file tail $f]: $hits Anker umgeschrieben"
        }
    }
}
puts "----"
puts "[expr {$dry ? {dry-run} : {fertig}}]: $totalHits Anker in $totalFiles Dateien."
