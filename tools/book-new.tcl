#!/usr/bin/env tclsh
# book-new.tcl -- scaffold a new bookkit book (source + optional translations).
#
# Usage:
#   tclsh tools/book-new.tcl <book-id> "Title" ?-lang de? ?-author Name? ?-tr en,fr?
#
# Each new directory gets a LICENSE from bookkit/template (German for
# lang de, English otherwise). The placeholder <Name> becomes -author
# when that option is set; otherwise it stays, because bookkit is public
# and the template must not carry a real name.
#
# Creates, next to bookkit/ (one level above tools/):
#   <book-id>/                      source chapters + book.tcl (lang = -lang)
#   <book-id>-<xx>/                 one dir per -tr language (same filenames)
#   glossary/<book-id>-glossary.tsv multi-column TSV (source + translations)
#   i18n/<book-id>-anchors-<xx>.tsv  per-translation anchor map stub
#
# Headings carry NO numbers (the build adds them). See SPEC.md.

set bookId ""
set title  ""
set author ""
set srcLang "de"
set trLangs {}

# --- minimal arg parse ---
set rest {}
for {set i 0} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        -lang   { incr i; set srcLang [lindex $argv $i] }
        -author { incr i; set author  [lindex $argv $i] }
        -tr     { incr i; set trLangs [split [lindex $argv $i] ,] }
        default { lappend rest $a }
    }
}
set bookId [lindex $rest 0]
set title  [lindex $rest 1]

# Tcl 8.6 haelt die Kommandozeile als Bytes, nicht als Zeichen. Ein Titel mit
# Umlaut oder Gedankenstrich kommt darum schon als UTF-8-Bytefolge an; die
# Schreibroutinen unten setzen -encoding utf-8 und kodieren ein ZWEITES Mal.
# Beispiel unter Tcl 8.6.14:
#
#     book-new.tcl probeB "Ärger mit Übungen"
#     -> set title "\xc3\x83\xc2\x84rger ..."   also "Ãrger mit Ãbungen"
#
# Ein ASCII-Titel ist unbetroffen, deshalb faellt es erst beim ersten
# deutschen Titel auf -- und landet dann auf der Titelseite des Buchs.
# convertfrom macht aus den Bytes wieder Zeichen; ist der Titel schon
# Zeichen (Tcl 9), bleibt er unveraendert, weil reines ASCII gleich bleibt
# und gueltiges UTF-8 nicht zweimal dekodiert wird.
if {[package vsatisfies [package provide Tcl] 8.6-8.7]} {
    if {![catch {encoding convertfrom utf-8 $title} _t]} { set title $_t }
    if {![catch {encoding convertfrom utf-8 $author} _t]} { set author $_t }
    unset -nocomplain _t
}

if {$bookId eq "" || $title eq ""} {
    puts stderr "Usage: book-new.tcl <book-id> \"Title\" ?-lang de? ?-author Name? ?-tr en,fr?"
    exit 1
}

set scriptDir [file dirname [file normalize [info script]]]
# Books are created in the current working directory; bookkit/ is expected as
# a sibling tools directory there (so the build path ../bookkit/tools/ resolves).
set root [pwd]

# Localised default section titles for known languages; fallback = English.
array set TOC   {de "Inhaltsverzeichnis" en "Contents" fr "Table des matières" es "Índice"}
array set INDEX {de "Stichwortverzeichnis" en "Index" fr "Index" es "Índice temático"}
proc tocFor  {l} { if {[info exists ::TOC($l)]}   {return $::TOC($l)}   ; return "Contents" }
proc idxFor  {l} { if {[info exists ::INDEX($l)]} {return $::INDEX($l)} ; return "Index" }

# German template for lang de, English template for every other language.
# <Name> stays when no author was given.
proc writeLicense {path lang author} {
    set which my-book-en
    if {$lang eq "de"} { set which my-book }
    set src [file join [file dirname $::scriptDir] template $which LICENSE]
    if {![file exists $src]} {
        puts stderr "FEHLER: Lizenzvorlage fehlt: $src"
        exit 1
    }
    set fh [open $src r]
    fconfigure $fh -encoding utf-8
    set text [read $fh]
    close $fh
    if {$author ne ""} {
        set text [string map [list <Name> $author] $text]
    }
    set fh [open $path w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $text
    close $fh
}

proc writeBookTcl {path title lang author} {
    set fh [open $path w]; fconfigure $fh -encoding utf-8
    puts $fh "# book.tcl -- manifest. Build: tclsh ../bookkit/tools/book-build.tcl . -number"
    puts $fh ""
    puts $fh "set title     \"$title\""
    puts $fh "set author    \"$author\""
    puts $fh "set subtitle  \"\""
    puts $fh "set date      \"\""
    puts $fh "set lang      \"$lang\"           ;# source language / translation code"
    puts $fh "set titlePage 1"
    puts $fh "set booktype  \"\"            ;# textbook | workshop | manual | reference | developer (STYLE.md)"
    puts $fh ""
    puts $fh "set tocTitle   \"[tocFor $lang]\""
    puts $fh "set indexTitle \"[idxFor $lang]\""
    puts $fh ""
    puts $fh "set chapters {"
    puts $fh "    010-introduction.md"
    puts $fh "    020-first-topic.md"
    puts $fh "}"
    close $fh
}

proc writeChapter {path h1 body} {
    set fh [open $path w]; fconfigure $fh -encoding utf-8
    puts $fh "# $h1"
    puts $fh ""
    puts $fh $body
    close $fh
}

set intro "Replace this opening chapter. Headings carry no numbers here; the
build adds them. Mark index terms inline with a bracketed span, e.g.
a \[keyword\]{.index} stays in the text and enters the subject index.

## A section

Sections become sub-numbers and appear in the table of contents. Anchors are
derived from the heading text, so cross-references survive reordering."

set topic "A second chapter. Code blocks render verbatim:

\`\`\`tcl
puts \"Hello from your book\"
\`\`\`

Refer to another chapter by its title anchor, e.g. the
\[Introduction\](#introduction)."

# --- source dir ---
set srcDir [file join $root $bookId]
if {[file exists $srcDir]} { puts stderr "FEHLER: existiert schon: $srcDir"; exit 1 }
file mkdir $srcDir
writeBookTcl [file join $srcDir book.tcl] $title $srcLang $author
writeLicense [file join $srcDir LICENSE] $srcLang $author
writeChapter [file join $srcDir 010-introduction.md] "Introduction" $intro
writeChapter [file join $srcDir 020-first-topic.md]  "First Topic"  $topic
puts "angelegt: $srcDir  (lang=$srcLang)"

# --- translation dirs ---
foreach l $trLangs {
    if {$l eq "" || $l eq $srcLang} continue
    set d [file join $root ${bookId}-$l]
    if {[file exists $d]} { puts stderr "  uebersprungen (existiert): $d"; continue }
    file mkdir $d
    writeBookTcl [file join $d book.tcl] $title $l $author
    writeLicense [file join $d LICENSE] $l $author
    file copy [file join $srcDir 010-introduction.md] [file join $d 010-introduction.md]
    file copy [file join $srcDir 020-first-topic.md]  [file join $d 020-first-topic.md]
    puts "angelegt: $d  (Uebersetzung, lang=$l)"
    # anchor-map stub
    file mkdir [file join $root i18n]
    set amap [file join $root i18n ${bookId}-anchors-$l.tsv]
    if {![file exists $amap]} {
        set fh [open $amap w]; fconfigure $fh -encoding utf-8
        puts $fh "# Anker-Map ${srcLang}->$l fuer $bookId. Format: quell-slug<TAB>ziel-slug"
        puts $fh "# Nur fuer UEBERSETZTE Ueberschriften noetig; identische Slugs weglassen."
        puts $fh "# Anwenden: tclsh ../bookkit/tools/i18n-fix-anchors.tcl ${bookId}-$l/ i18n/${bookId}-anchors-$l.tsv"
        close $fh
    }
}

# --- multi-column glossary ---
file mkdir [file join $root glossary]
set gpath [file join $root glossary ${bookId}-glossary.tsv]
if {![file exists $gpath]} {
    set cols [concat [list $srcLang] $trLangs]
    set fh [open $gpath w]; fconfigure $fh -encoding utf-8
    puts $fh "# Glossar fuer $bookId -- mehrspaltig. Zeilen mit # werden ignoriert."
    puts $fh "# Kopfzeile = Sprachcodes; eine Zeile je Begriff, Spalten TAB-getrennt."
    puts $fh [join $cols "\t"]
    close $fh
    puts "angelegt: $gpath  (Spalten: $cols)"
}

puts ""
puts "Naechste Schritte:"
puts "  1. Kapitel in $bookId/ schreiben, book.tcl-Reihenfolge pflegen."
puts "  2. Bauen:  tclsh bookkit/tools/book-build.tcl $bookId/ -number"
puts "  3. Uebersetzen in ${bookId}-<lang>/ (gleiche Dateinamen)."
puts "  4. Eintrag im Register (REGISTRY.md, liest book-check.tcl)."
