## Images

A book may contain images: screenshots, photographs, and pre-rendered
diagrams. Images use plain CommonMark syntax, both as a standalone block
and inline.

### Syntax

A standalone image block. The alt text becomes the caption
(`<figcaption>` in HTML, italic grey text below the image in PDF):

```markdown
![The log viewer after the first run](images/logviewer.png)
```

An inline image inside a paragraph, a table cell or a list item. The alt
text is not rendered as a caption here:

```markdown
Click the ![save icon](images/save.png) to store the entry.
```

Both forms accept an optional title:

```markdown
![Caption](images/logviewer.png "Tooltip text")
```

### Location and paths

Image paths are **relative to the book directory** — the same directory
that holds the chapter files and `book.tcl`. A subdirectory is
conventional but not required:

```
mybook/
├── book.tcl
├── 010-intro.md
├── 020-usage.md
└── images/
    ├── logviewer.png
    └── mainwindow.png
```

Absolute paths and `http(s):` URLs are passed through to HTML unchanged
and are **not** embedded in PDF; the PDF falls back to a `[image: alt]`
marker. Keep images local.

### Formats

| Purpose | Format | Reason |
|---------|--------|--------|
| Screenshot | PNG | lossless, text stays crisp |
| Photograph | JPEG | smaller for continuous-tone images |
| Diagram | PNG for PDF, SVG for HTML | PDF cannot embed SVG |

The PDF backend loads image files directly from disk. **Tk is not
required** for a book build.

Because PDF cannot embed SVG, a diagram that should be vector in HTML and
raster in PDF is exported twice under the same base name (`abi.svg` and
`abi.png`). Reference the one that matches the primary output format; a
build that produces both formats from one source must choose.

### Resolution

Images are scaled down to the text width if they are wider, and never
scaled up. For print, aim for roughly 200 dpi at the final size:

    pixel width about eight times the target width in mm

At a 120 mm text width that is about 950 px. Capture screenshots on a
HiDPI display or enlarge the window before capturing — upscaling
afterwards does not recover detail.

### Page breaks

An image block that does not fit in the remaining space on a PDF page is
moved to the next page as a whole. It is never split.

### Missing images

A referenced file that does not exist is reported on stderr during the
build and rendered as an `[image: alt]` marker. The build does not fail.

### Multilingual books

Screenshots of a localised user interface belong to the language, not to
the book. Keep them per language directory and reference them with the
same relative path from each translation:

```
git-und-tcltk/      images/mainwindow.png     # German UI
git-und-tcltk-en/   images/mainwindow.png     # English UI
```

Each translation is its own sibling directory (`SPEC.md` §1), not a `de/`
or `en/` folder nested inside the book. Reference the image with the same
relative path from every language. Where a screenshot carries no text, a
single shared copy is acceptable; reference it from each language with a
path that reaches the shared file.
