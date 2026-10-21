# Änderungen – querencia-packaging

## Alpha 2 – unveröffentlicht (Paketsatz 21.10.2026)

Paketsatz auf dem Live-Stand von entwicklungs-vm vom 21.10.2026 18:52
(Abschlusstabelle des Tages). Jede Quelle ist ein getaggter Stand; je
Komponente geprüft, dass das Live-Binary byte-gleich mit der Vorlage im
`-int`-Tag ist und der Code-Tag dessen Vorfahr ohne Codeänderung
dazwischen (Bericht `alpha2-pakete-bericht.md`).

- Dunkles Thema: Querencia-Klassisch 0.2.1 mit `gtk-dark.css` (GTK 3/4,
  prefer-dark), CSS-Welle dunkel in Panel 0.2.1, Desktop 0.2.0 und allen
  Programmen (QD-081); Kontrast hell nach WCAG AA in Thema, Bilder 0.2.5,
  Benachrichtigungen 0.2.2, Rechner 0.1.5, Einstellungen 0.1.3,
  Systemmonitor 0.1.4 (QD-088, QD-089).
- Terminal 0.3.0 mit Reitern (QD-079); Kürzelübersicht 0.2.0 kennt die
  Reiterkürzel.
- Files QF-0q-1: Stratas Update-Prüfer stillgelegt (QD-090), Patch 0001
  entfällt; Recommends querencia-archiv.
- Symbole 0.7: Knopf „Arbeitsfläche anzeigen“ und fünf Programmsymbole im
  Thema, das Thema wird beim Bau aus `quellen/` gerendert (715 Dateien,
  byte-gleich mit live).
- Neue Versionen: Shell 0.1.0~alpha7 (Runtime 2e134c6), Screenshot 0.2.9,
  Editor 0.2.3, Dateisuche 0.1.4, Software 0.1.4, Dokumente 0.1.2,
  Archiv 0.1.1; Einstellungen 0.1.3 ohne Patch 0001 (findet
  `/etc/querencia/labwc` selbst); Metapaket 0.1.0~alpha2-7.
- CLEAN-1: changelog-Trailer nur noch mit dem Maintainer (B1, deshalb neue
  Revisionen querencia-session 0.1.0~alpha7-2 und labwc
  0.9.8-0querencia5), MetaInfo-Homepage https://querencialinux.org (B2,
  querencia-sitzung 0.1.3-3, DEP-3-Patches für Archiv und Dokumente).
- Unverändert aus Alpha 1: querencia-anmeldung 0.1.1-2 (byte-gleich).
- Nicht im Satz: Hintergründe 0.2 (Lizenzprüfung offen).

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
