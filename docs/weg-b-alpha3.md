# Weg B Alpha 3 – Installationsprobe aus der veröffentlichten Quelle

Stand 24.10.2026. Pflichtprobe nach [pflichtprobe-frische-vm.md](pflichtprobe-frische-vm.md),
diesmal mit der signierten Quelle statt lokaler Pakete. Geprüft wurde auf der Probe-VM
(Ubuntu 26.04.1 Server-Abbild, Snapshot „frisch“, Anmeldung an tty1). Der Index der Quelle war
byte-gleich mit dem Satz `build/debs-beta-3` (22 Pakete, SHA256SUMS `488348b6…`, Tag
`packaging/alpha3-2`).

## Ergebnis

| Lauf | Ergebnis |
|---|---|
| Neuinstallation (`apt install querencia-desktop`) | 389 Pakete, Exit 0; `nachher` 76/0, `sitzung` 28/0; Querencia Dateien ist Ordnerprogramm; `querencia-files` wird nicht installiert |
| Upgrade Alpha 2.1 → Alpha 3 (`apt update && apt full-upgrade`) | 22 s, Exit 0, keine Konfigurationsfrage; 8 Querencia-Pakete aktualisiert, `querencia-dateien` neu, nichts entfernt; `nachher` 78/0 |
| Eigene Einstellungen beim Upgrade | Hintergrund, Panel-Starter, Ordnerwahl und Lesezeichen bleiben byte-gleich. Die geänderte `rc.xml` behält der Sitzungsstarter (`rc.xml.vorgabe-neu` daneben), die unveränderte `autostart` übernimmt die neue Vorgabe |
| Brücken | Ein alter Panel-Starter `io.github.lgse.Strata.desktop` und eine alte Ordnerwahl auf Files öffnen Querencia Dateien |
| Anmeldebildschirm | `querencia-anmeldung` macht sich auf dem Server-Abbild zum Anmeldedienst; Anmelden und Abmelden funktionieren |

## Folgen für dieses Repo

1. **Upgrade-Probe prüft einen falschen Files-Pfad.** `tests/wegwerf-upgrade.sh` legt die
   Files-Einstellungen unter `~/.config/querencia-files/settings.toml` an. Querencia Files
   0.1.0~alpha7 (Alpha 2.1) schreibt sie aber nach `~/.config/strata/settings.toml`. In der echten
   Probe hat Querencia Dateien 0.2.0 deshalb nichts übernommen; es legt `dateien.ini` mit den
   Vorgaben an. Die Probe soll den Ausgangsstand am Pfad des alten Files anlegen. Die Übernahme
   selbst ist ein Befund an Querencia Dateien (`konfig.rs`, `files_pfad()`).
2. **`frisches-ubuntu-pruefen.sh sitzung`** meldet FAIL „Ordnerprogramm“, wenn der Nutzer seine
   alte Wahl `io.github.lgse.Strata.desktop` behält. Das ist gewollt, denn die Brücke startet
   Dateien. Der Prüfpunkt soll eine Brücken-Wahl mit `Exec=querencia-dateien %U` als PASS werten.
3. Neuinstallation: `querencia-files` fehlt (`un`). Das Übergangspaket kommt nur über das
   Upgrade, wie das Prüfskript es erwartet.

## Hinweise für die nächste Probe

- Den Ausgangsstand für ein Upgrade aus der Quelle herstellen, solange sie noch den alten Stand
  liefert. Eigene Einstellungen über die Oberfläche setzen, damit die echten Pfade entstehen.
- polkit-Dialoge aus einem Terminal der grafischen Sitzung auslösen (über das Menü geöffnet).
  `systemctl` im Terminal nutzt seinen eigenen Text-Agenten, und `pkexec` fehlt auf dem
  Server-Abbild. Es geht z. B. mit
  `gdbus call --system --interactive --timeout 120 --dest org.freedesktop.systemd1 --object-path /org/freedesktop/systemd1 --method org.freedesktop.systemd1.Manager.RestartUnit cron.service replace`.
- Nach `apt purge` eines aktiven `querencia-anmeldung` läuft der Anmeldebildschirm bis zum
  Neustart weiter.

Bericht und Belege liegen außerhalb des Repos (Review-Ordner, intern).
