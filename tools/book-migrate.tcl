#!/usr/bin/env tclsh
# One-shot migration: .md cross-refs -> book anchors, optional index markers.
# Usage: tclsh book-migrate.tcl <bookdir>

set bookdir [lindex $argv 0]
if {$bookdir eq "" || ![file isdirectory $bookdir]} {
    puts stderr "Usage: book-migrate.tcl <bookdir>"
    exit 1
}

# filename -> H1 anchor (must match docir HTML output)
array set anchor {
    01-grundlagen.md              grundlagen-architektur-stubs-tea
    02-tcl8-vs-tcl9.md            tcl-8-vs-tcl-9-unterschiede-und-migration
    03-linux.md                   build-auf-linux
    04-windows.md                 build-auf-windows
    04a-msvc-nmake.md             msvc-und-nmake-werkzeugkette
    05-macos.md                   build-auf-macos
    06-androwish.md               androwish-tcl-tk-f-r-android
    07-bawt.md                    bawt-build-automation-with-tcl
    08-stubs.md                   tcl-stubs-mechanismus-einsatz-fallstricke
    09-critcl-cffi.md             critcl-cffi-ffidl-c-aus-tcl-heraus
    10-sprachen.md                c-go-python-als-tcl-erweiterungen
    11-crosscompile.md            cross-kompilierung
    12-packaging.md               packaging-tclkit-starpack-zipkit-tpack-freewrap-tclcompiler
    12a-einzeldatei-tcl9.md       einzeldatei-anwendungen-mit-tcl-9-zipfs
    13-dokumentation.md           dokumentation-mit-doctools
    14-testen.md                  testen-mit-tcltest
    15-installer.md               installer-f-r-endbenutzer
    16-cicd.md                    ci-cd-im-detail
    17-paket-repos.md             paket-repositories
    18-abi.md                     abi-und-binary-kompatibilit-t
    19-grafik-pdf.md              grafik-pdf-und-imaging-libraries
    20-beispielprojekt.md         beispielprojekt-von-c-bis-release
    21-release-checkliste.md      release-checkliste
    22-rendering-stack.md         rendering-stack-strategie-f-r-tcl-tk
    23-tea.md                     tea-tcl-extension-architecture
    23a-tea-c-extension.md        tea-c-boilerplate-stubs-und-init-funktion
    23b-tea-msvc-windows.md       tea-windows-build-mit-msvc-tip-477
    23c-tea-tests-und-doku.md     tea-tests-und-manpages
    23d-erstes-tea-projekt.md      erstes-tea-projekt-schritt-f-r-schritt
    24-vendor-management.md       vendor-management-drittanbieter-code-in-tcl-erweiterungen
    25-go-extensions.md           go-erweiterungen-f-r-tcl
    26-windows-compiler.md        windows-compiler-wahl-msvc-mingw64-oder-clang-cl
    Kapitel_Makefile_Design_Troubleshooting.md makefile-design-troubleshooting
    tclmcairo-build-handbuch.md   tclmcairo-build-handbuch
}

# First index marker per term per file (term pattern -> replacement with {.index})
array set indexOnce {
    01-grundlagen.md {
        Erweiterung {[Erweiterung]{.index}}
        {Stub-Mechanismus} {[Stub-Mechanismus]{.index}}
        TEA {[TEA]{.index}}
        pkgIndex.tcl {[pkgIndex.tcl]{.index}}
        libtcl {[libtcl]{.index}}
    }
    02-tcl8-vs-tcl9.md {
        {Tcl 9} {[Tcl 9]{.index}}
        Migration {[Migration]{.index}}
    }
    06-androwish.md {
        Androwish {[Androwish]{.index}}
    }
    07-bawt.md {
        BAWT {[BAWT]{.index}}
    }
    08-stubs.md {
        {Stub-Mechanismus} {[Stub-Mechanismus]{.index}}
        libtcl {[libtcl]{.index}}
    }
    09-critcl-cffi.md {
        critcl {[critcl]{.index}}
        cffi {[cffi]{.index}}
        ffidl {[ffidl]{.index}}
    }
    11-crosscompile.md {
        Cross-Kompilierung {[Cross-Kompilierung]{.index}}
    }
    12-packaging.md {
        Starpack {[Starpack]{.index}}
        tclkit {[tclkit]{.index}}
        zipkit {[zipkit]{.index}}
    }
    12a-einzeldatei-tcl9.md {
        zipfs {[zipfs]{.index}}
    }
    13-dokumentation.md {
        doctools {[doctools]{.index}}
    }
    14-testen.md {
        tcltest {[tcltest]{.index}}
    }
    16-cicd.md {
        CI/CD {[CI/CD]{.index}}
    }
    18-abi.md {
        ABI {[ABI]{.index}}
        {Binary-Kompatibilität} {[Binary-Kompatibilität]{.index}}
    }
    19-grafik-pdf.md {
        pdf4tcl {[pdf4tcl]{.index}}
        Cairo {[Cairo]{.index}}
    }
    22-rendering-stack.md {
        {Rendering-Stack} {[Rendering-Stack]{.index}}
    }
    23-tea.md {
        configure.ac {[configure.ac]{.index}}
    }
    24-vendor-management.md {
        {Vendor-Management} {[Vendor-Management]{.index}}
    }
    25-go-extensions.md {
        cgo {[cgo]{.index}}
    }
    26-windows-compiler.md {
        MinGW64 {[MinGW64]{.index}}
        MSVC {[MSVC]{.index}}
    }
    tclmcairo-build-handbuch.md {
        tclmcairo {[tclmcairo]{.index}}
    }
}

proc convertLinks {text} {
    global anchor
    set out $text
    foreach {file anc} [array get anchor] {
        set lit [string map {. \\.} $file]
        set pat [format {\]\(%s[^)]*\)} $lit]
        regsub -all $pat $out "\](#$anc)" out
    }
    return $out
}

proc addIndexMarkers {text pairs} {
    set out $text
    foreach {pat repl} $pairs {
        if {[string match *\[$pat\]\{\.index\}* $out]} continue
        set idx [string first $pat $out]
        if {$idx < 0} continue
        set out [string replace $out $idx [expr {$idx + [string length $pat]}] $repl]
    }
    return $out
}

set changed 0
foreach f [glob -nocomplain -directory $bookdir *.md] {
    set tail [file tail $f]
    if {$tail eq "README.md"} continue

    set fh [open $f r]
    fconfigure $fh -encoding utf-8
    set text [read $fh]
    close $fh

    set new [convertLinks $text]
    if {[info exists indexOnce($tail)] && 0} {
        set new [addIndexMarkers $new $indexOnce($tail)]
    }

    if {$new ne $text} {
        set fh [open $f w]
        fconfigure $fh -encoding utf-8
        puts -nonewline $fh $new
        close $fh
        incr changed
        puts "aktualisiert: $tail"
    }
}

puts "Fertig: $changed Dateien geändert."
