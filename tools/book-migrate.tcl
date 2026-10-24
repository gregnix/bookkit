#!/usr/bin/env tclsh
# book-migrate.tcl -- bring existing chapters into the book: links to other
# chapter files become links to the chapter's anchor.
#
#   tclsh bookkit/tools/book-migrate.tcl <bookdir> ?-n?
#
# For every *.md in <bookdir> (except README.md) the anchor is taken from its
# first "# " heading, computed like docir (lower case, every run outside
# a-z0-9 becomes "-"). Then in every chapter
#   ](other.md)        becomes  ](#anchor-of-other)
#   ](other.md#x)      becomes  ](#x)
# Links to files that are not chapters of <bookdir> stay as they are.
#
# book-build.tcl resolves "file.md" and "file.md#x" itself, so for a book
# built only with bookkit this step is optional; it helps when the chapters
# are also read on their own (one HTML page, an editor preview).
#
#   -n   only report what would change
#
# Pure Tcl, 8.6 and 9.x.

package require Tcl 8.6-

set bookdir ""; set dry 0
foreach a $argv {
    switch -- $a {
        -n      { set dry 1 }
        default {
            if {[string match -* $a] || $bookdir ne ""} {
                puts stderr "Usage: book-migrate.tcl <bookdir> ?-n?"
                exit 2
            }
            set bookdir $a
        }
    }
}
if {$bookdir eq "" || ![file isdirectory $bookdir]} {
    puts stderr "Usage: book-migrate.tcl <bookdir> ?-n?"
    exit 2
}

proc readUtf {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set t [read $fh]
    close $fh
    return $t
}

proc slug {text} {
    set id [string tolower $text]
    set id [regsub -all {[^a-z0-9]+} $id "-"]
    set id [string trim $id "-"]
    if {$id eq ""} { set id section }
    return $id
}

# Heading text without inline markup, as docir sees it.
proc plain {text} {
    regsub -all {\[([^\]]*)\]\{[^\}]*\}} $text {\1} text   ;# [x]{.index}
    regsub -all {\[([^\]]*)\]\([^)]*\)} $text {\1} text    ;# [x](url)
    return [string map {` "" * "" _ ""} $text]
}

# First "# " heading outside code fences.
proc firstHeading {text} {
    set fence ""
    foreach line [split $text \n] {
        if {[regexp {^ {0,3}(`{3,}|~{3,})} $line -> f]} {
            if {$fence eq ""} {
                set fence [string index $f 0]
            } elseif {[string index $f 0] eq $fence} {
                set fence ""
            }
            continue
        }
        if {$fence eq "" && [regexp {^#\s+(.+?)\s*#*\s*$} $line -> h]} {
            return $h
        }
    }
    return ""
}

set files [lsort [glob -nocomplain -directory $bookdir *.md]]
set anchor [dict create]
foreach f $files {
    set tail [file tail $f]
    if {$tail eq "README.md"} continue
    set h [firstHeading [readUtf $f]]
    if {$h ne ""} { dict set anchor $tail [slug [plain $h]] }
}

set changed 0
foreach f $files {
    set tail [file tail $f]
    if {$tail eq "README.md"} continue
    set text [readUtf $f]
    set new $text
    dict for {file anc} $anchor {
        set lit [string map {. \\. + \\+ ( \\( ) \\)} $file]
        regsub -all "\\]\\((?:\\./)?${lit}#(\[^)\\s\]+)\\)" $new {](#\1)} new
        regsub -all "\\]\\((?:\\./)?${lit}\\)" $new "\](#$anc)" new
    }
    if {$new eq $text} continue
    incr changed
    if {$dry} {
        puts "would change: $tail"
        continue
    }
    set fh [open $f w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $new
    close $fh
    puts "updated: $tail"
}
puts "[expr {$dry ? {would change} : {changed}}]: $changed file(s)."
