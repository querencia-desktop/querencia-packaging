# Pflichtprobe auf einer frischen Ubuntu-26.04-VM

**Zweck:** Beweisen, dass sich Querencia Desktop auf einem Rechner ohne
Entwicklungsumgebung aus Paketen installieren lässt, als Sitzung startet und
dass jedes Programm läuft (06 §7a, Stufe 1). Erst danach kommen die signierte
APT-Quelle und die Veröffentlichung.

**Wer:** pottrauschen (sudo, VM-Verwaltung). Dauer etwa 1 Stunde.
**Nie auf `entwicklungs-vm` ausführen.** Nur auf einer neuen, wegwerfbaren VM mit
Snapshot.

Paketsatz: `build/debs/` dieses Repositorys (17 Pakete, `SHA256SUMS`),
gebaut von G2-F; Quellstände in [quellen.conf](../quellen.conf), Bericht
.

## 1. VM anlegen

| Einstellung | Wert |
|---|---|
| System | Ubuntu 26.04 LTS, **Desktop**-Abbild (GDM vorhanden, prüft die Sitzungswahl) oder **Server**-Abbild (Anmeldung an tty1) |
| CPU / RAM / Platte | 2 vCPU, 4 GiB, 25 GB |
| Grafik | virtio-gpu (ohne 3D genügt), Anzeige SPICE oder VNC |
| Netz | NAT; die Installation braucht das Ubuntu-Archiv für Abhängigkeiten |
| Benutzer | neuer Benutzer, z. B. `probe`, **nicht** `user` (zeigt fest eingebaute Pfade) |

Mit virt-manager oder z. B.:

```bash
virt-install --name querencia-probe --memory 4096 --vcpus 2 --disk size=25 --cdrom ~/Downloads/ubuntu-26.04-desktop-amd64.iso --os-variant ubuntu26.04 --graphics spice --video virtio
```

Nach der Ubuntu-Installation: `sudo apt update && sudo apt full-upgrade`,
neu starten, dann **Snapshot `frisch`** anlegen:

```bash
virsh snapshot-create-as querencia-probe frisch
```

## 2. Pakete auf die VM bringen

Auf `entwicklungs-vm` (der Ordner enthält nur die `.deb` und `SHA256SUMS`):

```bash
scp -r ~/projects/querencia-packaging-wt-g2f/build/debs probe@<vm-ip>:querencia-debs
scp ~/projects/querencia-packaging-wt-g2f/tests/frisches-ubuntu-pruefen.sh probe@<vm-ip>:
```

Auf der VM:

```bash
cd ~/querencia-debs && sha256sum -c SHA256SUMS
```

Alle Zeilen müssen `OK` melden.

## 3. Vorher-Zustand festhalten

```bash
sudo bash ~/frisches-ubuntu-pruefen.sh vorher
```

## 4. Installation

**Weg A – lokales Verzeichnis (Standard für die Probe).** apt nimmt die
Querencia-Pakete aus dem Ordner und alle Abhängigkeiten aus dem
Ubuntu-Archiv. Der labwc-Backport (0.9.8) muss dabei sein, weil Ubuntu nur
0.9.3 liefert:

```bash
cd ~/querencia-debs && sudo apt install ./*.deb
```

apt zeigt vorher die Liste der zusätzlichen Pakete; sie sollte keinen
Anmeldebildschirm und keinen anderen Desktop enthalten (Prüfung P). Ausgabe
sichern:

```bash
cd ~/querencia-debs && sudo apt install ./*.deb 2>&1 | tee ~/apt-install.log
```

**Weg B – signierte Testquelle (zweiter Durchlauf, optional).** Auf
`entwicklungs-vm` eine Quelle mit Wegwerf-Schlüssel erzeugen:

```bash
cd ~/projects/querencia-packaging-wt-g2f && mkdir -p -m 0700 build/probe-gnupg && gpg --homedir build/probe-gnupg --batch --passphrase '' --quick-gen-key 'Querencia Probe <probe@invalid>' ed25519 sign 30d
```

```bash
cd ~/projects/querencia-packaging-wt-g2f && FPR=$(gpg --homedir build/probe-gnupg --list-secret-keys --with-colons | awk -F: '/^fpr/ {print $10; exit}') && python3 werkzeuge/apt-quelle-erzeugen.py --ziel build/probe-apt --gnupghome build/probe-gnupg --schluessel "$FPR" build/debs/*.deb
```

`build/probe-apt/` auf die VM kopieren (z. B. nach `/srv/querencia-apt`),
dann dort:

```bash
sudo install -m 0644 /srv/querencia-apt/querencia-archive-keyring.gpg /usr/share/keyrings/querencia-probe.gpg
```

```bash
printf 'Types: deb\nURIs: file:/srv/querencia-apt/\nSuites: resolute\nComponents: alpha\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/querencia-probe.gpg\n' | sudo tee /etc/apt/sources.list.d/querencia-probe.sources
```

```bash
sudo apt update && sudo apt install querencia-desktop
```

Nach der Probe den Wegwerf-Schlüssel auf `entwicklungs-vm` löschen
(`rm -rf build/probe-gnupg`).

## 5. Nachher-Prüfung (ohne Sitzung)

```bash
bash ~/frisches-ubuntu-pruefen.sh nachher
```

Erwartet: alle 17 Pakete installiert, labwc ≥ 0.9.4, alle Desktop-Dateien
gültig, 14 MetaInfo-Dateien, kein 48×48-Symbol neben SVG, deutscher
Editor-Katalog, `querencia-session --check` ohne `FEHLT`, kein
Anmeldebildschirm verändert, nichts in `/home` angelegt.

## 6. Anmeldung und Prüfliste

**Desktop-Abbild:** abmelden, im GDM-Anmeldebildschirm unten rechts das
Zahnrad, „Querencia Desktop“ wählen, anmelden.
**Server-Abbild:** an tty1 anmelden, `querencia-session` eingeben.

Dann im Querencia-Terminal:

```bash
bash ~/frisches-ubuntu-pruefen.sh sitzung
```

Von Hand, je Zeile PASS/FAIL mit Bildschirmfoto (Druck-Taste) notieren:

| Nr. | Prüfung | Erwartet |
|---|---|---|
| 1 | Panel oben | Logo „Q“, Menüs Anwendungen / Orte / System, Uhr. Lautstärke und Netzwerk sind auf einem frischen Profil nicht da: Rechtsklick aufs Panel → „Zum Panel hinzufügen …“ → beide hinzufügen |
| 2 | Panel unten | Fensterliste, Arbeitsflächenumschalter mit 4 Flächen |
| 3 | Arbeitsfläche | Hintergrund „Querencia Blau“, Symbole Rechner, Persönlicher Ordner, Papierkorb; Rechtsklick-Menü |
| 4 | Fensterrahmen | Theme Querencia-Klassisch (klassische Knöpfe), Titelleiste mit Programmsymbol |
| 5 | Menü Anwendungen | Zubehör, Grafik, Systemwerkzeuge vorhanden; Einträge mit eigenen Symbolen |
| 6 | Querencia Files | Orte → Persönlicher Ordner; Ordner öffnen, Datei kopieren |
| 7 | Terminal | Zubehör → Terminal; Strg+Umschalt+C/V |
| 8 | Texteditor | Zubehör → Texteditor; deutsche Menüs, Datei speichern; Doppelklick auf eine `.txt` in Files öffnet den Editor |
| 9 | Bildbetrachter | Doppelklick auf ein PNG öffnet Querencia Bilder; Info-Fenster mit Symbol |
| 10 | Rechner | Zubehör → Taschenrechner; `0,1 + 0,2 − 0,3 = 0` |
| 11 | Systemüberwachung | Systemwerkzeuge → Systemüberwachung; Prozesse, Ressourcen, Dateisysteme |
| 12 | Dateisuche | „Nach Dateien suchen …“; Suche nach `*.txt` im Persönlichen Ordner |
| 13 | Bildschirmfoto | Druck öffnet die Auswahl, Alt+Druck nimmt ein Fenster auf, Speichern unter Bilder |
| 14 | Einstellungen | System → Einstellungen → Systemeinstellungen; Hintergrund ändern, Auflösung ändern und den 15-s-Rückfall abwarten |
| 15 | Software | System → Systemverwaltung → Software; Katalog lädt; ein kleines Programm installieren → **Passwortdialog des Querencia-polkit-Agenten**; wieder entfernen |
| 16 | Benachrichtigung | `notify-send Test Hallo` zeigt ein Popup oben rechts |
| 17 | Lautstärke | Klick auf das Symbol öffnet den Regler (in einer VM evtl. nur „Dummy Output“) |
| 18 | Netzwerk | Symbol zeigt die Verbindung (mit NetworkManager auch die Liste) |
| 19 | Tastenkürzel | Super+? zeigt die Übersicht; Alt+Tab mit Liste; Strg+Alt+←/→ wechselt die Fläche |
| 20 | Sperren | Strg+Alt+L sperrt, Entsperren mit dem Passwort |
| 21 | Sitzungsdialog | Strg+Alt+Entf öffnet „Abmelden, Bildschirm sperren, Neu starten, Herunterfahren“ |
| 22 | Abmelden | System → Abmelden …; zurück im Anmeldebildschirm bzw. an tty1 |
| 23 | Zweite Anmeldung | erneut anmelden: alles startet wieder, Logs in `~/.local/state/querencia/` ohne `panicked` |

Logs für den Bericht:

```bash
tar -czf ~/querencia-probe-logs.tgz -C ~ .local/state/querencia querencia-test apt-install.log
```

## 7. Entfernen und Rückfall

Erst prüfen, dass Entfernen sauber ist, dann die VM zurücksetzen:

```bash
sudo apt remove 'querencia-*'
```

```bash
bash ~/frisches-ubuntu-pruefen.sh entfernt
```

Erwartet: Pakete entfernt, Benutzerdaten in `~/.config/querencia` und
`~/.local/state/querencia` bleiben (werden nie vom Paket gelöscht). Der
labwc-Backport bleibt installiert; zurück auf Ubuntus labwc:

```bash
sudo apt install --allow-downgrades labwc/resolute
```

**Rückfall der ganzen Probe:** Snapshot wiederherstellen.

```bash
virsh snapshot-revert querencia-probe frisch
```

Bleibt die Sitzung hängen (kein Panel): an einer Textkonsole (Strg+Alt+F3)
anmelden und `querencia-session --exit`; im Anmeldebildschirm wieder die
Ubuntu-Sitzung wählen.

## 8. Ergebnis melden

Ergebnisdateien `~/querencia-test/`, `~/querencia-probe-logs.tgz` und die
Tabelle aus Abschnitt 6 an die Status-Session geben. Jede FAIL-Zeile mit
Bildschirmfoto und Log. Erst mit allen Zeilen PASS (oder einer Entscheidung
je FAIL) gilt die Pflichtprobe als bestanden.
