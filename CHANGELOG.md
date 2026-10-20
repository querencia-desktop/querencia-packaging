# Änderungen – querencia-packaging

## [0.1.0~alpha2] – unveröffentlicht

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
