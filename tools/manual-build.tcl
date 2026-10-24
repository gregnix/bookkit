#!/usr/bin/env tclsh
# manual-build.tcl -- merge a tree of nroff-derived manpage Markdown files
# into ONE Markdown manual (and optionally PDF/HTML).
#
# Unlike book-build.tcl (for hand-written, number-free chapters), this is for
# converted manpages that carry their own NAME/DESCRIPTION sections and YAML
# front matter. Each manpage becomes a chapter titled by its command name
# (the file name); the manpage's own sections are shifted one level down, so
# the result is a clean hierarchy: "# after" / "## NAME" / "## DESCRIPTION".
#
# Usage:
#   tclsh bookkit/tools/manual-build.tcl <dir> [-md out.md] [-pdf out.pdf] [-html out.html]
#                                [-title T] [-index] [-index-label L] [-index-title T]
#                                [-no-cid] [-no-groups] [-lang TAG] [-author A] [-subject S]
#
# PDF fonts: CID mode by default, as in book-build.tcl -- the TTF faces with
# their full Unicode repertoire. Without it only a 256-character subset is
# available; a German manual loses its narrow no-break spaces (U+202F,
# "z. B.") and other characters to "?".
# -no-cid switches back to the subset.
#
# -index: subject index at the end. Its terms come from the YAML "Keywords:"
# of each manpage (TIP 700) plus the command name; they are shown at the end
# of each chapter as "Stichwörter: [after]{.index}, [cancel]{.index}, ..."
# (label: -index-label, index heading: -index-title).
#
# Running header (PDF, needs a docir with running title %c): left the manual title (-title),
# right where the page is -- the man page that starts on it, else the one
# still running -- as the longest of these that fits the line:
#   "< prev  |  struct / graph  |  next >"   path and neighbours
#   "struct / graph"                         path (folders below <dir>,
#                                            without "modules")
#   "< prev  |  graph  |  next >"            neighbours
#   "graph"                                  name
# (with real angle quotes; the current name in bold if docir supports
# "**...**" in the header). -header TEMPLATE sets another docir template
# (%t title, %c that text, %p page, a tab splits left and right),
# -no-header switches it off. An older docir prints %c literally: then
# use -no-header.
#
# -index-tsv FILE (with -pdf and -index): also writes the finished index as
# a table, for tools/index-gesamt.tcl (one combined index over several
# manuals). Header lines "# pdf", "# label", "# title", then one line per
# term: term TAB pages (comma-separated, as printed). -label NAME is the
# manual's name in that combined index (default: -title, else the PDF name).
#
# Parts: with man pages in more than one folder below <dir> each folder is a
# part ("# Tcl", "# Tk", "# Ttk" for the ttk_* pages under tk/; in tcllib one
# per module), the pages one level below ("## after"). -no-groups: flat.
#
# Metadata: -lang TAG (de, en; pdf4tcl 0.9.4.73), -author, -subject.
#
# <dir> is scanned recursively for *.md (e.g. .../manuals/8.6 covers both
# tcl/ and tk/). Files are ordered by path, so tcl/ sorts before tk/.

package require Tcl 8.6-

# ============================================================
# Module discovery (env overrides + sibling search + system install)
# ============================================================

set scriptDir [file dirname [file normalize [info script]]]

set searchBases {}
if {[info exists env(REPOS_DIR)]} { lappend searchBases $env(REPOS_DIR) }
lappend searchBases \
    $scriptDir \
    [file dirname $scriptDir] \
    [file dirname [file dirname $scriptDir]] \
    [file join $env(HOME) code git github] \
    [file join $env(HOME) lib tcltk] \
    /usr/local/lib/tcltk

# A marker path may contain a glob in its final element (e.g.
# {lib pdf4tcllib-*.tm}) so it survives version bumps.
proc _markerHit {dir markerRel} {
    set p [file join $dir {*}$markerRel]
    if {[string match {*[*?]*} [lindex $markerRel end]]} {
        return [expr {[llength [glob -nocomplain -- $p]] > 0}]
    }
    return [file exists $p]
}

proc discover {envVar markerRel} {
    global env searchBases
    if {[info exists env($envVar)] && [_markerHit $env($envVar) $markerRel]} {
        return $env($envVar)
    }
    foreach base $searchBases {
        if {![file isdirectory $base]} continue
        if {[_markerHit $base $markerRel]} { return $base }
        foreach sub [glob -nocomplain -directory $base -type d *] {
            if {[_markerHit $sub $markerRel]} { return $sub }
            foreach sub2 [glob -nocomplain -directory $sub -type d *] {
                if {[_markerHit $sub2 $markerRel]} { return $sub2 }
            }
        }
    }
    return ""
}

proc addTm {dir} {
    if {$dir ne "" && [file isdirectory $dir] && $dir ni [tcl::tm::path list]} {
        catch {tcl::tm::path add $dir}
    }
}

set docirRoot   [discover DOCIR_HOME      {lib tm docir-0.1.1.tm}]
set mdstackRoot [discover MDSTACK_HOME    {lib mdstack-0.1.tm}]
set pdftclRoot  [discover PDF4TCL_HOME    {pdf4tcl.tcl}]
set pdflibRoot  [discover PDF4TCLLIB_HOME {lib pdf4tcllib-*.tm}]

if {$docirRoot   ne ""} { addTm [file join $docirRoot lib tm] }
if {$mdstackRoot ne ""} { addTm [file join $mdstackRoot lib] }
if {$pdflibRoot  ne ""} { addTm [file join $pdflibRoot lib] }
if {$pdftclRoot  ne ""} { lappend auto_path $pdftclRoot }

foreach pkg {mdstack::parser docir::mdSource} {
    if {[catch {package require $pkg} err]} {
        puts stderr "FEHLER: kann $pkg nicht laden: $err"
        puts stderr "  Setze DOCIR_HOME / MDSTACK_HOME (und PDF4TCL_HOME / PDF4TCLLIB_HOME)."
        exit 1
    }
}
package require docir::md

# ============================================================
# Manual assembly
# ============================================================

# Collect *.md recursively, ordered by path (so tcl/ sorts before tk/).
proc collectManpages {dir} {
    set files [lsort [glob -nocomplain -directory $dir *.md]]
    foreach sub [lsort [glob -nocomplain -type d -directory $dir *]] {
        foreach f [collectManpages $sub] { lappend files $f }
    }
    return $files
}

# Code fences after CommonMark: a fence opens with
# at least three ` or ~ (up to three spaces indent; after ` no ` in the info
# string) and closes only with the same character, at least as many, and
# nothing but blanks after it. state: "" outside, else {char length}.
# Returns 1 for a fence line (opening or closing), else 0.
proc fenceStep {stateVar line} {
    upvar 1 $stateVar state
    if {$state eq ""} {
        if {[regexp {^ {0,3}(`{3,}|~{3,})(.*)$} $line -> f info]
                && !([string index $f 0] eq "`" && [string first "`" $info] >= 0)} {
            set state [list [string index $f 0] [string length $f]]
            return 1
        }
        return 0
    }
    lassign $state c len
    if {[regexp {^ {0,3}([`~]+)\s*$} $line -> f]
            && [string index $f 0] eq $c && [string length $f] >= $len
            && [string length [string map [list $c ""] $f]] == 0} {
        set state ""
        return 1
    }
    return 0
}

# One manpage -> a chapter: "# <command>" then the manpage body with its own
# headings shifted down one level (NAME/DESCRIPTION become ##, sub-sections
# ###). The command name is taken from the file name.
#
# The body is taken VERBATIM from the source Markdown (no docir round-trip):
# the round-trip would degrade Pandoc definition lists (": text") into
# 4-space-indented code blocks, which then overflow the page as non-wrapping
# monospace. We only (a) strip the YAML front matter (but keep its Copyright
# lines), and (b) raise ATX heading levels by one, skipping fenced code blocks
# so that "# comment" lines inside examples are left untouched. The copyright
# of each manpage is preserved as a small note at the end of its chapter.
proc manualChapter {file {withIndex 0} {indexLabel ""} {level 1}} {
    set name [file rootname [file tail $file]]
    set keywords {}
    set fh [open $file r]
    fconfigure $fh -encoding utf-8
    set md [read $fh]
    close $fh

    set lines [split $md \n]
    set i 0
    set copyrights {}
    # Strip leading YAML front matter (--- ... ---), but capture Copyright:.
    if {[llength $lines] > 0 && [lindex $lines 0] eq "---"} {
        set inList ""
        for {set i 1} {$i < [llength $lines]} {incr i} {
            set fm [lindex $lines $i]
            if {$fm eq "---"} { incr i; break }
            if {[regexp {^(Copyright|Keywords):} $fm -> key]} { set inList $key; continue }
            if {$inList ne ""} {
                if {[regexp {^ +- +(.+)$} $fm -> cline]} {
                    set cline [string trim [string trim $cline] {"}]
                    if {$inList eq "Copyright"} {
                        lappend copyrights $cline
                    } else {
                        lappend keywords $cline
                    }
                    continue
                } else {
                    set inList ""
                }
            }
        }
    }

    set out "[string repeat # $level] $name\n\n"
    set fence ""
    for {} {$i < [llength $lines]} {incr i} {
        set line [lindex $lines $i]
        # Track fenced code blocks (``` or ~~~); leave their content verbatim.
        if {[fenceStep fence $line]} {
            append out $line "\n"
            continue
        }
        if {$fence eq "" && [regexp {^(#{1,6}) (.*)$} $line -> hashes rest]} {
            set hashes [string repeat # [expr {min(6, [string length $hashes] + $level)}]]
            append out $hashes " " $rest "\n"
        } else {
            append out $line "\n"
        }
    }
    set out [string trimright $out]
    # Index terms: command name + Keywords, visible as one line (docir::pdf
    # collects [term]{.index} spans; the term stays in the text).
    if {$withIndex} {
        set terms [list $name]
        foreach k $keywords {
            if {[string tolower $k] ni [lmap t $terms {string tolower $t}]} { lappend terms $k }
        }
        set spans {}
        foreach t $terms {
            lappend spans "\[[string map {\[ ( \] ) * {} _ {\_}} $t]\]{.index}"
        }
        append out "\n\n*$indexLabel:* [join $spans {, }]"
    }
    # Preserve the manpage's copyright as a small italic note -- only the
    # lines the page does not show itself already (tcllib/tklib pages have a
    # "# Copyright" section with the same text).
    # Compared without markup, blanks and case.
    set flat [string tolower [regsub -all {[^[:alnum:]]+} $out ""]]
    set copyrights [lmap c $copyrights {
        set k [string tolower [regsub -all {[^[:alnum:]]+} $c ""]]
        if {$k ne "" && [string first $k $flat] >= 0} continue
        set c
    }]
    if {[llength $copyrights] > 0} {
        set notes {}
        foreach c $copyrights { lappend notes "*$c*" }
        # " \\" + newline: a hard break straight after the closing "*"
        # ("*a.*\\") is not seen by mdstack 0.8.0 (the "*" after "." is not
        # right-flanking before the break), the lines ran together.
        append out "\n\n" [join $notes " \\\n"]
    }
    return "$out\n\n"
}

# Index table for tools/index-gesamt.tcl. The page numbers are those docir
# printed: docir::pdf::indexEntries; with a docir that lacks it, the render
# state ::docir::pdf::st (indexEntries) of the last run.
proc writeIndexTsv {file pdfOut label title} {
    set byTerm [dict create]
    if {[llength [info commands ::docir::pdf::indexEntries]]} {
        # offizielle Abfrage
        foreach e [docir::pdf::indexEntries] {
            lassign $e term pages
            foreach pg $pages { dict set byTerm $term $pg 1 }
        }
    } elseif {[info exists ::docir::pdf::st] && [dict exists $::docir::pdf::st indexEntries]} {
        # aelteres docir: interner Zustand des letzten Laufs
        foreach e [dict get $::docir::pdf::st indexEntries] {
            lassign $e term page
            dict set byTerm $term $page 1
        }
    } else {
        puts stderr "WARNUNG: kein Index aus docir::pdf, $file nicht geschrieben"
        return
    }
    if {$label eq ""} { set label [expr {$title ne "" ? $title : [file rootname [file tail $pdfOut]]}] }
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts $fh "# pdf\t[file tail $pdfOut]"
    puts $fh "# label\t$label"
    puts $fh "# title\t$title"
    foreach term [lsort -dictionary [dict keys $byTerm]] {
        set pages [lsort -integer [dict keys [dict get $byTerm $term]]]
        puts $fh "[string map {\t { } \n { }} $term]\t[join $pages ,]"
    }
    close $fh
    puts "Index: $file ([dict size $byTerm] Begriffe)"
}

# ============================================================
# CLI
# ============================================================

if {[llength $argv] < 1} {
    puts stderr "Usage: manual-build.tcl <dir> \[-md out.md\] \[-pdf out.pdf\] \[-html out.html\]"
    puts stderr "                         \[-title T\] \[-license file ...\]"
    puts stderr "                         \[-index\] \[-index-label L\] \[-index-title T\] \[-no-cid\]"
    puts stderr "                         \[-index-tsv file\] \[-label NAME\] \[-header T | -no-header\]"
    puts stderr "                         \[-no-groups\] \[-lang TAG\] \[-author A\] \[-subject S\]"
    exit 1
}

set dir [lindex $argv 0]
if {![file isdirectory $dir]} {
    puts stderr "FEHLER: kein Verzeichnis: $dir"
    exit 1
}

set mdOut    ""
set pdfOut   ""
set htmlOut  ""
set title    ""
set licFiles {}
set withIndex  0
set wantCid    1
set indexLabel "Stichw\u00f6rter"
set indexTitle "Stichwortverzeichnis"
set indexTsv   ""
# Kopfzeile, siehe Kopf der Datei ("Running header").
set headerTpl  "%t\t%c"
set label      ""
set groups     1
set lang       ""
set author     ""
set subject    ""
for {set i 1} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        -md      { set mdOut   [lindex $argv [incr i]] }
        -pdf     { set pdfOut  [lindex $argv [incr i]] }
        -html    { set htmlOut [lindex $argv [incr i]] }
        -title   { set title   [lindex $argv [incr i]] }
        -license { lappend licFiles [lindex $argv [incr i]] }
        -index   { set withIndex 1 }
        -index-label { set indexLabel [lindex $argv [incr i]] }
        -index-title { set indexTitle [lindex $argv [incr i]] }
        -no-cid  { set wantCid 0 }
        -index-tsv { set indexTsv [lindex $argv [incr i]] }
        -label   { set label   [lindex $argv [incr i]] }
        -header  { set headerTpl [lindex $argv [incr i]] }
        -no-header { set headerTpl "" }
        -no-groups { set groups 0 }
        -lang    { set lang    [lindex $argv [incr i]] }
        -author  { set author  [lindex $argv [incr i]] }
        -subject { set subject [lindex $argv [incr i]] }
        default  { puts stderr "Unbekannte Option: $a"; exit 1 }
    }
}
if {$mdOut eq "" && $pdfOut eq "" && $htmlOut eq ""} {
    set base [file normalize $dir]
    set mdOut "[file tail $base]-all.md"
}

set files [collectManpages $dir]

# Parts (see top, "Parts"): group = folders below <dir> without "modules";
# ttk_*.md under tk/ form a part "ttk". Files are ordered part by part, in
# the order the parts first appear. Only with two parts or more.
proc partOf {file dir} {
    set rel [file split [string range [file dirname [file normalize $file]] \
        [string length [file normalize $dir]] end]]
    set path [lsearch -all -inline -not -regexp $rel {^(/|modules)$}]
    set p [join $path " / "]
    if {$p eq "tk" && [string match ttk_* [file tail $file]]} { set p ttk }
    return $p
}
proc partTitle {p} {
    if {[dict exists {tcl Tcl tk Tk ttk Ttk} $p]} { return [dict get {tcl Tcl tk Tk ttk Ttk} $p] }
    return $p
}
set partOrder {}
set fileParts [dict create]
foreach f $files {
    set p [partOf $f $dir]
    dict lappend fileParts $p $f
    if {$p ni $partOrder} { lappend partOrder $p }
}
if {!$groups || [llength $partOrder] < 2} {
    set groups 0
} else {
    set files {}
    foreach p $partOrder { lappend files {*}[dict get $fileParts $p] }
}

# Running header texts per chapter (see top): name -> candidates, longest
# first; docir takes the first that fits.
set runInfo [dict create]
set dirN [file normalize $dir]
set names [lmap f $files {file rootname [file tail $f]}]
for {set k 0} {$k < [llength $files]} {incr k} {
    set name [lindex $names $k]
    set path [expr {[partOf [lindex $files $k] $dir] eq "" ? {} : [split [partOf [lindex $files $k] $dir] /]}]
    set path [lmap x $path {string trim $x}]
    set prev [expr {$k > 0 ? [lindex $names [expr {$k-1}]] : ""}]
    set next [expr {$k < [llength $names]-1 ? [lindex $names [expr {$k+1}]] : ""}]
    # \x02 around the current name: bold in the header (docir "**...**"),
    # see runningText
    set cur "\x02$name\x02"
    set pfad [join [concat $path [list $cur]] " / "]
    set nach $cur
    if {$prev ne ""} { set nach "\u2039 $prev  |  $nach" }
    if {$next ne ""} { set nach "$nach  |  $next \u203a" }
    set beide $pfad
    if {$prev ne ""} { set beide "\u2039 $prev  |  $beide" }
    if {$next ne ""} { set beide "$beide  |  $next \u203a" }
    if {![dict exists $runInfo $name]} {
        set c {}
        foreach x [list $beide $pfad $nach $cur] { if {$x ni $c} { lappend c $x } }
        dict set runInfo $name [lsort -command {apply {{a b} {
            expr {[string length $b] - [string length $a]}}}} $c]
    }
}
proc runningText {title level} {
    global runInfo
    if {![dict exists $runInfo $title]} { return [list $title] }
    # a docir with _hdrSegs sets "**...**" in the header bold; without it
    # the asterisks would be printed, so then without
    set mark [expr {[llength [info commands ::docir::pdf::_hdrSegs]] ? "**" : ""}]
    return [lmap c [dict get $runInfo $title] {string map [list \x02 $mark] $c}]
}
if {[llength $files] == 0} {
    puts stderr "FEHLER: keine .md gefunden unter $dir"
    exit 1
}
puts "Manual: [llength $files] Manpages aus $dir"

# Assemble merged Markdown.
set manual ""
set lastPart ""
foreach f $files {
    if {$groups} {
        set p [partOf $f $dir]
        if {$p ne $lastPart} { append manual "# [partTitle $p]\n\n"; set lastPart $p }
        append manual [manualChapter $f $withIndex $indexLabel 2]
    } else {
        append manual [manualChapter $f $withIndex $indexLabel]
    }
}
set manual [string trimright $manual]\n

# Optional license appendix. One or more -license files are appended as a
# final "# License" chapter so they travel with the merged manual. With a
# single file the text follows the heading directly; with several files each
# gets a "## <name>" sub-section (name = file stem, e.g. tcl, tk) so they are
# told apart.
if {[llength $licFiles] > 0} {
    foreach lf $licFiles {
        if {![file exists $lf]} {
            puts stderr "FEHLER: Lizenzdatei nicht gefunden: $lf"
            exit 1
        }
    }
    append manual "\n# License\n\n"
    set multi [expr {[llength $licFiles] > 1}]
    foreach lf $licFiles {
        set fh [open $lf r]
        fconfigure $fh -encoding utf-8
        set lic [read $fh]
        close $fh
        if {$multi} {
            append manual "## [file rootname [file tail $lf]]\n\n"
        }
        append manual "```\n[string trim $lic]\n```\n\n"
    }
    set manual [string trimright $manual]\n
}

# Direct Markdown output: write the assembled manual as-is.
if {$mdOut ne ""} {
    set fh [open $mdOut w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $manual
    close $fh
    puts "MD:   $mdOut ([file size $mdOut] Bytes)"
}

# For PDF/HTML, re-parse the merged Markdown so command chapters become real
# headings, optionally number them, then render through the docir sinks.
if {$pdfOut ne "" || $htmlOut ne ""} {
    set ir [docir::md::fromAst [mdstack::parser::parse $manual]]
    if {$pdfOut ne ""} {
        package require docir::pdf
        if {[string first %c $headerTpl] >= 0 && \
                ![llength [info commands ::docir::pdf::_runningTitle]]} {
            puts stderr "HINWEIS: docir ohne Kolumnentitel (%c), Kopfzeile weggelassen"
            set headerTpl ""
        }
        set lvl [expr {$groups ? 2 : 1}]
        set pdfOpts [dict create \
            title $title paper a4 footer "%p" header $headerTpl \
            runningLevel $lvl runningProc runningText \
            generateToc 1 tocTitle "Contents" tocDepth $lvl \
            generateIndex $withIndex indexTitle $indexTitle \
            cid $wantCid lang $lang author $author subject $subject \
            creator "bookkit manual-build.tcl"]
        docir::pdf::render $ir $pdfOut $pdfOpts
        puts "PDF:  $pdfOut ([file size $pdfOut] Bytes)"
        if {$indexTsv ne ""} { writeIndexTsv $indexTsv $pdfOut $label $title }
    }
    if {$htmlOut ne ""} {
        package require docir::html
        set html [docir::html::render $ir [dict create \
            title $title includeToc 1 includeIndex $withIndex indexTitle $indexTitle]]
        set fh [open $htmlOut w]
        fconfigure $fh -encoding utf-8
        puts -nonewline $fh $html
        close $fh
        puts "HTML: $htmlOut ([file size $htmlOut] Bytes)"
    }
}
