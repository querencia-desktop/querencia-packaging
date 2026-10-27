# Querencia Packaging

Debian-Paketierung, APT-Quelle und CI-Vorlagen für
[Querencia Desktop](https://github.com/querencia-desktop/querencia) – einer
klassischen Desktopumgebung im GNOME-2-Stil für Wayland (labwc, Rust, GTK 4).

> **Status: Alpha 3.3 (27.10.2026, Satz `debs-alpha33-2`, unveröffentlicht): fünf
> Sprachen.** Alle Programme sprechen Deutsch, Englisch, Italienisch, Spanisch und
> Französisch (noch fest deutsch: Sperrbildschirm, Fenster des Lautstärkereglers,
> Tastenkürzel); der Anmeldebildschirm durchgehend Deutsch oder Englisch; das Panel hat
> einen Infobereich (Panel 0.4.0); das Metapaket empfiehlt `locales-all`. Veröffentlicht in der APT-Quelle ist Alpha 3.2
> (26.10.2026). 24 Pakete aus 24 Quellpaketen bauen lokal mit `dpkg-buildpackage`;
> geprüft statisch, in einer Wegwerf-Installation (auch mit `LANG=it_IT.UTF-8`) und
> mit Upgrade-Proben. Signatur und Upload macht der Betreuer der Quelle
> ([docs/apt-quelle.md](docs/apt-quelle.md)).

## Inhalt

```
quellen.conf                 Quellpaket → Repository → Commit → Version
common/querencia.mk          gemeinsames debian/rules-Fragment (ohne debhelper)
common/metainfo/             MetaInfo aller Komponenten (aus querencia-software)
querencia-shell/             Panel, Desktop, Lautstärke, Netzwerk, Tastenkürzel, Theme
querencia-session/           Sitzungsstarter und labwc-Konfiguration (Architecture: all)
querencia-sitzung/           Sitzungsdialog, Bildschirmsperre, polkit-Agent
querencia-anmeldung/         Anmeldebildschirm (greetd, ReGreet)
querencia-archiv/            Archivverwaltung
querencia-dokumente/         PDF-Betrachter
querencia-hintergruende/     Hintergrundbilder (Architecture: all)
querencia-benachrichtigungen/ Benachrichtigungsdienst
querencia-einstellungen/     Einstellungen (Kontrollzentrum)
querencia-dateien/           Dateimanager Querencia Dateien (Quelle: querencia-shell)
querencia-files/             Übergangspaket seit Alpha 3: nur Brücken-Starter auf Dateien
querencia-terminal/          Terminal (noch alte App-ID)
querencia-screenshot/        Bildschirmfoto
querencia-editor/            Texteditor (gettext: de, en, it, es, fr)
querencia-bilder/            Bildbetrachter
querencia-rechner/           Taschenrechner
querencia-systemmonitor/     Systemüberwachung
querencia-dateisuche/        Dateisuche
querencia-software/          Software-Verwaltung (mit Bausteinen, komponenten.conf)
querencia-symbole/           eigene Programmsymbole (Architecture: all)
querencia-desktop/           Metapaket (zieht alles außer den Zusatzpaketen)
querencia-schnatter/         Zusatzpaket, optional (nicht im Metapaket): Schnatter,
                             WhatsApp Web als eigenes Fenster (Quelle:
                             querencia-schnatter, Runtime als Komponente)
querencia-webhuelle/         Übergangspaket (ab 0.3.0) auf querencia-schnatter
backports/labwc/             labwc 0.9.8 für Ubuntu 26.04
apt/                         Eintrag für die APT-Quelle (querencia.sources)
werkzeuge/                   orig-erzeugen, paket-bauen, alle-bauen, pakete-pruefen,
                             copyright-erzeugen, apt-quelle-erzeugen/-testen,
                             veroeffentlichung-pruefen
tests/                       Prüfskript frische VM, Wegwerf-Installation und -Upgrade
ci/                          GitHub-Actions-Vorlagen (nicht aktiv)
docs/                        Bauen, Prüfen, Pflichtprobe, öffentliche Quellen
```

Erzeugnisse gehen nach `build/` (nicht in Git).

## Quellen der Pakete

`quellen.conf` nennt die Commit-Hashes der Arbeitsrepos; die öffentlichen Repos
tragen dieselben Tags, ihre Historie ist bereinigt, die Hashes weichen ab. Die
Spalte `<repository>` nennt die öffentlichen Repo-Namen: Ein Bau aus diesem Repo
setzt die Quellrepos als Geschwisterordner unter diesen Namen voraus und braucht
statt der Hashes die Tags. Zuordnung Paket → öffentliches Repo → Tag:
[docs/quellen-oeffentlich.md](docs/quellen-oeffentlich.md). Das Metapaket
`querencia-desktop` hat kein eigenes Repo; seine Paketierung ist nur in diesem
Packaging-Repo enthalten.

## Lizenz

GPL-3.0-or-later (Paketierung und Werkzeuge), siehe [LICENSE](LICENSE).
Copyright 2026 Querencia Desktop contributors; Urheberhinweis in
[COPYRIGHT](COPYRIGHT). Die Lizenzen der paketierten Programme stehen in ihren
`debian/copyright`.

Name und Logo „Querencia“ sind keine freien Inhalte: [MARKE.md](MARKE.md).

## Fehler melden

Fehler, Wünsche und Fragen zu Querencia gehen an die gemeinsame Meldestelle:
<https://github.com/querencia-desktop/querencia/issues/new/choose>.
Sicherheitslücken bitte nicht öffentlich melden, siehe [SECURITY.md](SECURITY.md).
