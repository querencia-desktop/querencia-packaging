# Änderungen – querencia-packaging

## [0.1.0~alpha2] – unveröffentlicht

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
