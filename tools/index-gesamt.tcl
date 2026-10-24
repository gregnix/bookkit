#!/usr/bin/env tclsh
# index-gesamt.tcl -- ein Gesamtindex ueber mehrere Handbuch-PDFs.
#
#   tclsh bookkit/tools/index-gesamt.tcl -pdf gesamt.pdf ?-title T?
#         ?-links 0|1? ?-lang de|en? ?-md gesamt.md? A.index.tsv B.index.tsv ...
#
# -lang en: Einleitungszeile englisch ("Terms from N manuals"), Vorgabe de.
#
# Die Eingaben schreibt manual-build.tcl mit -index -index-tsv DATEI (je
# Handbuch eine). Jede nennt das PDF, einen Namen (-label) und je Begriff die
# gedruckten Seiten. Daraus entsteht ein PDF mit allen Begriffen, alphabetisch,
# und hinter jedem Begriff, in welchem Handbuch er auf welchen Seiten steht:
#
#   after        Tcl/Tk 9.0: 75, 210 · Tcl/Tk 8.6: 71, 198
#
# Die Reihenfolge der Handbuecher je Begriff ist die der Eingaben.
#
# -links 1 (Vorgabe): jede Seitenzahl ist ein Verweis in das andere PDF
# (PDF-Aktion GoToR: Datei und Seite; docir und pdf4tcl ab 2026-10-23,
# aeltere Staende ergaenzt das Werkzeug selbst). Das PDF wird relativ zum Gesamtindex
# angegeben, so wie es neben der .index.tsv liegt; alle PDFs gehoeren also
# zusammen in einen Ordner (oder dieselbe Ordnerstruktur). Acrobat, Okular
# und Evince folgen solchen Verweisen; manche Betrachter im Browser nicht.
# -links 0: nur Text.
#
# Die Seitenzahlen gelten fuer genau diesen Stand der PDFs: nach jedem neuen
# Handbuch-PDF den Gesamtindex neu bauen (PDF-ALLE.sh in tcltk-manual-de
# macht beides zusammen).

package require Tcl 8.6-

set scriptDir [file dirname [file normalize [info script]]]
set searchBases {}
if {[info exists env(REPOS_DIR)]} { lappend searchBases $env(REPOS_DIR) }
lappend searchBases $scriptDir [file dirname $scriptDir] \
    [file dirname [file dirname $scriptDir]] \
    [file join $env(HOME) code git github] [file join $env(HOME) lib tcltk] \
    /usr/local/lib/tcltk
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

# ------------------------------------------------------------
# Aufruf
# ------------------------------------------------------------
proc usage {} {
    puts stderr "Aufruf: tclsh index-gesamt.tcl -pdf gesamt.pdf ?-title T? ?-links 0|1? ?-md gesamt.md? A.index.tsv ..."
    exit 2
}
set pdfOut ""; set mdOut ""; set title ""; set links 1; set lang de; set inputs {}
for {set i 0} {$i < $argc} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        -pdf   { set pdfOut [lindex $argv [incr i]] }
        -md    { set mdOut  [lindex $argv [incr i]] }
        -title { set title  [lindex $argv [incr i]] }
        -links { set links  [lindex $argv [incr i]] }
        -lang  { set lang   [lindex $argv [incr i]] }
        default {
            if {[string match -* $a]} usage
            lappend inputs $a
        }
    }
}
if {($pdfOut eq "" && $mdOut eq "") || ![llength $inputs]} usage
if {$lang ni {de en}} usage
if {$title eq ""} { set title [expr {$lang eq "en" ? "Combined index" : "Gesamtindex"}] }
set T [dict create \
    de {kopf "Begriffe aus %d Handb\u00fcchern:" begriffe Begriffe} \
    en {kopf "Terms from %d manuals:" begriffe terms}]
proc t {k} { dict get $::T $::lang $k }

# relativer Pfad von Ordner FROM zu Datei TO
proc relPath {from to} {
    set f [file split [file normalize $from]]
    set t [file split [file normalize $to]]
    set i 0
    while {$i < [llength $f] && $i < [llength $t] - 1 && [lindex $f $i] eq [lindex $t $i]} { incr i }
    set up [lrepeat [expr {[llength $f] - $i}] ..]
    return [join [concat $up [lrange $t $i end]] /]
}

# ------------------------------------------------------------
# Eingaben lesen: term -> Liste {label pdfRel pages}
# ------------------------------------------------------------
set outDir [file dirname [file normalize [expr {$pdfOut ne "" ? $pdfOut : $mdOut}]]]
set byTerm [dict create]
set handbuecher {}
foreach in $inputs {
    set h [open $in r]; fconfigure $h -encoding utf-8
    set kopf [dict create pdf "" label "" title ""]
    set rows {}
    foreach line [split [read $h] \n] {
        if {$line eq ""} continue
        if {[regexp {^# (pdf|label|title)\t(.*)$} $line -> k v]} {
            dict set kopf $k $v; continue
        }
        if {[string match "#*" $line]} continue
        lappend rows [split $line \t]
    }
    close $h
    set pdf [dict get $kopf pdf]; set label [dict get $kopf label]
    if {$pdf eq ""} { puts stderr "FEHLER: $in hat keine Zeile \"# pdf\""; exit 1 }
    if {$label eq ""} { set label [file rootname $pdf] }
    set pdfRel [relPath $outDir [file join [file dirname [file normalize $in]] $pdf]]
    lappend handbuecher [list $label $pdfRel [llength $rows]]
    foreach r $rows {
        lassign $r term pages
        dict lappend byTerm $term [list $label $pdfRel [split $pages ,]]
    }
}

# ------------------------------------------------------------
# Markdown: je Anfangsbuchstabe ein Abschnitt, je Begriff ein Listenpunkt
# ------------------------------------------------------------
proc mdEsc {s} { string map {\\ \\\\ * \\* _ \\_ [ \\[ ] \\] ` \\` < \\<} $s }
set md "# [mdEsc $title]\n\n"
append md "[format [t kopf] [llength $handbuecher]]\n\n"
foreach hb $handbuecher {
    lassign $hb label pdfRel n
    append md "- **[mdEsc $label]** (`$pdfRel`, $n [t begriffe])\n"
}
append md "\n"
set last ""
foreach term [lsort -dictionary [dict keys $byTerm]] {
    set ini [string toupper [string index $term 0]]
    if {![string is alpha $ini]} { set ini "#" }
    if {$ini ne $last} {
        append md "\n## $ini\n\n"
        set last $ini
    }
    set teile {}
    foreach occ [dict get $byTerm $term] {
        lassign $occ label pdfRel pages
        set ps {}
        foreach p $pages {
            if {$links} {
                lappend ps "\[$p\]([string map {{ } %20} $pdfRel]#page=$p)"
            } else {
                lappend ps $p
            }
        }
        lappend teile "[mdEsc $label]: [join $ps {, }]"
    }
    # \u2014 Gedankenstrich, \u00b7 Mittelpunkt (als Escape: die Datei wird
    # sonst in einer Nicht-UTF-8-Locale falsch gelesen)
    append md "- **[mdEsc $term]** \u2014 [join $teile " \u00b7 "]\n"
}

if {$mdOut ne ""} {
    set h [open $mdOut w]; fconfigure $h -encoding utf-8; puts -nonewline $h $md; close $h
    puts "MD:   $mdOut"
}
if {$pdfOut eq ""} { exit 0 }

foreach pkg {mdstack::parser docir::mdSource docir::md docir::pdf pdf4tcl} {
    if {[catch {package require $pkg} err]} {
        puts stderr "FEHLER: kann $pkg nicht laden: $err"
        puts stderr "  Setze DOCIR_HOME / MDSTACK_HOME / PDF4TCL_HOME / PDF4TCLLIB_HOME."
        exit 1
    }
}

# Verweise "datei.pdf#page=N" als Sprung in die andere Datei (GoToR).
# docir ab 2026-10-23 setzt solche Links selbst ueber pdf4tcl fileLinkAdd
# (pdf4tcl 0.9.4.73). Fehlt fileLinkAdd, liefert ein Mixin es nach; ist docir
# aelter, faengt der Mixin den URI-Link in hyperlinkAdd ab. Beides schreibt
# dieselbe Anmerkung. Mit aktuellem docir und pdf4tcl wird nichts ergaenzt.
oo::class create ::indexGesamt::FileLink {
    method fileLinkAdd {x y width height file {page 1} args} {
        my variable pdf
        my Trans  $x $y x y
        my TransR $width $height width height
        set x2 [expr {$x + $width}]
        set y2 [expr {$y + $height}]
        set f [string map {\\ \\\\ ( \\( ) \\)} $file]
        set andict "<< /Type /Annot\n  /Subtype /Link\n"
        append andict [format "  /Rect \[%.2f %.2f %.2f %.2f\]\n" $x $y $x2 $y2]
        append andict "  /F 4\n  /Border \[0 0 0\]\n  /H /I\n"
        append andict "  /A << /Type /Action /S /GoToR /F ($f) /D \[[expr {$page - 1}] /Fit\] /NewWindow true >>\n>>\n"
        lappend pdf(annotations) "[my AddAnnot $andict] 0 R"
        return
    }
}
oo::class create ::indexGesamt::UriAbfangen {
    method hyperlinkAdd {x y width height url args} {
        if {![regexp {^([^:#?]+\.pdf)(?:#page=([0-9]+))?$} $url -> file page]} {
            return [next $x $y $width $height $url {*}$args]
        }
        if {$page eq ""} { set page 1 }
        my fileLinkAdd $x $y $width $height [string map {%20 { }} $file] $page
    }
}
set docirKannDatei [llength [info commands ::docir::pdf::_canFileLink]]
set pdf4tclKannDatei [expr {"fileLinkAdd" in [info class methods ::pdf4tcl::pdf4tcl -all]}]
if {!$pdf4tclKannDatei} {
    oo::define ::pdf4tcl::pdf4tcl mixin -append ::indexGesamt::FileLink
}
if {!$docirKannDatei} {
    oo::define ::pdf4tcl::pdf4tcl mixin -append ::indexGesamt::UriAbfangen
}

set ir [docir::md::fromAst [mdstack::parser::parse $md]]
# Kopfzeile: links der Titel, rechts der Buchstabe der Seite (lebender
# Kolumnentitel ueber die "## A"-Abschnitte; docir ab 2026-10-23)
set kopf [expr {[llength [info commands ::docir::pdf::_runningTitle]] ? "%t\t%c" : ""}]
docir::pdf::render $ir $pdfOut [dict create title $title paper a4 footer "%p" \
    header $kopf runningLevel 2 generateToc 0 generateIndex 0 cid 1 \
    lang $lang creator "bookkit index-gesamt.tcl"]
puts "PDF:  $pdfOut ([dict size $byTerm] Begriffe, [llength $handbuecher] Handb\u00fccher)"
