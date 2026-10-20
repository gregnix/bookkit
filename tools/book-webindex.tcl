#!/usr/bin/env tclsh
# book-webindex.tcl -- write a web table of contents (index.md) and, if the
# book uses [term]{.index} markers, a subject index (stichwortverzeichnis.md)
# for a bookkit book, so an mdserver-style Markdown server can serve them.
#
# Chapter order and titles come from the book (book.tcl if present, else the
# NNN- numeric prefix order). Only managed blocks are written; prose around
# them is preserved (variant B).
#
#   <bookdir>/index.md                (TOC + link to the subject index)
#     <!-- bookkit:toc:begin -->  ... <!-- bookkit:toc:end -->
#   <bookdir>/stichwortverzeichnis.md (subject index, if any [term]{.index})
#     <!-- bookkit:index:begin --> ... <!-- bookkit:index:end -->
#
# The subject index links each term to chapter.md#idx-N, matching the anchors
# docir assigns to [term]{.index} spans (id="idx-N", 1-based, document order).
#
# Usage:
#   tclsh book-webindex.tcl <bookdir> [--dry-run] [--no-index]

package require Tcl 8.6 9

set TOC_BEGIN "<!-- bookkit:toc:begin -->"
set TOC_END   "<!-- bookkit:toc:end -->"
set IDX_BEGIN "<!-- bookkit:index:begin -->"
set IDX_END   "<!-- bookkit:index:end -->"
set IDX_FILE  "stichwortverzeichnis.md"

# --- CLI ---------------------------------------------------------------------
set bookdir ""; set dryrun 0; set wantIndex 1
foreach a $argv {
    switch -- $a {
        --dry-run  { set dryrun 1 }
        --no-index { set wantIndex 0 }
        --help - -h {
            puts "book-webindex.tcl <bookdir> \[--dry-run] \[--no-index]"
            puts "  Writes <bookdir>/index.md (TOC) and, unless --no-index and"
            puts "  there are \[term]{.index} markers, stichwortverzeichnis.md."
            exit 0
        }
        default {
            if {$bookdir eq ""} { set bookdir $a } else {
                puts stderr "Unexpected argument: $a"; exit 1
            }
        }
    }
}
if {$bookdir eq "" || ![file isdirectory $bookdir]} {
    puts stderr "Usage: tclsh book-webindex.tcl <bookdir> \[--dry-run] \[--no-index]"
    exit 1
}

# --- helpers -----------------------------------------------------------------

proc filePrefix {file} {
    if {[regexp {^(\d+)[-_]} [file tail $file] -> p]} { return $p }
    return ""
}
proc prefixOrdered {bookdir} {
    set withNum {}; set noNum {}
    foreach f [glob -nocomplain -directory $bookdir *.md] {
        set name [file tail $f]
        if {$name in {index.md indexsub.md stichwortverzeichnis.md}} continue
        set p [filePrefix $f]
        if {$p ne ""} { lappend withNum [list [scan $p %d] $name] } else { lappend noNum $name }
    }
    set files {}
    foreach pair [lsort -integer -index 0 $withNum] { lappend files [lindex $pair 1] }
    foreach f [lsort $noNum] { lappend files $f }
    return $files
}

# Read book.tcl (data only, safe interp). {title chapters tocTitle indexTitle}.
proc readManifest {path} {
    set ip [interp create -safe]
    interp eval $ip {set title ""; set chapters {}; set tocTitle ""; set indexTitle ""}
    set fh [open $path r]; fconfigure $fh -encoding utf-8
    set script [read $fh]; close $fh
    if {[catch {interp eval $ip $script} err]} { interp delete $ip; error "book.tcl: $err" }
    set r [list [interp eval $ip {set title}] [interp eval $ip {set chapters}] \
                [interp eval $ip {set tocTitle}] [interp eval $ip {set indexTitle}]]
    interp delete $ip
    return $r
}

# Normalise a heading for plain link text (strip bookkit index spans etc.).
proc cleanTitle {title} {
    regsub -all {\[([^\]]*)\]\{[^\}]*\}} $title {\1} title
    regsub -all {\[([^\]]*)\]\([^)]*\)} $title {\1} title
    regsub -all {\{[^\}]*\}} $title {} title
    return [string trim $title]
}

proc chapterTitle {file} {
    set title [file rootname [file tail $file]]
    if {![catch {open $file r} fh]} {
        fconfigure $fh -encoding utf-8
        while {[gets $fh line] >= 0} {
            if {[regexp {^#\s+(.+)$} $line -> t]} { set title [cleanTitle [string trim $t]]; break }
        }
        close $fh
    }
    return $title
}

proc readFile {file} {
    set fh [open $file r]; fconfigure $fh -encoding utf-8
    set c [read $fh]; close $fh; return $c
}
proc writeFile {file text} {
    set fh [open $file w]; fconfigure $fh -encoding utf-8
    puts -nonewline $fh $text; close $fh
}

# Replace BEGIN..END block in $file with $block, else append. Variant B.
proc updateBlock {file begin end block dryrun {headOnCreate ""}} {
    if {[file exists $file]} {
        set text [readFile $file]; set old $text
        set i [string first $begin $text]
        set j [string first $end $text]
        if {$i >= 0 && $j > $i} {
            set j [expr {$j + [string length $end]}]
            set text "[string range $text 0 [expr {$i-1}]]$block[string range $text $j end]"
        } else {
            append text "\n\n$block\n"
        }
        if {$text eq $old} { return "unchanged" }
        if {!$dryrun} { writeFile $file $text }
        return "updated"
    } else {
        if {!$dryrun} { writeFile $file "$headOnCreate$block\n" }
        return "created"
    }
}

# Collect [term]{.index} markers. Returns dict: term -> list of {chapter idxN}.
# idxN follows docir: every {.index} span counts, 1-based, document order;
# per chapter only the first occurrence of a term is recorded.
proc collectIndex {bookdir chapters} {
    set index [dict create]
    foreach ch $chapters {
        set path [file join $bookdir $ch]
        if {![file exists $path]} continue
        set content [readFile $path]
        set n 0
        array unset seen; array set seen {}
        foreach {full term} [regexp -all -inline \
                {\[([^\]]+)\]\{[^\}]*\.index[^\}]*\}} $content] {
            incr n
            set key [string trim $term]
            if {$key eq "" || [info exists seen($key)]} continue
            set seen($key) 1
            dict lappend index $key [list $ch $n]
        }
    }
    return $index
}

# --- resolve book ------------------------------------------------------------

set bookTitle ""; set tocTitle ""; set indexTitle ""; set chapters {}
set manifest [file join $bookdir book.tcl]
if {[file exists $manifest]} {
    lassign [readManifest $manifest] bookTitle chapters tocTitle indexTitle
}
if {[llength $chapters] == 0} { set chapters [prefixOrdered $bookdir] }
if {$tocTitle   eq ""} { set tocTitle   "Inhaltsverzeichnis" }
if {$indexTitle eq ""} { set indexTitle "Stichwortverzeichnis" }
if {$bookTitle  eq ""} { set bookTitle [file tail [file normalize $bookdir]] }

# --- subject index (optional) ------------------------------------------------

set haveIndex 0
if {$wantIndex} {
    set index [collectIndex $bookdir $chapters]
    if {[dict size $index] > 0} {
        set haveIndex 1
        # group by uppercase first letter (non-letters -> "#")
        set groups [dict create]
        foreach term [lsort -dictionary [dict keys $index]] {
            set c [string toupper [string index $term 0]]
            if {![string is alpha -strict $c]} { set c "#" }
            dict lappend groups $c $term
        }
        set lines {}
        lappend lines $IDX_BEGIN
        foreach g [lsort [dict keys $groups]] {
            lappend lines "## $g\n"
            foreach term [dict get $groups $g] {
                set refs {}
                foreach occ [dict get $index $term] {
                    lassign $occ ch n
                    lappend refs [format {[%s](%s#idx-%d)} \
                        [chapterTitle [file join $bookdir $ch]] $ch $n]
                }
                lappend lines [format {- **%s** -- %s} $term [join $refs ", "]]
            }
            lappend lines ""
        }
        lappend lines $IDX_END
        set idxBlock [join $lines "\n"]
        set idxPath [file join $bookdir $IDX_FILE]
        set st [updateBlock $idxPath $IDX_BEGIN $IDX_END $idxBlock $dryrun \
                    "# $indexTitle\n\n"]
        set prefix [expr {$dryrun ? "(dry-run) " : ""}]
        puts "${prefix}${st}: [file join [file tail [file normalize $bookdir]] $IDX_FILE]  ([dict size $index] Begriffe)"
    }
}

# --- TOC (index.md) ----------------------------------------------------------

set lines {}
lappend lines $TOC_BEGIN
lappend lines "## $tocTitle\n"
foreach ch $chapters {
    set path [file join $bookdir $ch]
    if {![file exists $path]} continue
    lappend lines [format { - [%s](%s)} [chapterTitle $path] $ch]
}
if {$haveIndex} {
    lappend lines ""
    lappend lines [format { - [%s](%s)} $indexTitle $IDX_FILE]
}
lappend lines $TOC_END
set tocBlock [join $lines "\n"]

set idx [file join $bookdir index.md]
set st [updateBlock $idx $TOC_BEGIN $TOC_END $tocBlock $dryrun "# $bookTitle\n\n"]
set prefix [expr {$dryrun ? "(dry-run) " : ""}]
puts "${prefix}${st}: [file join [file tail [file normalize $bookdir]] index.md]"
