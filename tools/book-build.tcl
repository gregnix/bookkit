#!/usr/bin/env tclsh
# book-build.tcl -- Build a docir/mdstack book to PDF and/or HTML, with
# hierarchical auto-numbering, a table of contents and a subject index.
#
# Usage:
#   book-build.tcl <bookdir> [-pdf out.pdf] [-html out.html]
#                            [-number] [-no-toc] [-no-index] [-no-cid]
#                            [-title T] [-author A] [-depth N]
#   book-build.tcl manifest <bookdir>     # write book.tcl from NNN- prefixes
#
# If neither -pdf nor -html is given, both are produced next to <bookdir>
# (<bookname>.pdf / <bookname>.html).
#
# Chapter order
#   - If <bookdir>/book.tcl exists it defines the order: it sets a Tcl
#     variable `chapters` (list of .md files relative to <bookdir>);
#     `title` and `author` are optional. The numeric filename prefix is
#     ignored in this mode.
#   - Otherwise files are taken from <bookdir>/*.md, ordered by a numeric
#     filename prefix (e.g. 010-intro.md). The prefix is only used for
#     ordering and never appears in the output. Files without a numeric
#     prefix follow, sorted alphabetically.
#
# Numbering (-number)
#   Source headings carry no numbers (#, ##, ###). With -number the build
#   assigns 1 / 1.1 / 1.1.1 from nesting + order (down to -depth, default 3).
#   Numbers are added on the IR, so they appear consistently in body, TOC,
#   bookmarks and both output formats. Heading anchors stay title-based, so
#   reordering changes numbers but not cross-reference targets.
#
# Fonts (PDF)
#   CID mode by default: the TTF faces with their full Unicode repertoire
#   (⌘ ⌥ → ∂, Greek, box drawing). Without it only a 256-character subset
#   is available and everything else becomes "?" -- measured 2026-10-19 on
#   the macOS book: all 49 ⌥ and 62 ⌘ lost. Costs about 20-40 % file size.
#   -no-cid switches back to the subset.
#
# Index
#   Index terms are marked in Markdown as bracketed spans: [Term]{.index}
#   The term stays visible in the text and is collected into the index
#   (PDF: pages; HTML: links to the sections, labelled by section title).

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
# {lib pdf4tcllib-*.tm}) so it survives version bumps. Match exact
# paths with [file exists] and glob patterns with [glob].
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

# ============================================================
# Helpers
# ============================================================

# Hierarchical auto-numbering on the IR: prepend "1.2.3  " to heading text,
# resetting deeper counters when a higher level appears. Down to maxLevel.
proc numberHeadings {ir maxLevel} {
    set counters {0 0 0 0 0 0}
    set out {}
    foreach node $ir {
        if {[dict get $node type] eq "heading"} {
            set m [dict get $node meta]
            set lv [expr {[dict exists $m level] ? [dict get $m level] : 1}]
            if {$lv >= 1 && $lv <= $maxLevel} {
                lset counters [expr {$lv - 1}] [expr {[lindex $counters [expr {$lv - 1}]] + 1}]
                for {set i $lv} {$i < 6} {incr i} { lset counters $i 0 }
                set num [join [lrange $counters 0 [expr {$lv - 1}]] .]
                set content [dict get $node content]
                # Normalize single-inline (flat dict) to a list of inlines.
                if {[lindex $content 0] eq "type"} { set content [list $content] }
                set content [linsert $content 0 [dict create type text text "$num  "]]
                dict set node content $content
            }
        }
        lappend out $node
    }
    return $out
}

# ------------------------------------------------------------
# Internal links
#
# Chapters link to each other as files: [Kapitel 3](030-x.md) or
# [Abschnitt](030-x.md#id). In the built book the files are one document,
# so such a link must become "#<id>": the id of the chapter's first heading,
# or the given id. "#id" links are checked against the heading ids as well;
# a spelling with ae/oe/ue/ss for an umlaut also resolves, since the parser
# drops umlauts from ids ("müssen" -> "m-ssen"). PDF turns "#id" into a jump
# inside the document, HTML into an anchor. Unresolved links are left as
# they are and reported.
# ------------------------------------------------------------

proc slugId {text} {
    set id [string tolower $text]
    set id [regsub -all {[^a-z0-9]+} $id "-"]
    return [string trim $id "-"]
}

proc headingText {node} {
    set c [dict get $node content]
    if {[lindex $c 0] eq "type"} { set c [list $c] }
    set t ""
    foreach i $c { if {[dict exists $i text]} { append t [dict get $i text] } }
    return $t
}

# Collect ids per file: returns {firstIdByFile aliasToId}.
proc collectIds {bookdir files} {
    set first {}
    set alias {}
    foreach f $files {
        set path [file join $bookdir $f]
        if {![file exists $path]} continue
        set fh [open $path r]
        fconfigure $fh -encoding utf-8
        set ir [docir::md::fromAst [mdstack::parser::parse [read $fh]]]
        close $fh
        foreach n $ir {
            if {[dict get $n type] ne "heading"} continue
            set m [dict get $n meta]
            if {![dict exists $m id] || [dict get $m id] eq ""} continue
            set id [dict get $m id]
            if {![dict exists $first $f]} { dict set first $f $id }
            if {![dict exists $alias $id]} { dict set alias $id $id }
            set tr [slugId [string map {ä ae ö oe ü ue ß ss Ä ae Ö oe Ü ue} \
                [headingText $n]]]
            if {$tr ne "" && ![dict exists $alias $tr]} { dict set alias $tr $id }
        }
    }
    return [list $first $alias]
}

proc resolveHref {href first alias} {
    if {[regexp {^#(.+)$} $href -> a]} {
        foreach c [list $a [slugId $a]] {
            if {[dict exists $alias $c]} { return "#[dict get $alias $c]" }
        }
        return ""
    }
    if {[regexp {^([^/:#]+\.md)(?:#(.*))?$} $href -> file a]} {
        if {![dict exists $first $file]} { return "" }
        if {$a eq ""} { return "#[dict get $first $file]" }
        return [resolveHref "#$a" $first $alias]
    }
    return $href
}

proc rewriteLinks {node first alias} {
    if {[catch {dict exists $node type} isNode] || !$isNode} { return $node }
    if {[dict get $node type] eq "link" && [dict exists $node href]} {
        set h [dict get $node href]
        set r [resolveHref $h $first $alias]
        if {$r eq ""} {
            global unresolved
            lappend unresolved $h
        } else {
            dict set node href $r
        }
    }
    # Definition lists keep the term as inlines in meta.
    if {[dict exists $node meta] && ![catch {dict exists [dict get $node meta] term} t] && $t} {
        set m [dict get $node meta]
        set terms {}
        set ok 1
        foreach ch [dict get $m term] {
            if {[catch {dict exists $ch type} isN] || !$isN} { set ok 0; break }
            lappend terms [rewriteLinks $ch $first $alias]
        }
        if {$ok} { dict set m term $terms; dict set node meta $m }
    }
    if {[dict exists $node content]} {
        set c [dict get $node content]
        if {[catch {llength $c}] || [llength $c] == 0} { return $node }
        if {[lindex $c 0] eq "type"} {
            dict set node content [rewriteLinks $c $first $alias]
        } else {
            set out {}
            foreach ch $c {
                if {[catch {dict exists $ch type} ok] || !$ok} { return $node }
                lappend out [rewriteLinks $ch $first $alias]
            }
            dict set node content $out
        }
    }
    return $node
}

# ------------------------------------------------------------
# Images
#
# Image nodes reach the IR as block images ({type image meta {url alt}})
# and as inline images ({type image url ... text ...}), including inside
# tables and lists. Two things have to happen for them to work:
#
#   PDF  -- docir::pdf resolves relative image URLs against its "root"
#           option; we hand it the book directory.
#   HTML -- the <img src="..."> stays relative, so the referenced files
#           must exist relative to the HTML output file. We copy them,
#           preserving the relative path.
# ------------------------------------------------------------

# A value that could be a dict (even length, non-empty).
proc maybeDict {v} {
    if {[catch {llength $v} n]} { return 0 }
    return [expr {$n > 0 && $n % 2 == 0}]
}

# All image URLs in an IR node list, blocks and inlines, recursively.
proc imageUrls {nodes} {
    set out {}
    foreach node $nodes {
        if {![maybeDict $node]} { continue }
        if {[catch {dict exists $node type} ok] || !$ok} { continue }
        if {[dict get $node type] eq "image"} {
            # block image: meta.url -- inline image: url
            if {[dict exists $node meta] && [maybeDict [dict get $node meta]] \
                    && [dict exists [dict get $node meta] url]} {
                lappend out [dict get [dict get $node meta] url]
            } elseif {[dict exists $node url]} {
                lappend out [dict get $node url]
            }
        }
        if {[dict exists $node content]} {
            set c [dict get $node content]
            # normalize a single flat inline dict to a list of nodes
            if {[maybeDict $c] && [lindex $c 0] eq "type"} { set c [list $c] }
            if {[catch {imageUrls $c} sub] == 0} { lappend out {*}$sub }
        }
    }
    return $out
}

# Copy every locally referenced image from the book directory to the
# output directory, preserving the relative path. Returns the number of
# files copied; missing files are reported and skipped.
proc copyImages {ir bookdir outdir} {
    set copied 0
    set missing {}
    foreach url [lsort -unique [imageUrls $ir]] {
        if {[string match "http://*" $url] || [string match "https://*" $url]} { continue }
        if {[string match "data:*" $url]} { continue }
        if {[file pathtype $url] ne "relative"} { continue }
        set src [file join $bookdir $url]
        if {![file exists $src]} { lappend missing $url ; continue }
        set dst [file join $outdir $url]
        if {[file normalize $src] eq [file normalize $dst]} { continue }
        file mkdir [file dirname $dst]
        file copy -force $src $dst
        incr copied
    }
    foreach m $missing {
        puts stderr "WARNUNG: Bild nicht gefunden: [file join $bookdir $m]"
    }
    return $copied
}

# Numeric filename prefix (leading digits), or "" if none.
proc filePrefix {name} {
    if {[regexp {^([0-9]+)} [file tail $name] -> n]} { return $n }
    return ""
}

# Files ordered by numeric prefix; unprefixed files alphabetically after.
proc prefixOrdered {bookdir} {
    set withNum {}
    set noNum {}
    foreach f [glob -nocomplain -directory $bookdir *.md] {
        set p [filePrefix $f]
        if {$p ne ""} {
            lappend withNum [list [scan $p %d] [file tail $f]]
        } else {
            lappend noNum [file tail $f]
        }
    }
    set files {}
    foreach pair [lsort -integer -index 0 $withNum] { lappend files [lindex $pair 1] }
    foreach f [lsort $noNum] { lappend files $f }
    return $files
}

# Read book.tcl in a child interpreter; return {title author chapters}.
proc readManifest {manifestPath} {
    set ip [interp create -safe]
    # Allow only plain variable assignment; book.tcl is data, not code.
    interp eval $ip {set title ""; set author ""; set chapters {}
                     set tocTitle ""; set indexTitle ""
                     set subtitle ""; set date ""; set titlePage 0}
    set fh [open $manifestPath r]
    fconfigure $fh -encoding utf-8
    set script [read $fh]
    close $fh
    if {[catch {interp eval $ip $script} err]} {
        interp delete $ip
        error "book.tcl: $err"
    }
    set title      [interp eval $ip {set title}]
    set author     [interp eval $ip {set author}]
    set chapters   [interp eval $ip {set chapters}]
    set tocTitle   [interp eval $ip {set tocTitle}]
    set indexTitle [interp eval $ip {set indexTitle}]
    set subtitle   [interp eval $ip {set subtitle}]
    set date       [interp eval $ip {set date}]
    set titlePage  [interp eval $ip {set titlePage}]
    interp delete $ip
    return [list $title $author $chapters $tocTitle $indexTitle \
                 $subtitle $date $titlePage]
}

# Resolve order + metadata for a book directory.
# Returns {title author files tocTitle indexTitle subtitle date titlePage}.
proc resolveBook {bookdir} {
    set manifest [file join $bookdir book.tcl]
    if {[file exists $manifest]} {
        lassign [readManifest $manifest] \
            title author chapters tocTitle indexTitle subtitle date titlePage
        return [list $title $author $chapters $tocTitle $indexTitle \
                     $subtitle $date $titlePage]
    }
    return [list "" "" [prefixOrdered $bookdir] "" "" "" "" 0]
}

# Generate book.tcl from the prefix order so it can be hand-reordered later.
proc writeManifestFile {bookdir} {
    set files [prefixOrdered $bookdir]
    if {[llength $files] == 0} {
        puts stderr "FEHLER: keine .md-Dateien in $bookdir"
        exit 1
    }
    set out [file join $bookdir book.tcl]
    set fh [open $out w]
    fconfigure $fh -encoding utf-8
    puts $fh "# book.tcl -- chapter order for this book."
    puts $fh "# Generated from filename prefixes; reorder lines freely."
    puts $fh "# Prefixes are ignored once this file exists."
    puts $fh ""
    puts $fh "set title  \"\""
    puts $fh "set author \"\""
    puts $fh ""
    puts $fh "set chapters \{"
    foreach f $files { puts $fh "    $f" }
    puts $fh "\}"
    close $fh
    puts "geschrieben: $out ([llength $files] Kapitel)"
}

# ============================================================
# Argument parsing
# ============================================================

if {[llength $argv] >= 2 && [lindex $argv 0] eq "manifest"} {
    writeManifestFile [lindex $argv 1]
    exit 0
}

if {[llength $argv] < 1} {
    puts stderr "Usage: book-build.tcl <bookdir> \[-pdf out.pdf\] \[-html out.html\] \[-md out.md\]"
    puts stderr "                       \[-number\] \[-no-toc\] \[-no-index\] \[-no-cid\] \[-title T\] \[-author A\] \[-depth N\]"
    puts stderr "                       \[-toc-title T\] \[-index-title T\]"
    puts stderr "                       \[-title-page\] \[-subtitle T\] \[-date T\]"
    puts stderr "       book-build.tcl manifest <bookdir>"
    exit 1
}

set bookdir [lindex $argv 0]
if {![file isdirectory $bookdir]} {
    puts stderr "FEHLER: kein Verzeichnis: $bookdir"
    exit 1
}

set pdfOut    ""
set htmlOut   ""
set mdOut     ""
set doNumber  0
set wantToc   1
set wantCid   1
set wantIndex 1
set optTitle  ""
set optAuthor ""
set optTocTitle   ""
set optIndexTitle ""
set optSubtitle   ""
set optDate       ""
set optTitlePage  0
set depth     3

for {set i 1} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        -pdf      { set pdfOut    [lindex $argv [incr i]] }
        -html     { set htmlOut   [lindex $argv [incr i]] }
        -md       { set mdOut     [lindex $argv [incr i]] }
        -number   { set doNumber  1 }
        -no-toc   { set wantToc   0 }
        -no-cid   { set wantCid   0 }
        -no-index { set wantIndex 0 }
        -title    { set optTitle  [lindex $argv [incr i]] }
        -author   { set optAuthor [lindex $argv [incr i]] }
        -toc-title   { set optTocTitle   [lindex $argv [incr i]] }
        -index-title { set optIndexTitle [lindex $argv [incr i]] }
        -subtitle    { set optSubtitle   [lindex $argv [incr i]] }
        -date        { set optDate       [lindex $argv [incr i]] }
        -title-page  { set optTitlePage  1 }
        -depth    { set depth     [lindex $argv [incr i]] }
        default   { puts stderr "Unbekannte Option: $a"; exit 1 }
    }
}

# Default outputs if none requested.
if {$pdfOut eq "" && $htmlOut eq "" && $mdOut eq ""} {
    set base [file join [file dirname [file normalize $bookdir]] [file tail [file normalize $bookdir]]]
    set pdfOut  "$base.pdf"
    set htmlOut "$base.html"
}

# ============================================================
# Assemble + parse + (number) + render
# ============================================================

lassign [resolveBook $bookdir] mTitle mAuthor files mTocTitle mIndexTitle \
    mSubtitle mDate mTitlePage
if {[llength $files] == 0} {
    puts stderr "FEHLER: keine Kapitel gefunden in $bookdir"
    exit 1
}

set title  [expr {$optTitle  ne "" ? $optTitle  : $mTitle}]
set author [expr {$optAuthor ne "" ? $optAuthor : $mAuthor}]
# Toc/index titles: command-line switch > manifest > German default.
set tocTitle [expr {$optTocTitle ne "" ? $optTocTitle \
    : ($mTocTitle ne "" ? $mTocTitle : "Inhaltsverzeichnis")}]
set indexTitle [expr {$optIndexTitle ne "" ? $optIndexTitle \
    : ($mIndexTitle ne "" ? $mIndexTitle : "Stichwortverzeichnis")}]
# Title page: switch or manifest enables it; subtitle/date switch > manifest.
set subtitle  [expr {$optSubtitle ne "" ? $optSubtitle : $mSubtitle}]
set date      [expr {$optDate     ne "" ? $optDate     : $mDate}]
set titlePage [expr {$optTitlePage || ($mTitlePage ne "" && $mTitlePage)}]

puts "Buch: [llength $files] Kapitel aus $bookdir"

set md ""
foreach f $files {
    set path [file join $bookdir $f]
    if {![file exists $path]} {
        puts stderr "WARNUNG: Kapitel fehlt, uebersprungen: $f"
        continue
    }
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    append md [read $fh] "\n\n"
    close $fh
}

set ast [mdstack::parser::parse $md]
set ir  [docir::md::fromAst $ast]

lassign [collectIds $bookdir $files] firstIds idAlias
set unresolved {}
set ir [lmap node $ir { rewriteLinks $node $firstIds $idAlias }]
if {[llength $unresolved]} {
    puts stderr "WARNUNG: [llength $unresolved] Verweis(e) ohne Ziel:\
        [join [lrange [lsort -unique $unresolved] 0 9] {, }]"
}
if {$doNumber} { set ir [numberHeadings $ir $depth] }

if {$pdfOut ne ""} {
    package require docir::pdf
    docir::pdf::render $ir $pdfOut [dict create \
        title         $title \
        author        $author \
        subtitle      $subtitle \
        date          $date \
        titlePage     $titlePage \
        paper         a4 \
        footer        "%p" \
        root          [file normalize $bookdir] \
        generateToc   $wantToc \
        tocTitle      $tocTitle \
        tocDepth      $depth \
        generateIndex $wantIndex \
        indexTitle    $indexTitle \
        cid           $wantCid]
    puts "PDF:  $pdfOut ([file size $pdfOut] Bytes)"
}

if {$htmlOut ne ""} {
    package require docir::html
    set html [docir::html::render $ir [dict create \
        title        $title \
        includeToc   $wantToc \
        includeIndex $wantIndex \
        indexTitle   $indexTitle]]
    set fh [open $htmlOut w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $html
    close $fh
    puts "HTML: $htmlOut ([file size $htmlOut] Bytes)"

    # <img src="..."> is relative to the HTML file: bring the images along.
    set n [copyImages $ir $bookdir [file dirname [file normalize $htmlOut]]]
    if {$n > 0} { puts "Bilder: $n kopiert" }
}

if {$mdOut ne ""} {
    # Single merged Markdown file: all chapters in reading order, with the
    # same chapter numbering as PDF/HTML when -number is used. headingShift 0
    # keeps the original heading levels (# chapter, ## section). Index markers
    # [term]{.index} survive the round-trip.
    package require docir::md
    set mdText [docir::md::render $ir [dict create headingShift 0]]
    set fh [open $mdOut w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $mdText
    close $fh
    puts "MD:   $mdOut ([file size $mdOut] Bytes)"
}
