# book.tcl -- example book (reference). Build:
#   tclsh ../../tools/book-build.tcl . -number

set title     "My Book"
set author    ""
set subtitle  "A bilingual example"
set date      ""
set lang      "en"
set titlePage 1

set tocTitle   "Contents"
set indexTitle "Index"

set chapters {
    010-einleitung.md
    020-thema.md
}
