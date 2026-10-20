# Pakete prüfen

```bash
bash werkzeuge/pakete-pruefen.sh build/debs/*.deb       # statisch + apt-get --simulate
bash werkzeuge/apt-quelle-testen.sh build/nachweis/apt build/debs/*.deb
python3 werkzeuge/veroeffentlichung-pruefen.py ../querencia-shell bericht.md
```

- `pakete-pruefen.sh`: Inhalt nur `/usr` und `/etc`, Conffiles, keine
  Entwicklerpfade, Desktop- und Sitzungsdateien gültig, Programme und Symbole
  vorhanden, Symbolregel (nie 48×48 neben einem Scalable-Verzeichnis),
  MetaInfo je Programmpaket (Regel M, `appstreamcli validate --no-net`),
  keine Datei in zwei Paketen, Abhängigkeiten auflösbar (Simulation gegen
  das System).
- `apt-quelle-testen.sh`: erzeugt eine Quelle mit Wegwerf-Testschlüssel und
  prüft sie mit apt in einer abgeschotteten Umgebung (`-o Dir=…`): gültig,
  manipuliert, falscher Schlüssel, unsigniert.
- `veroeffentlichung-pruefen.py`: durchsucht die gesamte Git-Historie nach
  Geheimnissen, persönlichen Daten, Maschinenpfaden, Logs, großen Dateien.

Nichts davon installiert etwas oder braucht root.

## Installationsprobe ohne zweite VM

`tests/wegwerf-installation.sh build/debs/*.deb` installiert den Paketsatz in
eine Wegwerf-Kopie des Systems (bubblewrap, Overlay über `/usr`, `/etc`,
`/var` im Arbeitsspeicher, eigener Benutzer-Namensraum ohne Netz) mit
`dpkg -i`, führt die Maintainer-Skripte aus, prüft `dpkg --audit`, ruft jedes
Programm mit `--version`/`--help` auf und startet eine kopflose
labwc-Sitzung mit Panel und Desktop. Das echte System bleibt unverändert.

## Pflichtprobe auf frischem Ubuntu

[pflichtprobe-frische-vm.md](pflichtprobe-frische-vm.md), Werkzeug
`tests/frisches-ubuntu-pruefen.sh`. Auf der Proxmox-VM 115 wiederholt
`werkzeuge/probe-wiederholen.sh [--desktop]` den automatischen Teil ab
Snapshot `frisch` (Installation, `vorher`/`nachher`).
