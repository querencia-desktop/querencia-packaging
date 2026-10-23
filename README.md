# Querencia Packaging

Debian-Paketierung, APT-Quelle und CI-Vorlagen für Querencia Desktop.

> **Status: Alpha 2 (G2-F, 20.10.2026).** 17 Quellpakete auf dem Live-Stand
> der Entwicklungs-VM bauen lokal mit `dpkg-buildpackage`; geprüft statisch
> und in einer Wegwerf-Installation. Nichts ist veröffentlicht oder signiert;
> die Pflichtprobe auf einer frischen VM steht aus.

## Inhalt

```
quellen.conf                 Quellpaket → Repository → Commit → Version
common/querencia.mk          gemeinsames debian/rules-Fragment (ohne debhelper)
common/metainfo/             MetaInfo aller Komponenten (aus querencia-software-paket)
querencia-shell/             Panel, Desktop, Lautstärke, Netzwerk, Tastenkürzel, Theme
querencia-session/           Sitzungsstarter und labwc-Konfiguration (Architecture: all)
querencia-sitzung/           Sitzungsdialog, Bildschirmsperre, polkit-Agent
querencia-benachrichtigungen/ Benachrichtigungsdienst
querencia-einstellungen/     Einstellungen (Kontrollzentrum)
querencia-dateien/           Dateimanager Querencia Dateien (aus querencia-runtime)
querencia-files/             früherer Dateimanager, Übergang zu Dateien (ohne UnRAR)
querencia-terminal/          Terminal (noch alte App-ID)
querencia-screenshot/        Bildschirmfoto
querencia-editor/            Texteditor (gettext, de)
querencia-bilder/            Bildbetrachter
querencia-rechner/           Taschenrechner
querencia-systemmonitor/     Systemüberwachung
querencia-dateisuche/        Dateisuche
querencia-software/          Software-Verwaltung (mit Bausteinen, komponenten.conf)
querencia-symbole/           eigene Programmsymbole (Architecture: all)
querencia-desktop/           Metapaket (zieht alles)
backports/labwc/             labwc 0.9.8 für Ubuntu 26.04
werkzeuge/                   orig-erzeugen, paket-bauen, alle-bauen, pakete-pruefen,
                             copyright-erzeugen, apt-quelle-erzeugen/-testen,
                             veroeffentlichung-pruefen
tests/                       Prüfskript frische VM, Wegwerf-Installation und -Upgrade
ci/                          GitHub-Actions-Vorlagen (nicht aktiv)
docs/                        Bauen, Prüfen, Pflichtprobe
```

Die Repositories der Komponenten liegen neben diesem Repository (Spalte
`<repository>` in `quellen.conf`); Erzeugnisse gehen nach `build/` (nicht in
Git).

Anleitung: [docs/building.md](docs/building.md),
[docs/testing.md](docs/testing.md),
[docs/pflichtprobe-frische-vm.md](docs/pflichtprobe-frische-vm.md).

## Lizenz

GPL-3.0-or-later (Paketierung und Werkzeuge), siehe [LICENSE](LICENSE).
