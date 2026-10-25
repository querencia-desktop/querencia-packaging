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
  das System), keine gebündelten Fremdarchive in `cargo-vendor` der
  Quellarchive (QD-139; Quellarchive aus `QUERENCIA_ORIG_DIRS`, Standard
  `build/orig`; entfernt werden sie nach `common/fremdarchive.conf`).
- `apt-quelle-testen.sh`: erzeugt eine Quelle mit Wegwerf-Testschlüssel und
  prüft sie mit apt in einer abgeschotteten Umgebung (`-o Dir=…`): gültig,
  manipuliert, falscher Schlüssel, unsigniert.
- `veroeffentlichung-pruefen.py`: durchsucht die gesamte Git-Historie nach
  Geheimnissen, persönlichen Daten, Maschinenpfaden, Logs, großen Dateien.
  Name und E-Mail des Besitzers stehen nicht im Repository; sie kommen als
  Regex aus `QUERENCIA_PRIVAT_MUSTER` (ohne Variable: Hinweis, keine
  Prüfung).

Nichts davon installiert etwas oder braucht root.

## Installationsprobe ohne zweite VM

`tests/wegwerf-installation.sh build/debs/*.deb` installiert den Paketsatz in
eine Wegwerf-Kopie des Systems (bubblewrap, Overlay über `/usr`, `/etc`,
`/var` im Arbeitsspeicher, eigener Benutzer-Namensraum ohne Netz) mit
`dpkg -i`, führt die Maintainer-Skripte aus, prüft `dpkg --audit`, ruft jedes
Programm mit `--version`/`--help` auf und startet eine kopflose
labwc-Sitzung mit Panel und Desktop. Das echte System bleibt unverändert.

`tests/wegwerf-upgrade.sh <nachweis> <alter satz> <neuer satz>` misst in derselben Hülle ein
Upgrade: alter Satz mit `dpkg -i`, Probe-Benutzer (Lesezeichen, Files-Einstellungen, eigene
Ordnerwahl auf die alte Strata-ID), `apt-get -s full-upgrade` gegen eine Datei-Quelle, neuer
Satz darüber, Ordnerprogramm (`gio mime inode/directory` wie in der Querencia-Sitzung),
Files-Starter, unveränderte Benutzerdaten, `apt-get -s autoremove`, danach die volle
Sitzungsprüfung von `wegwerf-installation.sh` auf dem neuen Stand. Seit Alpha 3 zusätzlich
`apt-get -s upgrade --with-new-pkgs` (wie `apt upgrade`: nichts zurückgehalten, nichts entfernt),
das Übergangspaket `querencia-files` ohne Reste von Files und keine Starter oder
mimeapps-Einträge, die ins Leere zeigen. Alter Satz Alpha 2.1:
`UPGRADE_VORHER_ORDNER=io.github.lgse.Strata.desktop`; Alpha 3: `UPGRADE_VORHER_ORDNER=org.querencia.Dateien.desktop
UPGRADE_NEU=`. `UPGRADE_FILES_ORDNER=strata` legt die Files-Einstellungen des Probe-Benutzers wie
bis Alpha 2.1 unter `~/.config/strata/` ab; `UPGRADE_OHNE` nimmt Pakete aus (optionale wie
`querencia-webhuelle` zieht apt beim Upgrade nicht).

`tests/wegwerf-upgrade-schnatter.sh <nachweis> <alter satz> <neuer satz>` misst die
Umbenennung Querencia Webhülle → Schnatter: alter Satz mit `querencia-webhuelle 0.2.0-1`, ein
Probe-Benutzer mit den Ordnern der Webhülle **am echten Pfad** (`~/.local/share`, `~/.cache`,
`~/.config` je `querencia-webhuelle`, Attrappe der Anmeldung, Einstellungen wie von 0.2.0;
Lehre aus QD-172), `apt-get -s full-upgrade` und `upgrade --with-new-pkgs` (Schnatter neu,
Übergangspaket aktualisiert, nichts entfernt), Upgrade mit `dpkg -i` (Übergangspaket zuerst:
dpkg ordnet nicht um wie apt), Pakete und Brücken-Starter, Ordner vom Upgrade unberührt, dann
ein Start von Schnatter ohne Bildschirm: der Umzug läuft vor GTK (gleiche Inode, gleicher
Inhalt), ein zweiter Start findet nichts mehr; zuletzt `apt-get -s autoremove`.

Beide Proben legen ihre Wegwerf-Wurzel unter `$TMPDIR` an und geben der Hülle einen eigenen
`TMPDIR` darin; `TMPDIR=$PWD/build/tmp` hält sie auf der Platte (`/tmp` ist auf der
Entwicklungs-VM ein tmpfs). Paketpfade absolut angeben.

## Pflichtprobe auf frischem Ubuntu

[pflichtprobe-frische-vm.md](pflichtprobe-frische-vm.md), Werkzeug
`tests/frisches-ubuntu-pruefen.sh`. Auf der Proxmox-VM 115 wiederholt
`werkzeuge/probe-wiederholen.sh [--desktop]` den automatischen Teil ab
Snapshot `frisch` (Installation, `vorher`/`nachher`).
