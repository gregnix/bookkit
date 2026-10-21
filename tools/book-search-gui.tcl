#!/usr/bin/env wish
# book-search-gui.tcl -- Tk front end for book-search.tcl
#
# Searches the database built by book-search.tcl (bibliothek-suche.db) while
# you type. Left: hits (subject index terms first, then sections, best
# first); right: the whole section with the search words marked. Opens the
# hit in the built HTML at its anchor, or the chapter file.
#
#   wish bookkit/tools/book-search-gui.tcl ?-db file? ?-root dir? ?words ...?
#   tclsh bookkit/tools/book-search-gui.tcl ...          (loads Tk itself)
#
# Without -db the database is <root>/bibliothek-suche.db, root being the
# directory above bookkit/ (as for book-search.tcl). "Index neu" runs
# "book-search.tcl index" in a second process; the window stays usable.
#
# Keys: Return search now, Ctrl+F or Escape to the search field, Up/Down in
# the list, Return or double-click in the list opens the HTML, Ctrl+E opens
# the chapter file, Ctrl+C in the list copies "file:line".
#
# Needs Tcl/Tk 8.6 or 9 and the sqlite3 package with FTS5. Only ttk widgets,
# no other packages.

package require Tcl 8.6-
package require Tk
package require sqlite3

set ::bsgDir [file dirname [file join [pwd] [info script]]]
if {[file tail $::bsgDir] eq "."} { set ::bsgDir [file dirname $::bsgDir] }
# book-search.tcl as a library: its command line part runs only when it is
# the main script.
source -encoding utf-8 [file join $::bsgDir book-search.tcl]

namespace eval ::bsg {
    variable db ""
    variable dbFile ""
    variable root ""
    variable query ""
    variable mode word
    variable book "alle Bücher"
    variable limit 50
    variable after ""
    variable hits         ;# tree item -> dict
    array set hits {}
    variable words {}
    variable indexPipe ""
    variable status ""
}

# ------------------------------------------------------------------
# database
# ------------------------------------------------------------------

proc ::bsg::openDb {} {
    variable db; variable dbFile; variable root
    if {$db ne ""} { catch {$db close}; set db "" }
    if {![file exists $dbFile]} {
        setStatus "Kein Index: $dbFile -- \"Index neu\" baut ihn."
        return 0
    }
    sqlite3 ::bsg::sql $dbFile -readonly 1
    set db ::bsg::sql
    set r [$db onecolumn {SELECT value FROM meta WHERE key = 'root'}]
    if {$root eq "" && $r ne "" && [file isdirectory $r]} { set root $r }
    if {$root eq ""} { set root [file dirname $dbFile] }
    fillBooks
    indexStatus
    return 1
}

proc ::bsg::fillBooks {} {
    variable db
    set l [list "alle Bücher"]
    $db eval {SELECT DISTINCT book FROM books ORDER BY book} { lappend l $book }
    .top.book configure -values $l
}

proc ::bsg::indexStatus {} {
    variable db
    set built [$db onecolumn {SELECT value FROM meta WHERE key = 'built'}]
    set nb [$db onecolumn {SELECT count(*) FROM books}]
    set ns [$db onecolumn {SELECT count(*) FROM sections}]
    setStatus "Index vom $built: $nb Buchverzeichnisse, $ns Abschnitte"
}

proc ::bsg::setStatus {s} {
    variable status
    set status $s
}

# ------------------------------------------------------------------
# search
# ------------------------------------------------------------------

# Words of the query. In FTS5 mode the whole line is one expression.
proc ::bsg::queryWords {} {
    variable query; variable mode
    set q [string trim $query]
    if {$q eq ""} { return {} }
    if {$mode eq "raw"} { return [list $q] }
    # "a phrase" stays together, otherwise split at blanks
    set out {}
    foreach {- ph w} [regexp -all -inline {"([^"]*)"|(\S+)} $q] {
        if {$ph ne ""} { lappend out $ph } elseif {$w ne ""} { lappend out $w }
    }
    return $out
}

proc ::bsg::schedule {} {
    variable after
    after cancel $after
    set after [after 250 ::bsg::run]
}

proc ::bsg::run {} {
    variable db; variable mode; variable book; variable limit
    variable hits; variable words
    after cancel $::bsg::after
    if {$db eq ""} { return }
    set words [queryWords]
    .main.list.tree delete [.main.list.tree children {}]
    array unset hits
    clearPreview
    if {[llength $words] == 0 || [string length [join $words ""]] < 2} {
        indexStatus
        return
    }
    set books [expr {$book eq "alle Bücher" ? {} : [list $book]}]
    set t0 [clock milliseconds]
    if {[catch {::bs::search $db $words -mode $mode -books $books -limit $limit} r]} {
        setStatus "Fehler: $r"
        return
    }
    set ms [expr {[clock milliseconds] - $t0}]
    set tree .main.list.tree
    set terms [dict get $r terms]
    set secs  [dict get $r sections]
    if {[llength $terms]} {
        set p [$tree insert {} end -text "Stichwörter ([llength $terms])" \
            -open 1 -tags group]
        foreach t $terms {
            # dict get, not dict with: "book" is also the namespace variable
            # of the book combobox
            set where [expr {[dict get $t kind] eq "glossar" ? "Glossar"
                             : "[dict get $t chapter]:[dict get $t line]"}]
            set id [$tree insert $p end -text [dict get $t book] \
                -values [list [labelText [dict get $t label]] [dict get $t term] $where] \
                -tags term]
            set hits($id) [dict merge $t {type term}]
        }
    }
    set p [$tree insert {} end -text "Abschnitte ([llength $secs])" -open 1 -tags group]
    foreach s $secs {
        set id [$tree insert $p end -text [dict get $s book] \
            -values [list [labelText [dict get $s label]] [dict get $s heading] \
                         "[dict get $s chapter]:[dict get $s line]"] \
            -tags section]
        set hits($id) [dict merge $s {type section}]
    }
    set n [llength $secs]
    set more [expr {$n >= $limit ? " (Grenze $limit erreicht)" : ""}]
    set note [dict get $r note]
    setStatus "[llength $terms] Stichwörter, $n Abschnitte$more, $ms ms[expr {$note ne "" ? " -- $note" : ""}]"
    # select the first real hit
    foreach g [$tree children {}] {
        set c [lindex [$tree children $g] 0]
        if {$c ne ""} { $tree selection set $c; $tree see $c; break }
    }
}

proc ::bsg::labelText {label} {
    if {$label eq ""} { return "" }
    if {[string is integer -strict $label]} { return "Kap. $label" }
    if {[string match S.* $label]} { return $label }   ;# PDF page
    return "Anh. $label"
}

# ------------------------------------------------------------------
# preview
# ------------------------------------------------------------------

proc ::bsg::clearPreview {} {
    set t .main.prev.text
    $t configure -state normal
    $t delete 1.0 end
    $t configure -state disabled
    .main.prev.head configure -text ""
}

proc ::bsg::current {} {
    variable hits
    set sel [lindex [.main.list.tree selection] 0]
    if {$sel eq "" || ![info exists hits($sel)]} { return "" }
    return $hits($sel)
}

# Section id of a hit. A glossary term has none of its own: take the entry
# in the book's glossary appendix (8xx-...glossar...md), if there is one.
proc ::bsg::sectionOf {h} {
    variable db
    if {[dict get $h type] eq "section"} { return [dict get $h id] }
    if {[dict get $h section] ne ""} { return [dict get $h section] }
    set book [dict get $h book]; set lang [dict get $h lang]
    set like "%[dict get $h term]%"
    return [$db onecolumn {
        SELECT id FROM sections WHERE book = :book AND lang = :lang
          AND chapter GLOB '8*glossar*' AND body LIKE :like
        ORDER BY id LIMIT 1}]
}

proc ::bsg::showSelected {} {
    variable db
    set h [current]
    if {$h eq ""} { clearPreview; return }
    set sid [sectionOf $h]
    set t .main.prev.text
    $t configure -state normal
    $t delete 1.0 end
    if {$sid eq ""} {
        # glossary term without an appendix entry: name the TSV
        .main.prev.head configure -text "[dict get $h book] -- Glossar"
        $t insert end "»[dict get $h term]« steht im Glossar\n" head \
            "[dict get $h chapter]\n\n" {} \
            "Das Glossarkapitel des Buchs (Anhang) erklärt den Begriff; die\
             Abschnittsliste zeigt, wo er im Text vorkommt.\n"
        $t configure -state disabled
        return
    }
    $db eval {SELECT s.book, s.lang, s.chapter, s.label, s.heading, s.line,
                     s.body, b.title
              FROM sections s LEFT JOIN books b ON b.book = s.book AND b.lang = s.lang
              WHERE s.id = :sid} r {
        set head "$r(title) -- [labelText $r(label)] -- $r(chapter):$r(line)"
        .main.prev.head configure -text $head
        $t insert end "$r(heading)\n" head "\n" {}
        insertBody $t $r(body)
    }
    mark
    $t configure -state disabled
    set first [lindex [$t tag ranges hit] 0]
    if {$first ne ""} { $t see $first } else { $t see 1.0 }
}

# Body text as stored by book-search.tcl: source lines, code lines with four
# leading blanks. Prose lines of a paragraph are joined again; code, list
# items, table rows and blank lines keep their line.
proc ::bsg::insertBody {t body} {
    set para ""
    set flush {
        if {$para ne ""} { $t insert end "$para\n" body; set para "" }
    }
    foreach line [split $body \n] {
        if {[string match "    *" $line] && ![regexp {^\s*([-*+]|\d+\.)\s} $line]} {
            eval $flush
            $t insert end "[string range $line 4 end]\n" code
        } elseif {[string trim $line] eq ""} {
            eval $flush
            $t insert end "\n" body
        } elseif {[regexp {^\s*([-*+]|\d+\.)\s|^\s*\|} $line]} {
            eval $flush
            set para [string trimright $line]
        } else {
            set l [string trim $line]
            set para [expr {$para eq "" ? $l : "$para $l"}]
        }
    }
    eval $flush
}

# Mark the search words in the preview (case-insensitive; whole words or,
# in substring mode, anywhere).
proc ::bsg::mark {} {
    variable words; variable mode
    set t .main.prev.text
    $t tag remove hit 1.0 end
    set list $words
    if {$mode eq "raw"} {
        set list [lmap w [regexp -all -inline {[\w.:-]+} [lindex $words 0]] {
            expr {$w in {AND OR NOT NEAR} ? [continue] : [string trimright $w *]}
        }]
    }
    foreach w $list {
        set w [string trim $w "\""]
        if {$w eq ""} continue
        set pat [regsub -all {[][\\.*+?(){}^$|]} $w {\\&}]
        if {$mode eq "word"} { set pat "\\m$pat\\M" }
        if {$mode eq "prefix"} { set pat "\\m$pat" }
        set idx 1.0
        while {[set idx [$t search -regexp -nocase -count n -- $pat $idx end]] ne ""} {
            if {$n == 0} break
            $t tag add hit $idx "$idx + $n chars"
            set idx [$t index "$idx + $n chars"]
        }
    }
}

# ------------------------------------------------------------------
# open
# ------------------------------------------------------------------

proc ::bsg::opener {target} {
    switch -- $::tcl_platform(platform) {
        windows {
            exec {*}[auto_execok start] "" $target &
        }
        default {
            if {$::tcl_platform(os) eq "Darwin"} {
                exec open $target &
            } else {
                exec xdg-open $target &
            }
        }
    }
}

proc ::bsg::fileUrl {path} {
    set p [file normalize $path]
    if {$::tcl_platform(platform) eq "windows"} { set p "/$p" }
    # spaces and a few others; '#' must not occur in the path part
    return "file://[string map {% %25 " " %20 # %23} $p]"
}

proc ::bsg::chapterPath {h} {
    variable db; variable root
    if {[dict exists $h kind] && [dict get $h kind] eq "pdf"} {
        return [file join $root [dict get $h pdf]]
    }
    set book [dict get $h book]; set lang [dict get $h lang]
    set dir [$db onecolumn {SELECT dir FROM books WHERE book = :book AND lang = :lang}]
    return [file join $root $dir [dict get $h chapter]]
}

proc ::bsg::openHtml {} {
    variable db; variable root
    set h [current]
    if {$h eq ""} return
    set book [dict get $h book]; set lang [dict get $h lang]
    if {[dict exists $h kind] && [dict get $h kind] eq "pdf"} {
        # a PDF page: the file at the page (pdf.js and Chrome follow #page=N)
        set url "[fileUrl [file join $root [dict get $h pdf]]]#[dict get $h anchor]"
        if {[catch {opener $url} err]} { setStatus "Öffnen: $err" } \
        else { setStatus "geöffnet: $url" }
        return
    }
    set html [$db onecolumn {SELECT html FROM books WHERE book = :book AND lang = :lang}]
    if {$html eq ""} {
        setStatus "Kein HTML für $book gebaut -- öffne die Kapiteldatei."
        openFile
        return
    }
    set anchor [dict get $h anchor]
    if {$anchor eq ""} {
        # glossary term: jump to its entry in the glossary appendix
        set sid [sectionOf $h]
        if {$sid ne ""} { set anchor [$db onecolumn {SELECT anchor FROM sections WHERE id = :sid}] }
    }
    set url [fileUrl [file join $root $html]]
    if {$anchor ne ""} { append url "#$anchor" }
    if {[catch {opener $url} err]} { setStatus "Öffnen: $err" } \
    else { setStatus "geöffnet: $url" }
}

proc ::bsg::openFile {} {
    set h [current]
    if {$h eq ""} return
    if {[dict get $h type] eq "term" && [dict get $h kind] eq "glossar"} {
        # the TSV next to the book directory
        variable db; variable root
        set book [dict get $h book]; set lang [dict get $h lang]
        set dir [$db onecolumn {SELECT dir FROM books WHERE book = :book AND lang = :lang}]
        set p [file join $root [file dirname $dir] glossary [dict get $h chapter]]
    } else {
        set p [chapterPath $h]
    }
    if {[catch {opener [file nativename $p]} err]} { setStatus "Öffnen: $err" } \
    else { setStatus "geöffnet: $p" }
}

proc ::bsg::copyRef {} {
    set h [current]
    if {$h eq ""} return
    set ref "[chapterPath $h]:[dict get $h line]"
    clipboard clear
    clipboard append $ref
    setStatus "kopiert: $ref"
}

# ------------------------------------------------------------------
# rebuild the index in a second process
# ------------------------------------------------------------------

proc ::bsg::reindex {} {
    variable indexPipe; variable dbFile; variable root; variable db
    if {$indexPipe ne ""} return
    set tclsh [info nameofexecutable]
    # wish cannot print to a pipe on Windows; look for a tclsh next to it
    if {[string match -nocase *wish* [file tail $tclsh]]} {
        foreach c [glob -nocomplain -directory [file dirname $tclsh] tclsh*] {
            if {[file executable $c]} { set tclsh $c; break }
        }
    }
    set cmd [list $tclsh [file join $::bsgDir book-search.tcl] index -db $dbFile]
    if {$root ne ""} { lappend cmd -root $root }
    if {$db ne ""} { catch {$db close}; set db "" }
    if {[catch {open |[concat $cmd [list 2>@1]] r} indexPipe]} {
        setStatus "Index neu: $indexPipe"
        set indexPipe ""
        return
    }
    fconfigure $indexPipe -blocking 0 -encoding utf-8
    fileevent $indexPipe readable ::bsg::reindexRead
    .top.reindex state disabled
    setStatus "Index wird neu gebaut ..."
}

proc ::bsg::reindexRead {} {
    variable indexPipe
    if {[gets $indexPipe line] >= 0} {
        if {[string trim $line] ne ""} { setStatus [string trim $line] }
        return
    }
    if {![eof $indexPipe]} return
    fconfigure $indexPipe -blocking 1
    set rc [catch {close $indexPipe} err]
    set indexPipe ""
    .top.reindex state !disabled
    if {[openDb]} {
        if {$rc} { setStatus "Index neu: $err" }
        run
    }
}

# ------------------------------------------------------------------
# window
# ------------------------------------------------------------------

proc ::bsg::build {} {
    wm title . "Bibliothek durchsuchen"
    wm minsize . 640 360
    catch {wm geometry . 1100x700}

    ttk::frame .top -padding 6
    ttk::entry .top.q -textvariable ::bsg::query -width 40
    ttk::combobox .top.mode -state readonly -width 12 \
        -values {Wörter Wortanfang Teilwort FTS5-Ausdruck}
    .top.mode set Wörter
    ttk::combobox .top.book -state readonly -width 20 -textvariable ::bsg::book
    ttk::button .top.go -text Suchen -command ::bsg::run
    ttk::button .top.reindex -text "Index neu" -command ::bsg::reindex
    grid .top.q .top.mode .top.book .top.go .top.reindex -padx 3 -sticky ew
    grid columnconfigure .top 0 -weight 1
    pack .top -side top -fill x

    ttk::panedwindow .main -orient horizontal
    ttk::frame .main.list
    ttk::treeview .main.list.tree -columns {kap title where} \
        -yscrollcommand {.main.list.sb set} -selectmode browse
    .main.list.tree heading #0 -text Buch -anchor w
    .main.list.tree heading kap -text Kap. -anchor w
    .main.list.tree heading title -text Abschnitt -anchor w
    .main.list.tree heading where -text Datei -anchor w
    .main.list.tree column #0 -width 160 -stretch 0
    .main.list.tree column kap -width 60 -stretch 0
    .main.list.tree column title -width 260
    .main.list.tree column where -width 200 -stretch 0
    .main.list.tree tag configure group -font TkHeadingFont
    ttk::scrollbar .main.list.sb -command {.main.list.tree yview}
    pack .main.list.sb -side right -fill y
    pack .main.list.tree -side left -fill both -expand 1

    ttk::frame .main.prev
    ttk::label .main.prev.head -anchor w -padding {4 2}
    text .main.prev.text -wrap word -width 50 -padx 8 -pady 6 \
        -yscrollcommand {.main.prev.sb set} -state disabled -relief flat \
        -font TkTextFont
    .main.prev.text tag configure head -font TkHeadingFont -spacing3 4
    .main.prev.text tag configure hit -background #ffe08a
    .main.prev.text tag configure code -font TkFixedFont -background #f2f2f2 \
        -lmargin1 12 -lmargin2 12
    .main.prev.text tag raise hit
    ttk::scrollbar .main.prev.sb -command {.main.prev.text yview}
    pack .main.prev.head -side top -fill x
    pack .main.prev.sb -side right -fill y
    pack .main.prev.text -side left -fill both -expand 1

    .main add .main.list -weight 3
    .main add .main.prev -weight 2
    pack .main -side top -fill both -expand 1

    ttk::frame .bot -padding {6 2}
    ttk::button .bot.html -text "Im Browser öffnen" -command ::bsg::openHtml
    ttk::button .bot.file -text "Kapiteldatei öffnen" -command ::bsg::openFile
    ttk::button .bot.copy -text "Datei:Zeile kopieren" -command ::bsg::copyRef
    ttk::label .bot.status -textvariable ::bsg::status -anchor w
    pack .bot.html .bot.file .bot.copy -side left -padx 3
    pack .bot.status -side left -fill x -expand 1 -padx 8
    pack .bot -side bottom -fill x

    bind .top.q <KeyRelease> {
        if {"%K" ni {Return KP_Enter Up Down Escape Tab}} { ::bsg::schedule }
    }
    bind .top.q <Return> ::bsg::run
    bind .top.q <KP_Enter> ::bsg::run
    bind .top.q <Down> { focus .main.list.tree; ::bsg::firstHit }
    bind .top.mode <<ComboboxSelected>> {
        set ::bsg::mode [dict get {Wörter word Wortanfang prefix Teilwort sub
            FTS5-Ausdruck raw} [.top.mode get]]
        ::bsg::run
    }
    bind .top.book <<ComboboxSelected>> ::bsg::run
    bind .main.list.tree <<TreeviewSelect>> ::bsg::showSelected
    bind .main.list.tree <Double-1> ::bsg::openHtml
    bind .main.list.tree <Return> ::bsg::openHtml
    bind .main.list.tree <Control-c> ::bsg::copyRef
    bind . <Control-f> { focus .top.q; .top.q selection range 0 end }
    bind . <Escape> { focus .top.q; .top.q selection range 0 end }
    bind . <Control-e> ::bsg::openFile
    focus .top.q
}

proc ::bsg::firstHit {} {
    set tree .main.list.tree
    if {[$tree selection] ne ""} return
    foreach g [$tree children {}] {
        set c [lindex [$tree children $g] 0]
        if {$c ne ""} { $tree selection set $c; $tree focus $c; return }
    }
}

# ------------------------------------------------------------------
# main
# ------------------------------------------------------------------

proc ::bsg::main {argv} {
    variable dbFile; variable root; variable query
    set words {}
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set a [lindex $argv $i]
        switch -- $a {
            -db   { set dbFile [file normalize [lindex $argv [incr i]]] }
            -root { set root [file normalize [lindex $argv [incr i]]] }
            default { lappend words $a }
        }
    }
    if {$root eq ""} { set root [file dirname $::bs::kitDir] }
    if {$dbFile eq ""} { set dbFile [file join $root bibliothek-suche.db] }
    build
    if {[openDb] && [llength $words]} {
        set query [join $words " "]
        run
    }
}

::bsg::main $::argv
