# Versionsdatei Querencia Desktop (ab Alpha 2.1)

Festgelegt 22.10.2026 für Alpha 2.1; erzeugt in `querencia-desktop/debian/rules` (Variable `AUSGABE`, `VERSION_ID` = Upstream-Version des Metapakets).

## Pfade und Paket

| Datei | Inhalt | Paket |
|---|---|---|
| `/usr/share/querencia/version` | genau eine Zeile, Anzeigename der Ausgabe | `querencia-desktop` (Metapaket, Architecture: all) |
| `/usr/share/querencia/release` | Schlüssel-Wert-Zeilen im Format von os-release(5) | `querencia-desktop` |

Beide Dateien liegen unter `/usr` (keine conffiles, nicht vom Benutzer zu ändern) und
werden bei jeder Ausgabe mit dem Metapaket neu geliefert.

## Inhalt Alpha 2.1

`/usr/share/querencia/version` (UTF-8, eine Zeile mit abschließendem Zeilenumbruch):

```
Alpha 2.1
```

`/usr/share/querencia/release`:

```
NAME="Querencia Desktop"
VERSION="Alpha 2.1"
VERSION_ID="0.1.0~alpha2.1"
HOME_URL="https://querencialinux.org"
BUG_REPORT_URL="https://github.com/querencia-desktop/querencia/issues"
DOCUMENTATION_URL="https://querencialinux.org/de/docs/"
```

## Format (verbindlich für Leser)

- `version`: erste Zeile lesen, Leerraum am Rand abschneiden. Der Text ist zum Anzeigen
  gedacht („Querencia Desktop Alpha 2.1“ setzt der Leser selbst zusammen), nicht zum Vergleichen.
- `release`: Syntax wie os-release(5): je Zeile `SCHLÜSSEL="Wert"`, Werte in doppelten
  Anführungszeichen, keine Shell-Erweiterung. Leser überspringen leere Zeilen und Zeilen
  mit `#` und ignorieren unbekannte Schlüssel (es können später weitere dazukommen,
  z. B. `VERSION_CODENAME`). Anführungszeichen entfernen; `\"`, `\\`, `` \` ``, `\$` sind
  die einzigen Escapes (kommen derzeit nicht vor). Ohne Anführungszeichen ist ein Wert
  ebenfalls gültig.
- `VERSION` = Inhalt von `version`; `VERSION_ID` = Upstream-Version des Metapakets im
  Debian-Format (mit `~`), zum Vergleichen nur über dpkg-Regeln, nicht als SemVer.
- URLs: `HOME_URL` für „Webseite“, `BUG_REPORT_URL` für „Fehler melden“,
  `DOCUMENTATION_URL` für „Hilfe/Dokumentation“ (deutsche Doku; eine englische Seite ist
  `https://querencialinux.org/en/docs/`, wenn der Leser nach Sprache wählen will).

## Fehlen der Dateien

Die Dateien fehlen, wenn das Metapaket nicht installiert ist (einzelne Pakete, Live-Stand
der Entwicklungsumgebung, Bau aus dem Quellbaum). Leser müssen das ohne Fehler hinnehmen:

1. `release` lesbar → `VERSION` (und URLs) daraus;
2. sonst `version` lesbar → erste Zeile;
3. sonst keine Ausgabe anzeigen (oder „Entwicklungsstand“), URLs aus eigenen Konstanten.

Keine Umgebungsvariable, kein anderer Suchpfad (kein `/etc/querencia/…`).

## Für Panel und Einstellungen

- Info-Dialog Panel („Über Querencia“) und Einstellungen („Über dieses System“) lesen
  `release` (Reihenfolge oben). Die eigene Programmversion bleibt `CARGO_PKG_VERSION`.
- Testen ohne Paket: eine Kopie der Datei oben in einen Test-Ordner legen und den Pfad nur
  im Test umlenken; im Programm ist der Pfad fest `/usr/share/querencia/release`.
