# bookkit — Buchregister

Register aller Bücher, die dem bookkit-Format folgen. Eine Zeile je Buch; je
Sprache ein Verzeichnis `<book-id>` bzw. `<book-id>-<lang>`.

Bauen (aus dem Arbeitsverzeichnis, in dem die Bücher und `bookkit/` liegen):

```bash
tclsh bookkit/tools/book-build.tcl <book-id>/ -number
```

Ausgabe: `<book-id>.pdf` / `.html` eine Ebene über dem Buchverzeichnis.

---

## Status

| book-id | Quelle | Sprachen | book.tcl | Anmerkung |
|---|---|---|---|---|
| tea | `book-tea/tea-de/` | de, en | ja | TEA-Handbuch |
| tcltk9-fortgeschritten | `book-Programmierung-Fortgeschritten/TclTk-9-Programmierung-Fortgeschritten-de/` | de, en | ja | Tcl/Tk 9 Fortgeschritten |
| tcltk-canvas | `book-canvas/TclTk-Canvas-de/` | de (en geplant) | ja | Tk-Canvas-Lehrbuch |
| tcltk-text | `book-text-widget/TclTk-Text-de/` | de (en geplant) | ja | Tk-Text-Widget |
| tcltk-tcloo | `book-tcloo/TclTk-TclOO-de/` | de (en geplant) | ja | TclOO |
| linux-debian | `book-linux-debian/Debian-de/` | de (en geplant) | ja | Debian: apt, Policy, vier Shell-Serien (2026-10-20); Tcl-Lehrtext im Buch linux-tcltk |
| samba | `book-samba/Samba-de/` | de (en geplant) | ja | Samba: SMB-Server, Freigaben, Client |
| proxmox | `book-proxmox/Proxmox-de/` | de (en geplant) | ja | Proxmox VE: VM, Container, Cluster, CLI |
| tcltk-tablelist | `book-tablelist/TclTk-Tablelist-de/` | de (en geplant) | ja | Tablelist-Lehrbuch (tablelist_tile 7.11) |
| pdf4tcl | `book-pdf4tcl/pdf4tcl-de/` | de (en geplant) | ja | pdf4tcl 0.9.4.69; Links im Dokument 0.9.4.72 |
| mswindows11 | `book-mswindows11/Windows11-de/` | de (en geplant) | ja | Windows 11: Tastatur, Snap, Explorer, Terminal, MMC; Build 26300 gemessen 2026-10-20 |
| macos-tcltk | `book-macos-tcltk/MacOS-TclTk-de/` | de (en geplant) | ja | BAWT 3.3.0, Tcl/Tk 9.0.4 aqua auf Mac mini M6, macOS 27; Tasten, Finder-Start und App-Bündel gemessen |
| linux-tcltk | `book-linux-tcltk/Linux-TclTk-de/` | de (en geplant) | ja | Tcl 8.6.18/9.0.4 auf Debian forky, Xfce 4.20 (Howto-Serien); Containerprüfung Ubuntu 24.04, Tk 8.6.14/9.0.4 unter Xvfb: XDG, Locale, Mausrad, Zwischenablagen, Tests |
| mswindows-tcltk | `book-mswindows-tcltk/Windows-TclTk-de/` | de (en geplant) | ja | Tcl 8.6.17 und 9.0.4, TWAPI 5.2.0, Windows 11 Build 26300 (2026-10-20); serie-mswindows 12/12, serie-twapi unter 8.6.17 15/15, unter 9.0.4 Howto 15 FAIL |
| windows-shell | `book-windows-shell/Windows-Shell-de/` | de (en geplant) | ja | Shell-Namensraum und explorer.exe; 2026-10-20, Build 26300.9711, serie-windows-shell 16 OK, serie-explorer 10 OK |
| twapi | `book-twapi/Twapi-de/` | de (en geplant) | ja | TWAPI 5.2.0; Serie 15/15 am 2026-09-22 und 2026-10-20, unter Tcl 9.0.4 Howto 15 FAIL |
| ms365 | `book-ms365/Ms365-de/` | de (en geplant) | ja | Microsoft 365: Outlook, Excel, Teams |
| powershell | `book-powershell/PowerShell-de/` | de (en geplant) | ja | PowerShell 5.1, CIM, Get-CimInstance |
| python3 | `book-python3/Python3-de/` | de (en geplant) | ja | CPython 3.14: venv, pip, tkinter |
| go | `book-go/Go-de/` | de (en geplant) | ja | Go 1.27.2: Modul, Build, Test |
| python3-uv | `book-python3-uv/Python3-uv-de/` | de (en geplant) | ja | uv 0.13.0: Projekt, Lock, Tool |
| python3-tkinter | `book-python3-tkinter/Python3-Tkinter-de/` | de (en geplant) | ja | tkinter: Tk 8.6.18, python3-tk 3.14.7-3 |
| rl_json | `book-rl_json/rl_json-de/` | de (en geplant) | ja | rl_json 0.16: JSON als eigener Typ |
| tcl-metaprogramming | `book-tcl-metaprogramming/Tcl-Metaprogramming-de/` | de (en geplant) | ja | list, eval, uplevel, apply |
| rustdesk | `book-rustdesk/RustDesk-de/` | de (en geplant) | ja | RustDesk: ID, Self-Host, Relay |
| tcl-rest | `book-tcl-rest/Tcl-Rest-de/` | de (en geplant) | ja | Tcl REST-Client: http, tls, JSON |
| zertifikate | `book-zertifikate/Zertifikate-de/` | de (en geplant) | ja | X.509, interne CA, Let's Encrypt (HTTP-01/TLS-ALPN/DNS-01) |
| tcltk-datenbank | `book-TclTk-und-Datenbank/TclTk-und-Datenbank-de/` | de | ja | bestehendes Handbuch: TDBC, SQLite, PostgreSQL, Oratcl; HTML und PDF |
| tcltk-benutzeroberflaechen | `book-TclTk-Benutzeroberflaechen/Benutzeroberflaechen-de/` | de | ja | bestehendes Handbuch: Desktop-GUI, ttk, Layout |
| ttk | `book-ttk/Ttk-de/` | de (en geplant) | ja | Werkzeugbuch: ttk Styles und Themes |
| tcltk-softwaredesign | `book-tcltk-softwaredesign/Softwaredesign-de/` | de (en geplant) | ja | Werkzeugbuch: Tcl/Tk Softwaredesign (Serie) |
| thread-coroutine-interp | `book-thread-coroutine-interp/Thread-Coroutine-Interp-de/` | de (en geplant) | ja | Werkzeugbuch: Eventloop, Coroutine, Interp, Thread, TclOO-Async |
| tdom | `book-tdom/tdom-de/` | de (en geplant) | ja | tdom 0.9.6: XML DOM |
| pdf-werkzeuge | `book-pdf-werkzeuge/Pdf-Werkzeuge-de/` | de (en geplant) | ja | PDF-CLI: qpdf, Poppler, Ghostscript, OCR |
| bind | `book-bind/Tk-Bind-de/` | de (en geplant) | ja | Tk bind, bindtags, break und Fokus |
| encoding | `book-encoding/Encoding-de/` | de (en geplant) | ja | Encoding, TIP 656, Windows cp1252 |
| ssh | `book-ssh/Ssh-de/` | de (en geplant) | ja | OpenSSH: Login, Schlüssel, Tunnel, sftp |
| rclone | `book-rclone/Rclone-de/` | de (en geplant) | ja | rclone 1.69.3: Cloud- und lokale Remotes |
| rsync | `book-rsync/Rsync-de/` | de (en geplant) | ja | rsync 3.5.0: Delta-Kopie, SSH, --delete |
| docker | `book-docker/Docker-de/` | de (en geplant) | ja | Docker: Compose, Inspect, Netz |
| kopia | `book-kopia/Kopia-de/` | de (en geplant) | ja | Kopia: Snapshot-Backup, Repository |
| ugreen-dxp2800 | `book-ugreen-dxp2800/Ugreen-Dxp2800-de/` | de (en geplant) | ja | UGREEN DXP2800: NAS-Rollenhandbuch |
| nginx | `book-nginx/Nginx-de/` | de (en geplant) | ja | nginx: Reverse-Proxy, TLS, auth_basic; mdserver 0.4 |
| tkcon | `book-tkcon/Tkcon-de/` | de (en geplant) | ja | tkcon 2.8: Enhanced Tk Console |
| proxmox-lxc-nginx | `book-proxmox-lxc-nginx/Proxmox-Lxc-Nginx-de/` | de (en geplant) | ja | PVE-LXC: Samba, mdserver 0.4 hinter nginx |
| proxmox-lxc-nginx-samba-mdserver-firewall-installation | `book-proxmox-lxc-nginx-samba-mdserver-firewall-installation/Dokumentenserver-LAN-de/` | de (en geplant) | ja | Geschlossenes Installationsbuch: LXC, Samba, mdserver 0.4, nginx, Firewall |
| sqlite3 | `book-sqlite3/Sqlite3-de/` | de (en geplant) | ja | SQLite: tdbc::sqlite3 1.1.14, sqlite3 3.53.4, sqlite3mc 3.51.0 |
| postgresql | `book-postgresql/Postgresql-de/` | de (en geplant) | ja | PostgreSQL: tdbc::postgres 1.1.14 |
| oracle | `book-oracle/Oracle-de/` | de (en geplant) | ja | Oracle: Oratcl 4.6.1, Instant Client 19.25 |
| nginx-proxy-manager | `book-nginx-proxy-manager/Nginx-Proxy-Manager-de/` | de (en geplant) | ja | Nginx Proxy Manager: GUI, Port 81, OpenResty |
| openresty | `book-openresty/Openresty-de/` | de (en geplant) | ja | OpenResty: nginx plus LuaJIT |
| pgrest | `book-pgrest/Pgrest-de/` | de (en geplant) | ja | PostgREST: HTTP-JSON über PostgreSQL |
| tinventar | `book-tinventar/Tinventar-de/` | de (en geplant) | ja | Betriebsbuch: tinventar 9.53.2, Schema 19 |
| bookkit | `book-bookkit/Bookkit-de/` | de, en | ja | Werkzeugbuch: Format, Build, Prüfung |
| mdstack | `book-mdstack/Mdstack-de/` | de (en geplant) | ja | Werkzeugbuch: Parser 0.8.0, HTML 0.2, PDF 0.3, Viewer 0.4 |
| mdserver | `book-mdserver/Mdserver-de/` | de (en geplant) | ja | Werkzeugbuch: mdserver 0.4 |
| docir | `book-docir/Docir-de/` | de (en geplant) | ja | Werkzeugbuch: docir 0.1.1, pdf 0.5 |
| tcltk9.1 | `book-tcltk9.1/TclTk-9.1-de/` | de (en geplant) | ja | Lehrbuch: Tcl/Tk 9.1.0 gegen 9.0 |
| tcltk9.0-bauen | `book-tcltk9.0-bauen/TclTk-9.0-Bauen-de/` | de (en geplant) | ja | Werkzeugbuch: 9.0.4 Prefix, Unix gemessen, Windows und macOS aus den READMEs |
| tcltk9.1-bauen | `book-tcltk9.1-bauen/TclTk-9.1-Bauen-de/` | de (en geplant) | ja | Werkzeugbuch: 9.1.0 Prefix, Unix, Windows, macOS |
| tcl-stubs-abi | `book-tcl-stubs-abi/Stubs-und-Abi-de/` | de (en geplant) | ja | Werkzeugbuch: Stubs, ABI, 8.6.14/9.0.4 gemessen |
| tcl-ausliefern | `book-tcl-ausliefern/Ausliefern-de/` | de (en geplant) | ja | Werkzeugbuch: Kits, zipfs, deb/rpm, 8.6.14/9.0.4 |
| tcl-erweiterungen | `book-tcl-erweiterungen/Erweiterungen-de/` | de (en geplant) | ja | Werkzeugbuch: C-API, critcl, cffi, 9.0.4 gemessen; Langform critcl ist book-critcl |
| critcl | `book-critcl/Critcl-de/` | de (en geplant) | ja | critcl 3.3.1; serie-critcl 8/8, Tcl 8.6.18, gcc, 2026-10-21 |
| kettle | `book-kettle/Kettle-de/` | de (en geplant) | ja | kettle 1.1 aus bibliosrc; serie-kettle 8/8, Tcl 8.6.18, 2026-10-21; kein install |
| tcl-testen | `book-tcl-testen/Testen-de/` | de (en geplant) | ja | Werkzeugbuch: tcltest 2.5.11, nagelfar, doctools |
| printing | `book-printing/Printing-de/` | de (en geplant) | ja | Werkzeugbuch: tk print, PDF-Pipeline, CUPS, Windows |
| printlib | `book-printlib/Printlib-de/` | de (en geplant) | ja | Werkzeugbuch: printlib 0.3.1 |
| brother-ql | `book-Brother-QL-Buch/Brother-QL-de/` | de (en geplant) | ja | Werkzeugbuch: Brother QL, b-PAC, twapi, CUPS |
| package-module | `book-package-module/Package-Module-de/` | de (en geplant) | ja | Werkzeugbuch: package, pkgIndex, .tm |
| tclutils | `book-tclutils/Tclutils-de/` | de (en geplant) | ja | Werkzeugbuch: tclutils 0.66.0 |
| tkutils | `book-tkutils/Tkutils-de/` | de (en geplant) | ja | Werkzeugbuch: tkutils 0.47.0 |
| utils-stack | `book-utils-stack/Utils-Stack-de/` | de (en geplant) | ja | Werkzeugbuch: Zusammenspiel tclutils 0.66.0, tkutils 0.47.0, ctrlutils 0.4 |
| my-book | `bookkit/template/my-book/` | de, en | ja | Referenz im Template |

Spalten:

- **Sprachen** — vorhandene Übersetzungen (ISO 639-1); geplante in Klammern.
- **book.tcl** — Manifest vorhanden?
- **Anmerkung** — Reifegrad, Besonderheiten.

Neues Buch registrieren: Zeile ergänzen, sobald `book.tcl` steht und das Buch
mindestens einmal fehlerfrei gebaut wurde.
