#!/usr/bin/env tclsh
# book-search.tcl -- full-text search across all bookkit books (SQLite FTS5)
#
# Builds one SQLite database over every book in the registry and searches it.
# Every chapter is split at its headings; each section is one row. Two FTS5
# indexes cover the sections: words (unicode61, diacritics folded, so
# "Kodierung" and "kodierung" match) and trigrams (substrings such as
# "scalingPct" or "WinPipe"). [term]{.index} markers and the glossary TSV
# files form a separate term table; a term hit is listed before full-text hits.
#
# Usage (from the directory that holds bookkit/ and the books):
#
#   tclsh bookkit/tools/book-search.tcl index ?options?
#   tclsh bookkit/tools/book-search.tcl query ?options? word ?word ...?
#   tclsh bookkit/tools/book-search.tcl stats ?-db file?
#
# index options:
#   -root dir       workspace with the books (default: the directory above
#                   bookkit/)
#   -registry file  default <bookkit>/doc/REGISTRY.md
#   -db file        default <root>/bibliothek-suche.db
#   -book id        only this book (repeatable)
#   -dir path       index an extra book directory not in the registry
#                   (repeatable; the book id is the directory name)
#   -lang l         only directories of this language (default: all
#                   languages listed in the registry that exist on disk)
#   -pdf dir        also index every PDF below dir (repeatable): one entry
#                   per file, one section per page, linked as file.pdf#page=N.
#                   Needs tclutils::tupdftext (tclutils 0.67.0); the text of
#                   an unchanged PDF (same mtime and size) is taken from the
#                   previous index, so a rebuild only reads new or changed
#                   files. A PDF without text (scan, encrypted) is listed.
#   -tclutils dir   where tclutils is (its lib/tm), if not on the module path
#                   or in TCLUTILS_TM
#
# query options:
#   -db file        as above
#   -book id        only this book (repeatable)
#   -limit n        number of section hits (default 20)
#   -sub            substring search (trigram) instead of words
#   -prefix         words as prefixes (nativ -> nativename)
#   -raw            the words are an FTS5 expression as they are
#   -format f       text (default) or tsv
#
# Without -sub a word query that finds nothing is repeated as a substring
# query (words of at least three characters); the output says so.
#
# Links: for every hit the HTML file of the book (built next to the book
# directory by book-build.tcl) and the anchor are given. Heading anchors are
# computed like docir::html (_makeId: lower case, everything outside a-z0-9
# becomes "-"); index anchors are idx-N, counted over the whole book in
# chapter order, as docir counts them in the book HTML.
#
# Needs Tcl 8.6 or 9 and the sqlite3 package with FTS5 (trigram needs
# SQLite 3.34 or newer; without it -sub is not available).

package require Tcl 8.6-
package require sqlite3

namespace eval ::bs {
    # Not [file normalize]: that resolves a symlinked bookkit/ to its target,
    # and the default root is the workspace the tool was called from.
    variable scriptDir [file dirname [file join [pwd] [info script]]]
    if {[file tail $scriptDir] eq "."} { set scriptDir [file dirname $scriptDir] }
    variable kitDir    [file dirname $scriptDir]
    if {[file tail $kitDir] eq "."} { set kitDir [file dirname $kitDir] }
}

# ------------------------------------------------------------------
# small helpers
# ------------------------------------------------------------------

proc ::bs::readFile {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set c [read $fh]
    close $fh
    return $c
}

proc ::bs::die {msg} {
    puts stderr "book-search: $msg"
    exit 1
}

# Parse "-opt value" pairs; repeatable options collect lists.
proc ::bs::options {argv spec} {
    # spec: dict name -> {default kind} ; kind: value | list | flag
    set o [dict create]
    dict for {k d} $spec { dict set o $k [lindex $d 0] }
    set rest {}
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set a [lindex $argv $i]
        if {$a eq "--"} { lappend rest {*}[lrange $argv $i+1 end]; break }
        if {[dict exists $spec $a]} {
            set kind [lindex [dict get $spec $a] 1]
            switch -- $kind {
                flag  { dict set o $a 1 }
                value - list {
                    if {$i + 1 >= [llength $argv]} { die "missing value for $a" }
                    set v [lindex $argv [incr i]]
                    if {$kind eq "list"} { dict lappend o $a $v } else { dict set o $a $v }
                }
            }
        } elseif {[string match -* $a] && [llength $rest] == 0 \
                && ![string is double -strict $a]} {
            die "unknown option $a (known: [lsort [dict keys $spec]])"
        } else {
            lappend rest $a
        }
    }
    return [list $o $rest]
}

# docir::html::_makeId
proc ::bs::slug {text} {
    set id [string tolower $text]
    set id [regsub -all {[^a-z0-9]+} $id "-"]
    set id [string trim $id "-"]
    if {$id eq ""} { set id "section" }
    return $id
}

# Markdown inline to plain text: index spans, links, images, code, emphasis.
# Code spans of a line as a list of {start end} (index of the opening and the
# closing backtick run). A run of n backticks closes with the next run of
# exactly n. Written out because a Tcl regexp like (`+).+?\1 is greedy as a
# whole (the first quantifier sets the preference) and would span the line.
proc ::bs::codeSpans {s} {
    set out {}; set i 0; set len [string length $s]
    while {[set a [string first ` $s $i]] >= 0} {
        set e $a
        while {$e < $len && [string index $s $e] eq "`"} { incr e }
        set n [expr {$e - $a}]
        set j $e; set close -1
        while {[set b [string first ` $s $j]] >= 0} {
            set f $b
            while {$f < $len && [string index $s $f] eq "`"} { incr f }
            if {$f - $b == $n} { set close $b; break }
            set j $f
        }
        if {$close < 0} { break }
        lappend out [list $a [expr {$close + $n - 1}] $n]
        set i [expr {$close + $n}]
    }
    return $out
}

proc ::bs::plain {s} {
    # code spans first: their content stays as it is (no tag or link removal)
    set codes {}
    foreach sp [lreverse [codeSpans $s]] {
        lassign $sp a e n
        set n0 [llength $codes]
        lappend codes [string trim [string range $s [expr {$a + $n}] [expr {$e - $n}]]]
        set s [string replace $s $a $e "\x01$n0\x02"]
    }
    regsub -all {<!--.*?-->} $s {} s
    regsub -all {!\[([^\]]*)\]\([^)]*\)} $s {\1} s
    regsub -all {\[([^\]]*)\]\{[^\}]*\}} $s {\1} s
    regsub -all {\[([^\]]*)\]\([^)]*\)} $s {\1} s
    regsub -all {\{#[^\}]*\}} $s {} s
    set s [string map {** "" __ ""} $s]
    # single * or _ used as emphasis at word borders (keep tcl_platform)
    regsub -all {(^|[\s(])[*_]([^*_\s][^*_]*?)[*_](?=[\s.,;:!?)]|$)} $s {\1\2} s
    regsub -all {<[^>]+>} $s {} s
    set i 0
    foreach c $codes { set s [string map [list "\x01$i\x02" $c] $s]; incr i }
    return $s
}

# Index markers of one line: list of terms. A marker that starts inside a
# code span (`[x]{.index}` as an example) is not a marker; docir does not
# count it either. A marker may contain a code span: [`tcl_platform`]{.index}.
proc ::bs::markers {line} {
    set spans [codeSpans $line]
    set out {}
    foreach {m term} [regexp -all -inline -indices \
            {\[([^\]]+)\]\{[^\}]*\.index[^\}]*\}} $line] {
        set st [lindex $m 0]; set inCode 0
        foreach sp $spans {
            if {$st > [lindex $sp 0] && $st < [lindex $sp 1]} { set inCode 1; break }
        }
        if {!$inCode} { lappend out [plain [string range $line {*}$term]] }
    }
    return $out
}

# ------------------------------------------------------------------
# registry and books
# ------------------------------------------------------------------

# Returns a list of dicts {id path langs}.
proc ::bs::readRegistry {file} {
    set out {}
    foreach line [split [readFile $file] \n] {
        if {![regexp {^\|\s*([A-Za-z0-9._-]+)\s*\|\s*`([^`]+)`\s*\|\s*([^|]*)\|} \
                $line -> id path langs]} continue
        if {$id eq "book-id"} continue
        set ll {}
        foreach l [split $langs ,] {
            set l [string trim [regsub {\(.*} $l {}]]
            if {[regexp {^[a-z]{2}$} $l]} { lappend ll $l }
        }
        lappend out [dict create id $id path [string trimright $path /] langs $ll]
    }
    return $out
}

# Directories of a registry entry: the source, plus sibling <base>-<lang>.
proc ::bs::bookDirs {root entry onlyLang} {
    set src [file join $root [dict get $entry path]]
    set dirs {}
    set srcLang ""
    regexp -- {-([a-z]{2})$} [file tail $src] -> srcLang
    if {[file isdirectory $src]} { lappend dirs [list $src $srcLang] }
    if {[regexp {^(.*)-[a-z]{2}$} [file tail $src] -> base]} {
        foreach l [dict get $entry langs] {
            if {$l eq $srcLang} continue
            set d [file join [file dirname $src] "$base-$l"]
            if {[file isdirectory $d]} { lappend dirs [list $d $l] }
        }
    }
    if {$onlyLang ne ""} {
        set dirs [lmap d $dirs { expr {[lindex $d 1] eq $onlyLang ? $d : [continue]} }]
    }
    return $dirs
}

# book.tcl, data only (safe interp), as book-build/book-webindex read it.
proc ::bs::manifest {bookdir} {
    set bt [file join $bookdir book.tcl]
    set title ""; set chapters {}
    if {[file exists $bt]} {
        set ip [interp create -safe]
        interp eval $ip {set title ""; set chapters {}}
        if {![catch {interp eval $ip [readFile $bt]}]} {
            set title    [interp eval $ip {set title}]
            set chapters [interp eval $ip {set chapters}]
        }
        interp delete $ip
    }
    if {[llength $chapters] == 0} {
        set chapters [lsort [lmap f [glob -nocomplain -directory $bookdir \
            {[0-9][0-9][0-9]-*.md}] {file tail $f}]]
    }
    return [list $title $chapters]
}

# "8", "A" ... like the printed book: 8xx/9xx files are appendices.
proc ::bs::chapterLabels {chapters} {
    set n 0; set a 0; set out {}
    foreach c $chapters {
        if {[regexp {^[89]\d\d-} [file tail $c]]} {
            lappend out [format %c [expr {65 + $a}]]; incr a
        } else {
            lappend out [incr n]
        }
    }
    return $out
}

# Split one chapter into sections. Returns list of dicts
# {level heading anchor line body idx} ; idx = list of {term localN line}.
proc ::bs::sections {text} {
    set secs {}
    set cur [dict create level 0 heading "" anchor "" line 1 body {} idx {}]
    set inFence 0; set fence ""
    set n 0; set lineNo 0
    foreach line [split $text \n] {
        incr lineNo
        if {[regexp {^\s{0,3}(```+|~~~+)} $line -> f]} {
            if {!$inFence} { set inFence 1; set fence [string index $f 0] } \
            elseif {[string index $f 0] eq $fence} { set inFence 0 }
            continue
        }
        if {$inFence} {
            # code as it is: <MouseWheel>, [list ...] stay searchable. Four
            # leading blanks mark it as code for a viewer (Markdown's
            # indented code); the FTS tokenizers ignore them.
            dict lappend cur body "    $line"
            continue
        }
        if {!$inFence && [regexp {^(#{1,6})\s+(.*?)\s*#*\s*$} $line -> h t]} {
            lappend secs $cur
            set id ""
            if {[regexp {\{#([^\}\s]+)\}\s*$} $t -> id]} {
                regsub {\s*\{#[^\}]*\}\s*$} $t {} t
            }
            set ht [string trim [plain $t]]
            if {$id eq ""} { set id [slug $ht] }
            set cur [dict create level [string length $h] heading $ht \
                anchor $id line $lineNo body {} idx {}]
        } else {
            dict lappend cur body [plain $line]
        }
        if {!$inFence} {
            foreach term [markers $line] {
                incr n
                dict lappend cur idx [list [string trim [plain $term]] $n $lineNo]
            }
        }
    }
    lappend secs $cur
    return $secs
}

# ------------------------------------------------------------------
# index
# ------------------------------------------------------------------

proc ::bs::createSchema {db} {
    $db eval {
        PRAGMA journal_mode = OFF;
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE books(book TEXT, lang TEXT, title TEXT, dir TEXT,
                           html TEXT, pdf TEXT, kind TEXT DEFAULT 'book',
                           PRIMARY KEY(book, lang));
        CREATE TABLE pdfcache(path TEXT PRIMARY KEY, mtime INTEGER,
                              size INTEGER, title TEXT, status TEXT,
                              pages TEXT);
        CREATE TABLE sections(id INTEGER PRIMARY KEY, book TEXT, lang TEXT,
                              chapter TEXT, label TEXT, heading TEXT,
                              level INTEGER, anchor TEXT, line INTEGER,
                              body TEXT);
        CREATE TABLE terms(term TEXT, kind TEXT, book TEXT, lang TEXT,
                           chapter TEXT, label TEXT, anchor TEXT,
                           line INTEGER, section INTEGER);
        CREATE INDEX terms_term ON terms(term COLLATE NOCASE);
        CREATE VIRTUAL TABLE sec_w USING fts5(heading, body,
            content='sections', content_rowid='id',
            tokenize='unicode61 remove_diacritics 2');
    }
    set tri [expr {![catch {$db eval {
        CREATE VIRTUAL TABLE sec_t USING fts5(heading, body,
            content='sections', content_rowid='id', tokenize='trigram')
    }}]}]
    return $tri
}

proc ::bs::cmdIndex {argv} {
    variable kitDir
    lassign [options $argv {
        -root {"" value} -registry {"" value} -db {"" value}
        -book {{} list} -dir {{} list} -lang {"" value}
        -pdf {{} list} -tclutils {"" value}
    }] o rest
    if {[llength $rest]} { die "index takes no words: $rest" }
    set root [dict get $o -root]
    if {$root eq ""} { set root [file dirname $kitDir] }
    set root [file normalize $root]
    set reg [dict get $o -registry]
    if {$reg eq ""} { set reg [file join $kitDir doc REGISTRY.md] }
    set dbf [dict get $o -db]
    if {$dbf eq ""} { set dbf [file join $root bibliothek-suche.db] }
    set only [dict get $o -book]

    set entries [readRegistry $reg]
    foreach d [dict get $o -dir] {
        set d [file normalize $d]
        lappend entries [dict create id [file tail $d] \
            path [string range $d [string length $root]+1 end] langs {} abs $d]
    }

    # PDF text from the previous index, reused when mtime and size match
    set cache [dict create]
    if {[llength [dict get $o -pdf]] && [file exists $dbf]} {
        catch {
            sqlite3 ::bs::old $dbf -readonly 1
            ::bs::old eval {SELECT path, mtime, size, title, status, pages FROM pdfcache} r {
                dict set cache $r(path) [list $r(mtime) $r(size) $r(title) $r(status) $r(pages)]
            }
        }
        catch {::bs::old close}
    }

    set tmp "$dbf.neu"
    file delete -force $tmp
    sqlite3 ::bs::db $tmp
    set tri [createSchema ::bs::db]
    set nBooks 0; set nSec 0; set nTerms 0; set missing {}
    set pdfStat [dict create files 0 pages 0 reused 0 skipped {}]
    ::bs::db transaction {
        foreach e $entries {
            set id [dict get $e id]
            if {[llength $only] && $id ni $only} continue
            if {[dict exists $e abs]} {
                set dirs [list [list [dict get $e abs] ""]]
            } else {
                set dirs [bookDirs $root $e [dict get $o -lang]]
            }
            if {[llength $dirs] == 0} { lappend missing $id; continue }
            foreach dl $dirs {
                lassign $dl bookdir lang
                lassign [indexBook ::bs::db $root $id $lang $bookdir] s t
                incr nBooks; incr nSec $s; incr nTerms $t
            }
        }
        foreach pd [dict get $o -pdf] {
            set pd [file normalize $pd]
            if {![file isdirectory $pd]} { lappend missing $pd; continue }
            loadPdfText [dict get $o -tclutils]
            set pdfStat [indexPdfDir ::bs::db $root $pd $cache $pdfStat]
            incr nSec [dict get $pdfStat newSections]
            dict set pdfStat newSections 0
        }
        ::bs::db eval {INSERT INTO sec_w(sec_w) VALUES('rebuild')}
        if {$tri} { ::bs::db eval {INSERT INTO sec_t(sec_t) VALUES('rebuild')} }
        set now [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]
        set ver [::bs::db eval {SELECT sqlite_version()}]
        ::bs::db eval {
            INSERT INTO meta VALUES('built', :now), ('root', :root),
                ('sqlite', :ver), ('trigram', :tri)
        }
    }
    ::bs::db close
    file rename -force $tmp $dbf
    puts "Index: $dbf"
    puts "  $nBooks Buchverzeichnisse, $nSec Abschnitte, $nTerms Stichwörter"
    if {[dict get $pdfStat files]} {
        puts "  PDF: [dict get $pdfStat files] Dateien, [dict get $pdfStat pages] Seiten\
            ([dict get $pdfStat reused] aus dem alten Index übernommen)"
        foreach {f why} [dict get $pdfStat skipped] {
            puts "  ohne Text: $f ($why)"
        }
    }
    if {!$tri} { puts "  ohne Trigramm-Index (SQLite zu alt): -sub geht nicht" }
    if {[llength $missing]} {
        puts "  nicht gefunden ([llength $missing]): [join $missing {, }]"
    }
}

# tclutils::tupdftext for PDF folders: from the module path, TCLUTILS_TM,
# -tclutils dir, or a tclutils tree next to the workspace.
proc ::bs::loadPdfText {dir} {
    if {![catch {package present tclutils::tupdftext}]} return
    set cands {}
    if {$dir ne ""} { lappend cands [file join $dir lib tm] $dir }
    if {[info exists ::env(TCLUTILS_TM)]} { lappend cands $::env(TCLUTILS_TM) }
    variable kitDir
    foreach base [list [file dirname $kitDir] [file dirname [file dirname $kitDir]]] {
        lappend cands [file join $base tclutils lib tm]
    }
    if {![catch {package require tclutils::tupdftext 0.1}]} return
    foreach c $cands {
        # only a directory that holds the module (tm paths must not nest)
        if {![llength [glob -nocomplain -directory [file join $c tclutils] tupdftext-*.tm]]} continue
        if {$c ni [tcl::tm::path list] && [catch {tcl::tm::path add $c}]} continue
        if {![catch {package require tclutils::tupdftext 0.1}]} return
    }
    die "PDF folders need tclutils::tupdftext (tclutils 0.67.0 or newer):\
        put tclutils/lib/tm on the module path, set TCLUTILS_TM or give -tclutils dir"
}

# All PDFs below dir (no dot folders), sorted.
proc ::bs::pdfFiles {dir} {
    set out {}
    foreach e [lsort -dictionary [glob -nocomplain -directory $dir *]] {
        set n [file tail $e]
        if {[string index $n 0] eq "."} continue
        if {[file isdirectory $e]} {
            lappend out {*}[pdfFiles $e]
        } elseif {[string tolower [file extension $n]] eq ".pdf"} {
            lappend out $e
        }
    }
    return $out
}

# Index every PDF below pd: one book per file, one section per page.
proc ::bs::indexPdfDir {db root pd cache stat} {
    dict set stat newSections 0
    foreach f [pdfFiles $pd] {
        # book id: the folder name given with -pdf plus the path inside it
        # (short, also for folders outside the workspace); the path for
        # opening stays relative to the workspace, or absolute outside it
        set rel [rel $root $f]
        set id "[file tail $pd]/[string range $f [string length $pd]+1 end]"
        set mt [file mtime $f]; set sz [file size $f]
        set title ""; set status ok; set pages {}
        if {[dict exists $cache $rel]
                && [lrange [dict get $cache $rel] 0 1] eq [list $mt $sz]} {
            lassign [dict get $cache $rel] - - title status pages
            dict incr stat reused
        } else {
            if {[catch {::tclutils::tupdftext::pages $f} pages opts]} {
                set status [lindex [dict get $opts -errorcode] end]
                set pages {}
            }
            set title [pdfTitle $f]
        }
        if {$title eq ""} { set title [file rootname [file tail $f]] }
        $db eval {INSERT INTO pdfcache VALUES(:rel, :mt, :sz, :title, :status, :pages)}
        dict incr stat files
        if {$status ne "ok"} {
            dict lappend stat skipped $rel $status
            continue
        }
        set dir [rel $root [file dirname $f]]
        $db eval {INSERT OR REPLACE INTO books(book, lang, title, dir, html, pdf, kind)
                  VALUES(:id, '', :title, :dir, '', :rel, 'pdf')}
        set chapter [file tail $f]
        set n 0
        foreach text $pages {
            incr n
            if {[string trim $text] eq ""} continue
            set first [string range [lindex [split $text \n] 0] 0 79]
            set heading "Seite $n: $first"
            set label "S. $n"
            set anchor "page=$n"
            $db eval {INSERT INTO sections(book, lang, chapter, label, heading,
                          level, anchor, line, body)
                      VALUES(:id, '', :chapter, :label, :heading, 1, :anchor, :n, :text)}
            dict incr stat newSections
            dict incr stat pages
        }
    }
    return $stat
}

# Title from the document information (tclutils::tupdf), if any.
proc ::bs::pdfTitle {f} {
    if {[catch {package require tclutils::tupdf}]} { return "" }
    if {[catch {::tclutils::tupdf::metadata $f} md]} { return "" }
    foreach k {Title title} {
        if {![dict exists $md $k]} continue
        set t [dict get $md $k]
        # a UTF-16BE string with byte order mark, as raw bytes
        if {[string range $t 0 1] eq "\xfe\xff"} {
            set t [::tclutils::tupdftext::_utf16 [string range $t 2 end]]
        }
        return [string trim $t]
    }
    return ""
}

proc ::bs::rel {root path} {
    if {[string first "$root/" $path] == 0} {
        return [string range $path [string length $root]+1 end]
    }
    return $path
}

proc ::bs::indexBook {db root book lang bookdir} {
    lassign [manifest $bookdir] title chapters
    set labels [chapterLabels $chapters]
    set base [file join [file dirname $bookdir] [file tail $bookdir]]
    set html [expr {[file exists $base.html] ? [rel $root $base.html] : ""}]
    set pdf  [expr {[file exists $base.pdf]  ? [rel $root $base.pdf]  : ""}]
    set dir [rel $root $bookdir]
    $db eval {INSERT OR REPLACE INTO books(book, lang, title, dir, html, pdf, kind)
              VALUES(:book, :lang, :title, :dir, :html, :pdf, 'book')}
    set nS 0; set nT 0; set global 0
    foreach ch $chapters label $labels {
        set path [file join $bookdir $ch]
        if {![file exists $path]} continue
        foreach s [sections [readFile $path]] {
            set body [string trim [join [dict get $s body] \n] \n]
            set heading [dict get $s heading]
            if {$heading eq "" && $body eq ""} continue
            set level [dict get $s level]; set anchor [dict get $s anchor]
            set line [dict get $s line]
            $db eval {INSERT INTO sections(book, lang, chapter, label, heading,
                          level, anchor, line, body)
                      VALUES(:book, :lang, :ch, :label, :heading, :level,
                             :anchor, :line, :body)}
            set sid [$db last_insert_rowid]
            incr nS
            foreach it [dict get $s idx] {
                lassign $it term - tline
                incr global
                set a "idx-$global"
                $db eval {INSERT INTO terms VALUES(:term, 'index', :book, :lang,
                              :ch, :label, :a, :tline, :sid)}
                incr nT
            }
        }
    }
    # glossary/<...>.tsv next to the book directory: header = language codes
    foreach g [glob -nocomplain -directory [file join [file dirname $bookdir] glossary] *.tsv] {
        set col -1
        foreach line [split [readFile $g] \n] {
            if {[string match #* $line] || [string trim $line] eq ""} continue
            set f [split $line \t]
            if {$col < 0} {
                set col [lsearch -exact $f [expr {$lang eq "" ? "de" : $lang}]]
                if {$col < 0} { set col 0 }
                continue
            }
            set term [string trim [lindex $f $col]]
            if {$term eq ""} continue
            set gl [file tail $g]
            $db eval {INSERT INTO terms VALUES(:term, 'glossar', :book, :lang,
                          :gl, '', '', 0, NULL)}
            incr nT
        }
    }
    return [list $nS $nT]
}

# ------------------------------------------------------------------
# query
# ------------------------------------------------------------------

proc ::bs::openDb {dbf} {
    variable kitDir
    if {$dbf eq ""} {
        set dbf [file join [file dirname $kitDir] bibliothek-suche.db]
    }
    if {![file exists $dbf]} {
        die "no index $dbf -- first: tclsh [info script] index"
    }
    sqlite3 ::bs::db $dbf -readonly 1
    return $dbf
}

proc ::bs::ftsQuote {w} { return "\"[string map {\" \"\"} $w]\"" }

proc ::bs::bookFilter {books} {
    if {[llength $books] == 0} { return "" }
    return " AND s.book IN ([join [lmap b $books {
        string cat ' [string map {' ''} $b] '
    }] ,])"
}

proc ::bs::cmdQuery {argv} {
    lassign [options $argv {
        -db {"" value} -book {{} list} -limit {20 value} -sub {0 flag}
        -prefix {0 flag} -raw {0 flag} -format {text value}
    }] o words
    if {[llength $words] == 0} { die "query needs at least one word" }
    openDb [dict get $o -db]
    set fmt [dict get $o -format]
    if {$fmt ni {text tsv}} { die "-format: text or tsv" }
    set mode word
    if {[dict get $o -sub]}    { set mode sub }
    if {[dict get $o -prefix]} { set mode prefix }
    if {[dict get $o -raw]}    { set mode raw }
    if {[catch {
        search ::bs::db $words -mode $mode -books [dict get $o -book] \
            -limit [dict get $o -limit]
    } r]} {
        die $r
    }
    set termHits {}
    foreach t [dict get $r terms] {
        lappend termHits {*}[dict values [dict filter $t key term kind book lang chapter label anchor line]]
    }
    set rows {}
    foreach h [dict get $r sections] {
        dict with h {}
        # a PDF page links to the file with #page=N
        if {$kind eq "pdf"} { set html $pdf }
        lappend rows $book $lang $chapter $label $heading $anchor $line \
            $snippet $snippetHeading $html $dir
    }
    output $fmt [join $words " "] $termHits $rows [dict get $r note]
    ::bs::db close
}

# ------------------------------------------------------------------
# Library entry: search an open database. Used by the CLI and by
# book-search-gui.tcl.
#
#   ::bs::search db words ?-mode word|prefix|sub|raw? ?-books ids? ?-limit n?
#
# Returns a dict:
#   terms    list of dicts {term kind book lang chapter label anchor line section}
#   sections list of dicts {id book lang chapter label heading anchor line
#                           snippet snippetHeading html dir}
#   mode     the mode actually used (a word search without hits falls back
#            to sub when every word has at least three characters)
#   note     "" or a short German note for the user
# Errors (bad option, FTS5 syntax with -mode raw) are thrown with errorcode
# {BOOKSEARCH ...}.
# ------------------------------------------------------------------
proc ::bs::search {db words args} {
    set o [dict merge {-mode word -books {} -limit 20} $args]
    set mode [dict get $o -mode]
    if {$mode ni {word prefix sub raw}} {
        return -code error -errorcode {BOOKSEARCH MODE} \
            "unknown mode \"$mode\": must be word, prefix, sub or raw"
    }
    set limit [dict get $o -limit]
    if {![string is integer -strict $limit] || $limit < 1} {
        return -code error -errorcode {BOOKSEARCH LIMIT} "-limit: positive integer"
    }
    set books [dict get $o -books]
    set words [lmap w $words { expr {[string trim $w] eq "" ? [continue] : $w} }]
    if {[llength $words] == 0} {
        return [dict create terms {} sections {} mode $mode note ""]
    }
    set phrase [join $words " "]

    # 1. terms: exact, case-insensitive
    set bf [string map {s.book book} [bookFilter $books]]
    set terms {}
    $db eval "
        SELECT term, kind, book, lang, chapter, label, anchor, line, section
        FROM terms WHERE term = :phrase COLLATE NOCASE $bf
        ORDER BY kind DESC, book, lang, line" r {
        lappend terms [dict create term $r(term) kind $r(kind) book $r(book) \
            lang $r(lang) chapter $r(chapter) label $r(label) \
            anchor $r(anchor) line $r(line) section $r(section)]
    }

    # 2. sections
    set tri [$db eval {SELECT value FROM meta WHERE key = 'trigram'}]
    if {$mode eq "sub" && !$tri} {
        return -code error -errorcode {BOOKSEARCH TRIGRAM} \
            "index has no trigram table (substring search)"
    }
    set rows [searchSections $db $mode $words $books $limit]
    set note ""
    if {[llength $rows] == 0 && $mode eq "word" && $tri} {
        set long [lmap w $words { expr {[string length $w] >= 3 ? $w : [continue]} }]
        if {[llength $long] == [llength $words]} {
            set rows [searchSections $db sub $words $books $limit]
            if {[llength $rows]} {
                set mode sub
                set note "keine Worttreffer, Teilwort-Suche"
            }
        }
    }
    return [dict create terms $terms sections $rows mode $mode note $note]
}

proc ::bs::searchSections {db mode words books limit} {
    switch -- $mode {
        raw    { set expr [join $words " "] }
        sub    { set expr [join [lmap w $words { ftsQuote $w }] " AND "] }
        prefix { set expr [join [lmap w $words { string cat [ftsQuote $w] * }] " AND "] }
        default { set expr [join [lmap w $words { ftsQuote $w }] " AND "] }
    }
    set t [expr {$mode eq "sub" ? "sec_t" : "sec_w"}]
    # a trigram token is about one character, a word token one word
    set snipLen [expr {$mode eq "sub" ? 64 : 16}]
    set bf [bookFilter $books]
    set sql "
        SELECT s.id AS id, s.book AS book, s.lang AS lang, s.chapter AS chapter,
               s.label AS label, s.heading AS heading, s.anchor AS anchor,
               s.line AS line,
               snippet($t, 1, '»', '«', ' … ', $snipLen) AS snippet,
               snippet($t, 0, '»', '«', ' … ', $snipLen) AS snippetHeading,
               coalesce(b.html, '') AS html, coalesce(b.dir, '') AS dir,
               coalesce(b.pdf, '') AS pdf, coalesce(b.kind, 'book') AS kind
        FROM $t JOIN sections s ON s.id = $t.rowid
             LEFT JOIN books b ON b.book = s.book AND b.lang = s.lang
        WHERE $t MATCH :expr $bf
        ORDER BY bm25($t, 8.0, 1.0)
        LIMIT $limit"
    set rows {}
    if {[catch {
        $db eval $sql r {
            set d [dict create]
            foreach k {id book lang chapter label heading anchor line
                       snippet snippetHeading html dir pdf kind} {
                dict set d $k $r($k)
            }
            lappend rows $d
        }
    } err]} {
        return -code error -errorcode {BOOKSEARCH QUERY} "query: $err"
    }
    return $rows
}

proc ::bs::output {fmt phrase termHits rows note} {
    if {$fmt eq "tsv"} {
        foreach {term kind book lang ch label anchor line} $termHits {
            puts [join [list term $kind $book $lang $ch $line $anchor $term] \t]
        }
        foreach {book lang ch label heading anchor line snip snipH html dir} $rows {
            if {[string first » $snip] < 0} { set snip $snipH }
            set snip [string map {\n " " \t " "} $snip]
            set link [expr {$html ne "" ? "$html#$anchor" : "$dir/$ch"}]
            puts [join [list section $book $lang $ch $line $anchor $heading $snip $link] \t]
        }
        return
    }
    if {[llength $termHits]} {
        puts "Stichwort »$phrase«:"
        foreach {term kind book lang ch label anchor line} $termHits {
            set where [expr {$kind eq "glossar" ? "Glossar ($ch)" : "$ch:$line"}]
            set lg [expr {$lang ne "" ? " $lang" : ""}]
            set a [expr {$anchor ne "" ? "  #$anchor" : ""}]
            puts "  $book$lg  $where$a"
        }
        puts ""
    }
    if {$note ne ""} { puts "($note)\n" }
    if {[llength $rows] == 0} {
        puts "Keine Abschnitte zu »$phrase«."
        return
    }
    set i 0
    foreach {book lang ch label heading anchor line snip snipH html dir} $rows {
        incr i
        # the hit is only in the heading: show the start of the body instead
        if {[string first » $snip] < 0} { set snip [string range $snip 0 160] }
        set kap [expr {[string is integer -strict $label] ? "Kap. $label"
                       : [string match S.* $label] ? $label : "Anh. $label"}]
        set lg [expr {$lang ne "" ? " $lang" : ""}]
        puts [format "%2d. %s%s  %s  %s:%d  § %s" $i $book $lg $kap $ch $line $heading]
        set snip [string trim [regsub -all {\s+} $snip " "]]
        puts "    $snip"
        if {$html ne ""} { puts "    → $html#$anchor" } else { puts "    → $dir/$ch" }
    }
}

proc ::bs::cmdStats {argv} {
    lassign [options $argv {-db {"" value}}] o rest
    set dbf [openDb [dict get $o -db]]
    puts "Index: $dbf"
    ::bs::db eval {SELECT key, value FROM meta ORDER BY key} {
        puts [format "  %-8s %s" $key $value]
    }
    puts ""
    puts [format "  %-24s %-4s %9s %9s  %s" Buch Spr. Abschn. Stichw. Titel]
    ::bs::db eval {
        SELECT b.book, b.lang, b.title,
               (SELECT count(*) FROM sections s WHERE s.book=b.book AND s.lang=b.lang) AS ns,
               (SELECT count(*) FROM terms t WHERE t.book=b.book AND t.lang=b.lang) AS nt
        FROM books b ORDER BY b.book, b.lang
    } {
        puts [format "  %-24s %-4s %9d %9d  %s" $book $lang $ns $nt $title]
    }
    ::bs::db close
}

# ------------------------------------------------------------------

if {[info exists ::argv0] && [file normalize $::argv0] eq [file normalize [info script]]} {
    set cmd [lindex $::argv 0]
    set args [lrange $::argv 1 end]
    set run {}
    switch -- $cmd {
        index { set run ::bs::cmdIndex }
        query { set run ::bs::cmdQuery }
        stats { set run ::bs::cmdStats }
        default {
            puts stderr "Usage: book-search.tcl index|query|stats ?options? ?words?"
            puts stderr "  index  ?-root dir? ?-registry file? ?-db file? ?-book id? ?-dir path? ?-lang l? ?-pdf dir? ?-tclutils dir?"
            puts stderr "  query  ?-db file? ?-book id? ?-limit n? ?-sub? ?-prefix? ?-raw? ?-format text|tsv? word ..."
            puts stderr "  stats  ?-db file?"
            exit [expr {$cmd in {"" -h --help help} ? 0 : 1}]
        }
    }
    # "| head" closes the pipe early: end quietly, not with a trace
    if {[catch {$run $args} err opts]} {
        if {[string match {*broken pipe*} $err]} { exit 0 }
        return -options $opts $err
    }
}
