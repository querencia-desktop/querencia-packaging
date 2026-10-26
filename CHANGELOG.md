# Änderungen – querencia-packaging

## Alpha 3.2 – Satz debs-alpha32-1 vom 26.10.2026 (Pflegestand), unveröffentlicht

Gegenüber Alpha 3.1 (veröffentlicht, `debs-alpha31-1`); 24 Pakete, 2 neu gebaut, 2 aus dem
Zweig schnatter-paket übernommen, 20 byte-gleich.

- querencia-dateien 0.2.2-1 aus runtime `dateien/0.2.2` (`73ef2b5`, mit querencia-oberflaeche
  0.1.1): Kontextmenüs springen nicht mehr in die Menüleiste (QD-176); das Netzwerkfenster heißt
  „Netzwerk“ (QD-173 P-4); Handbuchseite und MetaInfo 0.2.2 (230 Tests beim Bau). Panel und
  Desktop in querencia-shell bleiben auf `801a016` (kein Neubau, siehe
  `docs/dateien-nachziehen.md` §6).
- querencia-schnatter 0.3.0-1 und Übergangspaket querencia-webhuelle 0.3.0-1 unverändert aus
  `build/schnatter-1` des Zweigs schnatter-paket (`5233329`); Quellarchive neu erzeugt und
  byte-gleich.
- querencia-desktop 0.1.0~alpha3.2-1: nur Version, Versionsdatei „Alpha 3.2“ und Changelog.
  Schnatter bleibt optional, nicht im Metapaket (Entscheidung 24.10., bestätigt 26.10.2026); wer
  die Webhülle 0.2.0 hat, bekommt es mit dem Übergangspaket querencia-webhuelle 0.3.0-1.
- `tests/wegwerf-upgrade.sh`: Files-Einstellungen am Pfad des alten Files (QD-172 T-2);
  Webhülle 0.2.0 mit Ordnern am echten Pfad, Übergang auf Schnatter, Umzug beim Start;
  Neuinstallation zieht Schnatter nur, wenn das Metapaket es nennt; Schnatter entfernbar, apt
  holt es nicht wieder; Übergangspakete zuerst für `dpkg -i`.
- `tests/frisches-ubuntu-pruefen.sh`: behaltene Ordnerwahl aus Files (Brücke) gilt als PASS mit
  Hinweis (QD-172 T-1); Prüfpunkte A32 für Schnatter (wenn installiert).

## Zusatzpaket querencia-schnatter 0.3.0-1 vom 26.10.2026 (Zweig schnatter-paket), unveröffentlicht

- Neues Quellpaket **querencia-schnatter** (Section net, optional, nicht im Metapaket): Schnatter
  0.3.0, so heißt Querencia Webhülle jetzt, aus `querencia-nachrichten` Tag `schnatter/0.3.0`
  (`6cd0ce4`), Runtime-Komponente `6935c48` (querencia-oberflaeche 0.1.1, live mit Dateien 0.2.2),
  41 Tests beim Bau. Breaks/Replaces `querencia-webhuelle (<< 0.3.0~)` und
  `querencia-nachrichten`, Provides beide. Den Umzug der Ordner `querencia-webhuelle` bzw.
  `querencia-nachrichten` macht das Programm beim ersten Start (keine Paketskripte, die
  Benutzerordner anfassen).
- **querencia-webhuelle** 0.3.0-1 ist ein Übergangspaket (Section oldlibs, Architecture all,
  Depends `querencia-schnatter`), Muster querencia-files: bringt Schnatter mit `apt upgrade`,
  behält den Starter `org.querencia.Webhuelle.desktop` versteckt als Brücke auf Schnatter.
- `tests/wegwerf-upgrade-schnatter.sh`: Upgrade Webhülle 0.2.0-1 → Schnatter mit den Ordnern
  der Webhülle am echten Pfad (Lehre QD-172), apt-Simulation, erster Start ohne Bildschirm.
- `werkzeuge/pakete-pruefen.sh`: querencia-webhuelle als Übergangspaket ohne MetaInfo-Pflicht.
- Gebaut in `build/schnatter-1/`; der Satz Alpha 3.2 ist ein eigener Auftrag.

## Alpha 3.1 – Satz debs-alpha31-1 vom 24.10.2026 (Pflegestand), unveröffentlicht

Gegenüber Alpha 3 (veröffentlicht, `debs-beta-3`); 23 Pakete, 3 neu gebaut, 20 byte-gleich.

- querencia-dateien 0.2.1-1 aus runtime `dateien/0.2.1` (`21399c1`): der erste Start übernimmt die
  Einstellungen von Files auch aus `~/.config/strata/` (Upgrade von Alpha 2.1); Handbuchseite und
  MetaInfo 0.2.1 (228 Tests beim Bau).
- Neu und optional (nicht im Metapaket): querencia-webhuelle 0.2.0-1 aus querencia-nachrichten
  `webhuelle/0.2.0` (`131304f`), Zweig `webhuelle-paket` gemergt (Rezept des Workers unverändert;
  Quellarchive byte-gleich mit dessen Bau, 39 Tests).
- querencia-desktop 0.1.0~alpha3.1-1: Versionsdatei „Alpha 3.1“, Dateien ≥ 0.2.1.
- `tests/wegwerf-upgrade.sh`: `UPGRADE_NEU`, `UPGRADE_FILES_ORDNER` (Files-Einstellungen unter
  `strata/`), Files-Übergangspaket gleicher Version bleibt, übernommene Werte in `dateien.ini`.

## Zusatzpaket querencia-webhuelle 0.2.0-1 vom 24.10.2026 (Zweig webhuelle-paket), unveröffentlicht

- Neues Quellpaket **querencia-webhuelle** (Section net): Querencia Webhülle 0.2.0, eine Hülle
  für WhatsApp Web, aus `querencia-nachrichten` Tag `webhuelle/0.2.0` (`131304f`). Bis 0.1.1 hieß
  das Programm Querencia Nachrichten und war nie paketiert. **Optional:** nicht im Metapaket
  `querencia-desktop`; der nächste Satz nimmt es als eigenes Paket auf.
- Wie querencia-software mit `komponenten.conf`: Programm im Unterordner `querencia-webhuelle/`,
  der Runtime-Workspace (`801a016`, Quelle der Shell aus Alpha 3) als zweites Upstream-Archiv
  daneben, weil die Bibliotheken `querencia-oberflaeche` und `querencia-dateiarbeit`
  Cargo-Pfadabhängigkeiten sind; Prüfwerkzeuge, Doku, Hintergründe, Thema und Sitzungsdateien
  nicht im Quellarchiv.
- `Depends` nur aus den Bibliotheken (libwebkitgtk-6.0-4 bringt bubblewrap und xdg-dbus-proxy
  für WebKits Sandbox mit); `Recommends: querencia-shell` (Katalog `querencia-oberflaeche`),
  Wörterbücher; nur der eigene Katalog, eigenes Symbol in hicolor (nur SVG), MetaInfo aus der
  Quelle (`<replaces>` org.querencia.Nachrichten), Handbuchseite; 39 Tests beim Bau.
- Gebaut in `build/webhuelle-1/` (nicht im Satz debs-beta-3).

## Alpha 3 – Beta-Satz debs-beta-2 vom 24.10.2026 (Zweig dateien-beta), unveröffentlicht

Ersetzt debs-beta-1 (Tag `packaging/alpha3-1`, nicht veröffentlichen). Dazu gegenüber debs-beta-1:

- querencia-session 0.1.0~alpha10-1 aus `session/alpha10` (`0fc200f`): das Ordnerprogramm Dateien steht
  in der Quelle (seit alpha9), Patch 0002 entfällt; Software-OpenGL bei zink auf NVK (QD-169), Conffile
  `autostart` geändert; Recommends querencia-sitzung (>= 0.1.8); Patch 0001 (Archiv/SVG) auf die neue
  Zeile gesetzt.
- querencia-sitzung 0.1.8-1 aus `sitzung/0.1.8` (`27fd8ac`): polkit-Agent nach einem Neustart von
  polkitd, `--grafik-pruefen`.
- querencia-desktop 0.1.0~alpha3-1 neu gebaut: Session ≥ 0.1.0~alpha10, Sitzung ≥ 0.1.8.

### Beta-Satz debs-beta-1 (ersetzt)

Querencia Dateien 0.2.0 ins System, Querencia Files ausgemustert. Grundlage: Vorbau vom
23.10. (`build/debs`); 22 Pakete, davon 4 neu gebaut, 18 unverändert übernommen.

- querencia-shell 0.1.0~alpha10-1 aus runtime main `801a016` (Panel 0.3.2 mit Orte-Menü für
  Dateien, Arbeitsfläche 0.3.0 mit Dateiarbeit, Kürzel-Übersicht 0.2.2 mit Block „Querencia
  Dateien“). Baut und testet nur die fünf Shell-Crates (`cargo -p`); besitzt jetzt die Kataloge
  `querencia-oberflaeche` und `querencia-dateiarbeit` (`Replaces`/`Breaks: querencia-dateien (<<
  0.2.0)`); Symbole ≥ 0.8; Prüfrahmen von Dateien nicht im Quellarchiv; Patch 0001 auf die neue
  Zeile gesetzt.
- querencia-dateien 0.2.0-1 aus runtime `dateien/0.2.0` (`3facb50`): Reiter, Kompaktansicht,
  Netzwerk, Miniaturen, Suche. `MimeType=inode/directory` kommt upstream (desktop-file-edit
  entfällt), `Depends: querencia-shell (>= 0.1.0~alpha10)`, `Recommends: bubblewrap`,
  `Suggests: querencia-dateisuche`; nur noch der eigene Katalog; Handbuchseite und MetaInfo
  (`<release>` 0.2.0) nachgezogen; der PDF-Stellvertreter `werkzeug/miniaturen/qd-pdf-miniatur`
  bleibt als Test-Eingabe im Quellarchiv (227 Tests beim Bau).
- querencia-files 0.2.0-1: **Übergangspaket** (Section oldlibs, Architecture all) aus dem
  Projekt-Repository wie das Metapaket, nur die zwei Brücken-Starter auf Dateien
  (`TryExec=querencia-dateien`, `StartupWMClass=org.querencia.Dateien`), `Depends:
  querencia-dateien (>= 0.2.0)`. Kein Strata-Code, kein Files-Quellarchiv, keine MetaInfo
  (`common/metainfo/org.querencia.Files.metainfo.xml` entfernt; `pakete-pruefen.sh` nimmt das
  Übergangspaket von Regel M aus).
- querencia-desktop 0.1.0~alpha3-1 (neu gebaut, gleiche Version wie im unveröffentlichten
  Vorbau): Shell ≥ 0.1.0~alpha10, Dateien ≥ 0.2.0.
- Unverändert aus dem Vorbau: Session 0.1.0~alpha8-2 (Patch 0002), Symbole 0.8-1, Dateisuche
  0.1.5-2; die übrigen 15 aus Alpha 2.2 Kandidat 2.
- `tests/wegwerf-upgrade.sh`: `apt upgrade` neben `full-upgrade`, Übergangspaket ohne Reste von
  Files, keine verwaisten Starter oder mimeapps-Einträge, autoremove behält die Brücken,
  `UPGRADE_VORHER_ORDNER` für Upgrades von Alpha 2.1. `tests/frisches-ubuntu-pruefen.sh` auf
  Alpha 3 (Dateien, Symbole 0.8, Kataloge, Brücken). `alle-bauen.sh`, `docs/building.md`,
  `ci/paket.yml` ohne Fremd-Toolchain für Files.

## Welle C „Dateien“ – Satz vom 23.10.2026 (Zweig dateien-beta), unveröffentlicht

Querencia Dateien als Paket und Ablösung von Querencia Files (Migration M2, M4, M5, M7).
Grundlage Alpha 2.2 Kandidat 2; 22 Pakete, davon 6 neu gebaut.

- Neu: querencia-dateien 0.1.0-1 aus querencia-runtime `dateien/0.1.0-2` (`f9a3cda`), gebaut
  mit `cargo -p` für Dateien und seine Bibliotheken querencia-dateiarbeit und
  querencia-oberflaeche (167 Tests beim Bau). Starter mit `MimeType=inode/directory`,
  hicolor-SVG, drei gettext-Kataloge (dateien, oberflaeche, dateiarbeit), MetaInfo
  `org.querencia.Dateien` (`<replaces>` org.querencia.Files), Handbuchseite
  querencia-dateien(1), copyright mit den MIT-Teilen aus Files.
- querencia-symbole 0.8-1 (`symbole/0.8` = `26c830b`): Programmsymbol Dateien im Thema
  (723 Dateien), byte-gleich mit der geprüften Vorlage.
- querencia-files 0.1.0~alpha8-2 (Quelle unverändert): beide Starter sind versteckte Brücken
  ohne MIME-Typen auf `querencia-dateien %U` (M4, M5), Depends querencia-dateien,
  Übergangstext in Beschreibung, README.Debian und MetaInfo (ohne inode/directory).
- querencia-session 0.1.0~alpha8-2: Patch 0002, `inode/directory=org.querencia.Dateien.desktop`
  in x-querencia-mimeapps.list, Test der Quelle angepasst (75/0); Recommends querencia-dateien
  statt querencia-files.
- querencia-dateisuche 0.1.5-2 (Quelle unverändert): Recommends querencia-dateien statt
  querencia-files, damit eine Neuinstallation Files nicht mehr über Empfehlungen zieht; neu
  vendort ohne das gettext-Archiv (QD-139), Binary bis auf die eingebaute Paketversion gleich.
- querencia-desktop 0.1.0~alpha3-1: Depends querencia-dateien statt querencia-files (M7),
  Symbole ≥ 0.8, Session ≥ 0.1.0~alpha8-2, Versionsdatei „Alpha 3“.
- `tests/wegwerf-upgrade.sh`: Upgrade-Probe in der Wegwerf-Hülle (alter Satz, Probe-Benutzer,
  apt-Simulation von Upgrade und Neuinstallation, dpkg-Upgrade, Ordnerprogramm, Files-Starter,
  Lesezeichen, autoremove, danach die volle Sitzungsprüfung).
- `tests/wegwerf-installation.sh`: der Dunkeltest löscht nur noch `settings.ini` statt der
  ganzen Ordner `~/.config/gtk-3.0` und `gtk-4.0` (Lesezeichen im Probe-Home bleiben).
- `docs/dateien-nachziehen.md`: Nachzieh-Weg für den Beta-Stand von Dateien, geteilte Kataloge
  bei einem Shell-Neubau aus runtime main, Entfernen von Files.

## Alpha 2.2 – Kandidat 2 vom 23.10.2026, unveröffentlicht

Kandidat 1 plus Sitzung 0.1.7 und QD-139.

- querencia-sitzung 0.1.7-1 aus main `3775597` (Code wie Tag `sitzung/0.1.7` = `e63e935`):
  „Ausschalten …“ mit „Neu starten“. Metapaket verlangt querencia-sitzung (>= 0.1.7).
- QD-139: Das Quellarchiv von GNU gettext, das der Crate `gettext-sys` mitbringt, wird beim
  Vendoren entfernt (`common/fremdarchive.conf`, `werkzeuge/fremdarchive-entfernen.py`, Eintrag in
  `.cargo-checksum.json` gestrichen, Paketprüfsumme bleibt). Die Pakete bauen gettext-sys mit
  `gettext-system` und brauchen es nie. Das copyright nennt die Entfernung am Absatz des Crates,
  `debian/README.source` (Shell, Einstellungen, Sitzung) erklärt sie.
- `werkzeuge/copyright-erzeugen.py` bricht bei einem unbekannten gebündelten Archiv ab, das
  keine kleine Testdatei ist; `werkzeuge/pakete-pruefen.sh` öffnet die Quellarchive jedes Pakets
  (`QUERENCIA_ORIG_DIRS`) und meldet ein Fremdarchiv in `cargo-vendor` als FAIL.
- Ablauf: erzeugte `upstream-commit`/`copyright` werden vor dem Tag committet.

## Alpha 2.2 – Kandidat 1 vom 22.10.2026, unveröffentlicht

Welle Alpha 2.2 aus den Hauptzweigen (Stand der Entwicklungsumgebung).

- querencia-desktop 0.1.0~alpha2.2-1: Versionsdatei „Alpha 2.2“, Mindestversionen.
- querencia-shell 0.1.0~alpha9-1 aus querencia-runtime main `a1b3e53` (Panel 0.3.0,
  Arbeitsfläche 0.2.6, Kürzel 0.2.1) mit Thema main `3f4a95b` (0.2.2): beide labwc-Themen
  Querencia-Klassisch und Querencia-Klassisch-Dunkel unter `/usr/share/themes`, die
  gettext-Kataloge von Panel, Lautstärke, Netzwerk und Arbeitsfläche.
- querencia-files 0.1.0~alpha8-1 aus `files/qf-0t-3` (`ab79d99e`): Starter
  `org.querencia.Files.desktop`, alter Starter als unsichtbare Brücke ohne MIME-Typen,
  MetaInfo `org.querencia.Files`, Paketmarke unter `/usr/share/querencia-files`; der
  Patch für die Ausgabe entfällt (Files liest die Versionsdatei).
- querencia-session 0.1.0~alpha8-1 aus `session/alpha8` (`9d337b1`): Super+D an
  `org.querencia.Panel`, Ordner mit `org.querencia.Files`; Depends
  querencia-shell (>= 0.1.0~alpha9).
- querencia-einstellungen 0.1.6-1 (`888bc2e`), querencia-sitzung 0.1.6-1 (`316f52e`).
- Neue changelog-Einträge mit einem Datum vor dem Bau, damit alle Dateien auf
  SOURCE_DATE_EPOCH geklemmt werden.
- `tests/frisches-ubuntu-pruefen.sh`: N (nichts in /home) nur im Zeitfenster des letzten
  apt-Laufs (QD-131); Prüfpunkte für Alpha 2.2.
- `docs/alpha21-nachziehen.md`: Upgrade-Probe vor dem Hochladen aus einer lokalen Kopie
  der Quelle (QD-132).

## Alpha 2.1 – Kandidat 3b vom 22.10.2026, unveröffentlicht

Wie Kandidat 3, querencia-session 0.1.0~alpha7-3 aber aus der Quelle
`session/alpha7-3` (`1c200ad`, Autostart-Block gleich runtime `388cff8`, Tests
erwarten den Wachhund) statt aus den Paket-Patches 0002/0003.

## Alpha 2.1 – Kandidat 3 vom 22.10.2026, unveröffentlicht

Kandidat 2 plus Panel-Überwachung im Sitzungsstart.

- querencia-session 0.1.0~alpha7-3: Der Autostart startet Panel 0.2.3 unter
  seinem Wachhund (`--ueberwacht`); Patch 0002 aus runtime `panel/ueberwacht-1`
  (`7ad985a`), Patch 0003 passt `tests/run.sh` an (Fake-Panel beantwortet
  `--faehigkeiten`, neuer Fall „Panel unter Überwachung“).
- Metapaket verlangt querencia-session (>= 0.1.0~alpha7-3).
- Shell-Quelle runtime `388cff8` (gleiche Crates wie `a2eebc8`, Paket byte-gleich).
- Tests: Wegwerf-Hülle und `frisches-ubuntu-pruefen.sh sitzung` kennen Wachhund
  plus Panel; die Hülle prüft den Neustart nach SIGSEGV (zweimal geschickt, Rusts
  Stapelüberlauf-Handler fängt das erste).
- Weg-B-Probe in VM 115: Neuinstallation aus lokaler Quelle und Upgrade Alpha 2 →
  Kandidat 3 bestanden.

## Alpha 2.1 – Kandidat 2 vom 22.10.2026, unveröffentlicht

Welle Alpha 2.1 bis 05:00: alles, was live, nachkontrolliert und gemergt ist.

- Shell 0.1.0~alpha8-1 aus querencia-runtime main `388cff8` (Tag zeigt auf
  `a2eebc8`, gleiche Crates, Paket byte-gleich): Panel 0.2.3
  (Info mit Ausgabe, Online-Hilfe/Fehler melden, Netzwerkseite, seltener
  Symbolthema neu einlesen, Schutzmodus `--ueberwacht` noch aus), Desktop 0.2.4
  (Beschriftung ohne Platte), Kürzel 0.2.1 (dunkel).
- Files 0.1.0~alpha7-1 (QF-0s, `files/qf-0s`): Papierkorb-Ziehen stellt wieder
  her, Info mit Paketversion (`QUERENCIA_PACKAGE_VERSION` aus debian/rules),
  Ausgabe „Alpha 2.1“ per Patch.
- Sitzung 0.1.4, Einstellungen 0.1.5, Software 0.1.5, Terminal 0.3.2,
  Screenshot 0.2.10 (Homepage-Patches von Terminal und Screenshot entfallen),
  Rechner 0.1.6, Editor 0.2.4, Bilder 0.2.6, Dateisuche 0.1.5, Dokumente
  0.1.4, Archiv 0.1.2 (Homepage-Patch bleibt bei Archiv und Dokumente).
- Metapaket: Mindestversionen der Welle, `Recommends: fonts-noto-core,
  fonts-noto-cjk` (asiatische Zeichen in Fenstertiteln).
- Panel-Überwachung (`--ueberwacht`) im Autostart von querencia-session: in
  Kandidat 2 offen, mit Kandidat 3 erledigt.
- Unverändert aus Alpha 2: labwc, Session, Benachrichtigungen, Symbole,
  Hintergründe; Anmeldung 0.1.2-1 wie Kandidat 1.

## Alpha 2.1 – Kandidat 1 vom 22.10.2026, unveröffentlicht

Alpha 2 plus Desktop 0.2.3, Versionsdatei und Anmeldung 0.1.2; die übrigen
Tags der Welle folgen nach [docs/alpha21-nachziehen.md](docs/alpha21-nachziehen.md).

- Shell 0.1.0~alpha8-1: Desktop 0.2.3 (`desktop/0.2.3` = e38f402):
  Kontextmenü, Zwischenablage, Papierkorb und Ziehen auf der Arbeitsfläche.
- Metapaket 0.1.0~alpha2.1-1: `/usr/share/querencia/version` und
  `/usr/share/querencia/release` ([docs/versionsdatei.md](docs/versionsdatei.md));
  verlangt Shell >= 0.1.0~alpha8.
- Terminal 0.3.0-2, Screenshot 0.2.9-2: MetaInfo-Homepage
  https://querencialinux.org per Patch (bis die neuen Upstream-Versionen sie
  selbst mitbringen).
- Anmeldung 0.1.2-1 (Zweig `anmeldung-de`, Komponente c489a15): übersetzter
  Anmeldebildschirm, Uhr nach Systemsprache, Ausgabe aus der Versionsdatei.
- labwc: `GIT_CEILING_DIRECTORIES` im Bau, sonst landete `git describe` des
  Packaging-Repos als Version im Binary. Mit der Grenze ist der Neubau
  byte-gleich mit Alpha 2.
- Neue debian/changelog-Einträge ohne interne Kennungen, Rollen oder
  Rechnernamen. Der Filter für KI-Abschnitte (`common/doku/`) bleibt, solange
  die READMEs der Quellen den Abschnitt noch haben.
- 16 Pakete sind unverändert. Der Kandidat enthält für sie die Alpha-2-Dateien
  aus der Quelle (Pool unveränderlich). Ihr Neubau ist bei 12 Paketen byte-gleich.
  Bei Session, Symbole und Hintergründe weichen nur die Zeitstempel ab (der
  Alpha-2-Bau lief vor dem Changelog-Datum). Bei Software liegen im Binary die
  Konstanten in anderer Reihenfolge, bei gleichen Quellen.

## Alpha 2 – eingefroren 21.10.2026 22:07, unveröffentlicht

21 Pakete auf dem Live-Stand von entwicklungs-vm vom 21.10.2026 abends
(Abschlusstabelle 18:52, dazu Desktop 0.2.2, Einstellungen 0.1.4,
Dokumente 0.1.3, Files QF-0r-1 und Hintergründe 0.2). Jede Quelle ist ein
getaggter Stand; je Komponente geprüft, dass das Live-Binary byte-gleich mit
der Vorlage im `-int`-Tag ist und der Code-Tag dessen Vorfahr ohne
Codeänderung dazwischen; Panel und Kürzel aus `desktop/0.2.2` byte-gleich
nachgebaut. SHA256SUMS des Satzes `5cbe6f81…` (Bericht
`alpha2-pakete-bericht.md`).

- Dunkles Thema: Querencia-Klassisch 0.2.1 mit `gtk-dark.css` (GTK 3/4),
  CSS-Welle dunkel in Panel 0.2.1, Desktop und allen Programmen außer Files
  (QD-081); Kontrast hell nach WCAG AA (QD-088, QD-089).
- Neues Paket querencia-hintergruende 0.2-1: 16 Hintergründe (32 PNG),
  Standardbild Tiefblau; Shell (Desktop 0.2.2: Beschriftung mit
  Hinterlegung, Standardbild, leere Dateien) und Einstellungen 0.1.4
  (Galerie) hängen davon ab.
- Terminal 0.3.0 mit Reitern (QD-079); Kürzelübersicht 0.2.0.
- Files QF-0r-1: Update-Prüfer still (QD-090), „Querencia Files“ überall;
  Patch 0001 entfällt; Recommends querencia-archiv.
- Symbole 0.7: Knopf „Arbeitsfläche anzeigen“ und fünf Programmsymbole, das
  Thema wird beim Bau aus `quellen/` gerendert (715 Dateien = live).
- Neue Versionen: Shell 0.1.0~alpha7, Screenshot 0.2.9, Editor 0.2.3,
  Bilder 0.2.5, Benachrichtigungen 0.2.2, Rechner 0.1.5, Systemmonitor
  0.1.4, Dateisuche 0.1.4, Software 0.1.4, Dokumente 0.1.3, Archiv 0.1.1,
  Einstellungen 0.1.4 (Patch 0001 entfällt); Metapaket 0.1.0~alpha2-7.
- CLEAN-1: changelog-Trailer nur mit dem Maintainer (B1), MetaInfo-Homepage
  https://querencialinux.org (B2), APT-Werkzeuge verlangen genau einen
  Schlüssel und vergleichen Valid-Until (B3), Doku ohne KI-Abschnitte und
  ohne interne Pfade (Filter in `doc_install`, DEP-3-Patches). Deshalb neue
  Revisionen auch für Session 0.1.0~alpha7-2, labwc 0.9.8-0querencia5,
  Sitzung 0.1.3-3 und Anmeldung 0.1.1-3.
- Prüfungen: Alpha-2-Punkte in `tests/frisches-ubuntu-pruefen.sh` und
  `tests/wegwerf-installation.sh`; `werkzeuge/probe-wiederholen.sh` für eine
  zweite Probe-VM (PROBE_VMID).

## [0.1.0~alpha2] – veröffentlicht als Alpha 1 (20.10.2026)

- Neues Paket querencia-anmeldung (ANM-1, Zweig anm-1): Anmeldebildschirm
  aus greetd und ReGreet 0.5.0 (Upstream, Spiegel
  `querencia-anmeldung/upstream/regreet.git`) mit den Querencia-Teilen als
  Komponente `querencia/`; debconf-Frage `shared/default-x-display-manager`
  wie gdm3/lightdm, eigener Dienst `querencia-anmeldung.service`;
  Umschaltprüfung `tests/anmeldung-umschalten.sh` (Wegwerf-Wurzel, eigene
  debconf-Datenbank). `common/querencia.mk` installiert jetzt auch
  `debian/<paket>.config` und `.templates`. Metapaket: Suggests
  querencia-anmeldung statt greetd.
- Paketsatz auf dem Live-Stand von entwicklungs-vm (20.10.2026 ~13:00, G2-F2):
  Runtime 348351c (main 8014df9 + G2-AD 0.1), Editor/Bilder 0.2.1,
  Rechner 0.1.3, Systemmonitor 0.1.2, Dateisuche 0.1.3, Software 0.1.2,
  Screenshot 0.2.8, Terminal 0.2.0 (App-ID org.querencia.Terminal),
  Einstellungen 0.0.8, Symbole 0.5.2, Sitzung und Benachrichtigungen 0.1.2,
  Files qf-0o-2-2; siehe `quellen.conf`.
- querencia-shell: GTK-Thema Querencia-Klassisch (Komponente
  querencia-thema), Standardhintergründe G2-AF; querencia-symbole:
  Symbolthema Querencia; gettext-Kataloge in allen übersetzten Programmen
  (Makro `mo_install`), MetaInfo aus dem Upstream (`metainfo_install_from`),
  Lintian-Ausnahmen aus `debian/<paket>.lintian-overrides`.
- Befunde der Pflichtprobe: libnotify-bin (B5), x-querencia-portals.conf
  (B6) und Erscheinungsbild nur für X-Querencia (B7) im Sitzungspaket,
  Hinweise zu netplan/NetworkManager (B2), GDM-Neustart (B9) und Umfang
  (B12); labwc mit Manpages und SVG-Knöpfen.
- Neues Gerüst querencia-dokumente (18. Paket, wartet auf den Tag
  dokumente/0.1.0); Prüfskripte zählen 17 oder 18 Pakete.
- Pflichtprobe auf frischer VM (20.10.2026): `werkzeuge/probe-wiederholen.sh`
  für die Proxmox-VM 115; `tests/frisches-ubuntu-pruefen.sh` ohne
  Fehl-FAIL unter pipefail und mit Anmeldebildschirm-Vergleich über
  Prüfsummen.
- Paketsatz auf dem Live-Stand von entwicklungs-vm (20.10.2026, G2-F):
  Quellen aus den Arbeits-Repositories (querencia-runtime main 52f177cd,
  Files QF-0o-1, Screenshot 0.2.4, Bilder 0.1.1, Editor 0.2.0 …), siehe
  `quellen.conf`.
- Neue Pakete: querencia-sitzung, -benachrichtigungen, -einstellungen,
  -editor, -rechner, -systemmonitor, -dateisuche, -software, -symbole.
  Metapaket querencia-desktop 0.1.0~alpha2 zieht alle.
- querencia-shell enthält jetzt Lautstärke, Netzwerk, Tastenkürzel und das
  Theme Querencia-Klassisch; querencia-session 0.1.0~alpha2 startet
  polkit-Agent, Leerlaufsperre, Benachrichtigungen und Bildschirmanordnung.
- MetaInfo in jedem Programmpaket (Regel M von SW-5 in `pakete-pruefen.sh`),
  Prüfung auf Dateien in zwei Paketen.
- Werkzeuge: Erzeugnisse nach `build/`, `komponenten.conf` (weitere
  Upstream-Archive, Unterordner, Ausschlüsse), `alle-bauen.sh`, nice beim
  Bau, `tests/wegwerf-installation.sh` (dpkg -i in einer bubblewrap-Hülle,
  kopflose labwc-Sitzung).
- Maintainer `pottrauschen`, Copyright „Querencia Desktop contributors“
  (ENTSCHEIDUNGEN Nr. 3, 14); Doku nach `docs/` (Nr. 17).

## [0.1.0~alpha1] – unveröffentlicht

- Erste Paketierung aller Komponenten, Metapaket, labwc-Backport (QREL-01).
- Werkzeuge für reproduzierbare Quellarchive (git archive + cargo vendor),
  Paketbau ohne debhelper, Paketprüfung, DEP-5-Copyright aus
  Crate-Metadaten, signierte APT-Quelle und Veröffentlichungsprüfung.
- CI-Vorlagen (GitHub Actions), nicht aktiviert.
- querencia-bilder (QI-01): Bildbetrachter, noch ohne MIME-Zuordnung;
  querencia-desktop 0.1.0~alpha1-2 empfiehlt ihn (Recommends).
