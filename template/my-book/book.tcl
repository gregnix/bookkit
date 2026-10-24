# book.tcl -- Beispielbuch (Referenz). Build:
#   tclsh ../../tools/book-build.tcl . -number

set title     "Mein Buch"
set author    ""
set subtitle  "Ein zweisprachiges Beispiel"
set date      ""
set lang      "de"
set titlePage 1
set booktype  textbook

set tocTitle   "Inhaltsverzeichnis"
set indexTitle "Stichwortverzeichnis"

set chapters {
    010-einleitung.md
    020-thema.md
}
