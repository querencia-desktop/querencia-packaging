# Änderungen – querencia-packaging

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
