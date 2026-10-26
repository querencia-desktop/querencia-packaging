# Querencia Packaging

Debian-Paketierung, APT-Quelle und CI-Vorlagen für Querencia Desktop.

> **Status: Alpha 3.2 (26.10.2026, Satz `debs-alpha32-1`, unveröffentlicht).**
> Veröffentlicht in der APT-Quelle ist Alpha 3.1 (24.10.2026). 24 Pakete aus 24
> Quellpaketen bauen lokal mit `dpkg-buildpackage`; geprüft statisch, in einer
> Wegwerf-Installation und mit Upgrade-Proben. Signatur und Upload macht der
> Betreuer der Quelle ([docs/apt-quelle.md](docs/apt-quelle.md)).

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
querencia-files/             Übergangspaket seit Alpha 3: nur Brücken-Starter auf Dateien
querencia-terminal/          Terminal (noch alte App-ID)
querencia-screenshot/        Bildschirmfoto
querencia-editor/            Texteditor (gettext, de)
querencia-bilder/            Bildbetrachter
querencia-rechner/           Taschenrechner
querencia-systemmonitor/     Systemüberwachung
querencia-dateisuche/        Dateisuche
querencia-software/          Software-Verwaltung (mit Bausteinen, komponenten.conf)
querencia-symbole/           eigene Programmsymbole (Architecture: all)
querencia-desktop/           Metapaket (zieht alles; querencia-schnatter als Recommends)
querencia-schnatter/         Schnatter, WhatsApp Web als eigenes Fenster (aus
                             querencia-nachrichten, Runtime als Komponente);
                             ab Alpha 3.2 vom Metapaket empfohlen, entfernbar
querencia-webhuelle/         Übergangspaket (ab 0.3.0) auf querencia-schnatter
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
