#!/usr/bin/env tclsh
# Find likely untranslated German prose in English handbook chapters.
# Skips code blocks, headings, inline code, Markdown links, URLs.
#
# Usage:
#   tclsh i18n-check.tcl tcl-manual-en/
#   tclsh i18n-check.tcl tcl-manual-en/ -verbose

set bookdir [lindex $argv 0]
set verbose [expr {"-verbose" in $argv}]

if {$bookdir eq "" || ![file isdirectory $bookdir]} {
    puts stderr "Usage: i18n-check.tcl <bookdir-en> ?-verbose?"
    exit 1
}

# Common German function words / endings (heuristic, not exhaustive)
set patterns {
    {\m(und|oder|nicht|wird|werden|sind|ist|eine|einer|einem|einen|dieses|dieser|diese|können|muss|müssen|sollte|sollten|beim|zur|zum|führ|über|während|wenn|dann|auch|noch|schon|nur|sehr|hier|dort|damit|dass|wurde|wurden|oben|unten|Hinweis|Kapitel|Abschnitt|Beispiel|Wichtig|Empfehlung|Voraussetzung|Fallstrick|Übersicht)\M}
    {ä|ö|ü|ß}
    {\m(Stand:|Verwandte Kapitel|Häufigste Fehler|Ergänzungskapitel)\M}
}

set total 0
foreach f [lsort [glob -nocomplain -directory $bookdir *.md]] {
    if {[file tail $f] eq "README.md"} continue
    set fh [open $f r]
    fconfigure $fh -encoding utf-8
    set lines [split [read $fh] \n]
    close $fh

    set inCode 0
    set fileHits 0
    set ln 0
    foreach line $lines {
        incr ln
        if {[regexp {^\s*```} $line]} {
            set inCode [expr {!$inCode}]
            continue
        }
        if {$inCode} continue
        if {[regexp {^\s*#} $line]} continue

        set probe $line
        regsub -all {`[^`]+`} $probe "" probe
        regsub -all {\[[^\]]+\]\([^)]+\)} $probe "" probe
        regsub -all {https?://\S+} $probe "" probe

        foreach pat $patterns {
            if {[regexp -nocase $pat $probe -> hit]} {
                incr fileHits
                incr total
                if {$verbose} {
                    puts "[file tail $f]:$ln: …$hit…"
                    puts "  $line"
                }
                break
            }
        }
    }
    if {$fileHits > 0} {
        puts "[file tail $f]: $fileHits Verdachtszeile(n)"
    }
}

if {$total == 0} {
    puts "OK: keine offensichtlichen deutschen Reste (Heuristik)."
} else {
    puts "---"
    puts "Summe: $total Verdachtszeile(n). Mit -verbose Details anzeigen."
    puts "Hinweis: Code-Kommentare auf Deutsch sind erlaubt und werden übersprungen."
}
