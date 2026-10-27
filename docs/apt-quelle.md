# APT-Quelle von Querencia Desktop

Signierte Paketquelle für Ubuntu 26.04 („resolute“), aus der
`apt install querencia-desktop` funktioniert.

| Was | Wert |
|---|---|
| Adresse | `https://dl.querencialinux.org/apt/` (Cloudflare R2, Bucket `querencialinux`, Pfad `apt/`) |
| Suite / Komponente | `resolute` / `main` |
| Architekturen | `amd64` und `all` |
| Schlüssel | `https://dl.querencialinux.org/apt/querencia.gpg` (auch `.asc`), beim Client `/etc/apt/keyrings/querencia.gpg` |
| Fingerabdruck | `63F6 C499 246E 3699 CA04  726D 342F 12D2 0CE7 1CBD` (erzeugt 20.10.2026, gültig bis 19.10.2028; öffentlicher Schlüssel `apt/querencia.gpg`/`apt/querencia.asc`) |

**Stand:** vorbereitet, nicht veröffentlicht. Es gibt noch keinen echten
Signierschlüssel (§4); geprüft ist der Ablauf mit einem Wegwerfschlüssel.

## 1. Einbinden (Anwender)

Auf einem Ubuntu 26.04 mit Internetzugang. `curl` fehlt auf manchen
Abbildern: `sudo apt install curl`.

Schlüssel holen und den Fingerabdruck mit dem auf
<https://querencialinux.org> veröffentlichten vergleichen:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
```

```bash
curl -fsSL https://dl.querencialinux.org/apt/querencia.gpg | sudo tee /etc/apt/keyrings/querencia.gpg >/dev/null
```

```bash
gpg --show-keys --with-fingerprint /etc/apt/keyrings/querencia.gpg
```

Passt der Fingerabdruck nicht, die Datei löschen und nicht weitermachen.

Quelle eintragen (Deb822; `Signed-By` bindet die Quelle an genau diesen
Schlüssel, er gilt für keine andere Quelle):

```bash
printf '%s\n' 'Types: deb' 'URIs: https://dl.querencialinux.org/apt/' 'Suites: resolute' 'Components: main' 'Architectures: amd64' 'Signed-By: /etc/apt/keyrings/querencia.gpg' | sudo tee /etc/apt/sources.list.d/querencia.sources
```

Die gleiche Datei liegt als Vorlage unter
`https://dl.querencialinux.org/apt/querencia.sources`.

Installieren:

```bash
sudo apt update && sudo apt install querencia-desktop
```

Auf einem Ubuntu-Server holt apt mit den empfohlenen Paketen rund 360
weitere Pakete aus dem Ubuntu-Archiv (weniger mit
`--no-install-recommends`), auf einem Ubuntu-Desktop nur wenige. Updates kommen danach mit `sudo apt upgrade` bzw. über Querencia
Software.

## 2. Sitzung wählen

- **Ubuntu Desktop (GDM):** Den Rechner nach der Installation einmal neu
  starten (GDM liest neue Sitzungen nur beim Start). Im Anmeldebildschirm
  den Benutzer wählen, unten rechts auf das Zahnrad klicken und
  „Querencia Desktop“ auswählen, dann das Kennwort eingeben. GDM merkt sich
  die Wahl.
- **Ohne grafischen Anmeldebildschirm** (Server): an einer Textkonsole
  anmelden und `querencia-session` starten, oder den Anmeldebildschirm von
  Querencia installieren: `sudo apt install querencia-anmeldung`. Er wird
  nur Standard, wenn noch kein anderer eingerichtet ist; umschalten mit
  `sudo dpkg-reconfigure querencia-anmeldung`
  (`/usr/share/doc/querencia-anmeldung/umschalten.md`).
- Diagnose ohne Start: `querencia-session --check`.

Weitere Hinweise (NetworkManager auf Servern, Koexistenz mit GNOME):
`/usr/share/doc/querencia-desktop/README.Debian`.

## 3. Entfernen

Wer `querencia-anmeldung` als Anmeldebildschirm benutzt, schaltet zuerst
auf den vorigen zurück (`sudo dpkg-reconfigure querencia-anmeldung`) und
entfernt das Paket dann mit `sudo apt purge querencia-anmeldung`.

```bash
sudo apt purge querencia-desktop && sudo apt autoremove --purge
```

Das Metapaket hat die übrigen Querencia-Pakete als Abhängigkeiten
mitgebracht; `autoremove` entfernt sie mit. Benutzerdateien unter
`~/.config/querencia` und `~/.local/state/querencia` bleiben.

Quelle und Schlüssel austragen:

```bash
sudo rm -f /etc/apt/sources.list.d/querencia.sources /etc/apt/keyrings/querencia.gpg && sudo apt update
```

## 4. Signierschlüssel (pottrauschen)

Der private Schlüssel bleibt bei pottrauschen. Keine Session erzeugt, sieht oder
benutzt ihn; die Werkzeuge bekommen nur den Ordner und den Fingerabdruck,
wenn pottrauschen selbst signiert.

### 4.1 Erzeugen

Eigenschaften: Ed25519, nur Signieren und Zertifizieren (kein
Verschlüsselungsteil), Ablauf nach 2 Jahren, Kennung
`Querencia Desktop Archive Signing Key <archive@querencialinux.org>`
(ENTSCHEIDUNGEN Nr. 22; ein Postfach dahinter ist nicht nötig). Der
Schlüssel liegt in einem eigenen GnuPG-Ordner, nicht in `~/.gnupg`, am
besten auf einem verschlüsselten USB-Stick, der nur zum Signieren
eingesteckt ist. `<ORDNER>` ist dieser Ordner (Beispiel
`/media/user/<stick>/querencia-gnupg`). Auf entwicklungs-vm laufen
Sessions als Benutzer user und können dessen Dateien lesen; deshalb
den Stick nach dem Signieren wieder abziehen und den Schlüssel immer mit
Passphrase schützen.

```bash
install -d -m 0700 <ORDNER>
```

```bash
gpg --homedir <ORDNER> --quick-gen-key 'Querencia Desktop Archive Signing Key <archive@querencialinux.org>' ed25519 sign 2y
```

gpg fragt nach einer Passphrase: eine lange, nur in pottrauschens
Passwortmanager. Fingerabdruck anzeigen:

```bash
gpg --homedir <ORDNER> --list-keys --with-colons | awk -F: '/^fpr/ {print $10; exit}'
```

### 4.2 Sichern

- gpg legt beim Erzeugen ein **Widerrufszertifikat** an:
  `<ORDNER>/openpgp-revocs.d/<FINGERABDRUCK>.rev`. Davon eine Kopie getrennt
  vom Schlüssel aufbewahren (zweites Medium oder ausgedruckt).
- Den ganzen Ordner `<ORDNER>` auf ein zweites verschlüsseltes Medium
  kopieren. Ohne Sicherung lässt sich die Quelle nach einem Verlust nur mit
  einem neuen Schlüssel weiterführen, den jeder Client neu einspielen muss.
- Nie ins Git, nie in `~/review`, nie in einen von Sessions gelesenen
  Ordner, nie in eine Cloud ohne eigene Verschlüsselung.

### 4.3 Öffentlichen Schlüssel verteilen

Den öffentlichen Teil exportiert `quelle-bauen.sh` bei jedem Lauf nach
`querencia.gpg` und `querencia.asc` in die Quelle; er wird mit
hochgeladen. Zusätzlich:

- **Packaging-Repo:** `querencia.asc` als `apt/querencia.asc` einchecken und
  den Fingerabdruck in diese Datei (Tabelle oben) eintragen.
- **Webseite:** Fingerabdruck und Link auf
  `https://dl.querencialinux.org/apt/querencia.asc` auf die Downloadseite.
  Clients vergleichen gegen diese zweite Quelle (§1).

### 4.4 Verlängern, ersetzen, widerrufen

- **Verlängern** (vor Ablauf; `quelle-bauen.sh` warnt 60 Tage vorher):
  `gpg --homedir <ORDNER> --quick-set-expire <FINGERABDRUCK> 2y`, dann
  Quelle neu bauen und hochladen. Clients holen den verlängerten Schlüssel
  nicht selbst: sie spielen `querencia.gpg` erneut ein (§1, zweiter
  Befehl). Ein späteres Paket `querencia-archive-keyring` würde das über
  apt erledigen (offen).
- **Kompromittiert:** Widerrufszertifikat veröffentlichen, neuen Schlüssel
  erzeugen, Quelle neu signieren, Clients informieren.

## 5. Quelle bauen, prüfen, hochladen (Betreuer)

Die Werkzeuge liegen unter `werkzeuge/apt/`, laufen ohne root und
installieren nichts. Jedes hat `--help`.

| Werkzeug | Zweck |
|---|---|
| `quelle-bauen.sh` | Satz `.deb` → Repo-Ordner mit `pool/`, `dists/resolute/main/binary-{amd64,all}/Packages{,.gz,.xz}`, `Contents-{amd64,all}{,.gz}`, `by-hash/SHA256/`, `Release`, `InRelease`, `Release.gpg`, `querencia.{gpg,asc,sources}` |
| `quelle-pruefen.sh` | Struktur, Hashes, Signatur, apt über `file://` und über einen lokalen `http.server` unter `/apt/`, Download aller Pakete, Auflösung auf einem frischen System (leerer dpkg-Status + Ubuntu-Listen des Rechners), Gegenproben (manipuliert, fremder Schlüssel, unsigniert); `--installieren` zusätzlich `tests/wegwerf-installation.sh`; mit einer URL statt eines Ordners prüft es den Server |
| `quelle-hochladen.sh` | Upload nach R2 per `wrangler r2 object put --remote`, mit `--trockenlauf` |

Ablauf mit dem freigegebenen Paketsatz (`<DEBS>`: Ordner mit `.deb` und
`SHA256SUMS`, `<REPO>`: Arbeitsordner der Quelle, bleibt zwischen den
Läufen liegen, z. B. `~/querencia-apt/repo`):

```bash
bash werkzeuge/apt/quelle-bauen.sh --ziel <REPO> --gnupghome <ORDNER> --schluessel <FINGERABDRUCK> <DEBS>
```

```bash
bash werkzeuge/apt/quelle-pruefen.sh --fingerabdruck <FINGERABDRUCK> --installieren <REPO>
```

```bash
bash werkzeuge/apt/quelle-hochladen.sh --trockenlauf --fingerabdruck <FINGERABDRUCK> <REPO>
```

```bash
bash werkzeuge/apt/quelle-hochladen.sh --fingerabdruck <FINGERABDRUCK> <REPO>
```

```bash
bash werkzeuge/apt/quelle-pruefen.sh --fingerabdruck <FINGERABDRUCK> https://dl.querencialinux.org/apt
```

### Regeln der Werkzeuge

- **Index = übergebener Satz.** Pakete früherer Läufe bleiben im Pool (und
  auf dem Server) liegen, stehen aber nicht mehr im Index; `quelle-bauen.sh`
  meldet sie. Ein älteres Paket wieder anbieten: es in den Satz aufnehmen.
- **Unveränderlich:** Eine Pool-Datei wird nie mit anderem Inhalt
  ersetzt, weder lokal noch auf dem Server (beide Werkzeuge brechen ab). Ein
  geändertes Paket bekommt eine neue Version.
- **Idempotent:** Gleicher Satz → gleicher Baum (Inhalt, Rechte,
  Zeitstempel); Release und Signaturen bleiben dann unverändert. Ein
  geänderter Index wird neu signiert; das Datum muss später liegen als das
  vorige (apt lehnt ältere Release-Dateien ab). Für ein festes Datum
  `SOURCE_DATE_EPOCH` setzen.
- **Kein Valid-Until:** Die Quelle wird von Hand signiert; ein Ablaufdatum
  würde Clients aussperren, sobald eine Neusignatur ausbleibt.
  `--gueltig-tage <n>` setzt eines, wenn später automatisch signiert wird;
  dann signiert jeder Lauf neu (neues Datum und Valid-Until), auch bei
  gleichem Satz.
- **Genau ein Schlüssel:** `quelle-pruefen.sh` und `quelle-hochladen.sh`
  brechen ab, wenn `querencia.gpg` mehr als einen Hauptschlüssel enthält
  oder InRelease/Release.gpg nicht vom erwarteten Fingerabdruck signiert
  sind (gpgv nähme jeden Schlüssel im Keyring an).
- **Nur SHA256 in Release, Acquire-By-Hash:** apt lädt Indexdateien über
  `by-hash/SHA256/<hash>` (immer mit dem stärksten Hash aus Release). Alte
  by-hash-Dateien bleiben liegen, damit Clients während eines Uploads
  passende Dateien finden.
- **Contents auch unkomprimiert:** apt 3.2 lädt Contents (für apt-file) nur,
  wenn Release den unkomprimierten Schlüssel führt.
- **Signatur:** `gpg --batch --pinentry-mode loopback`, nie ein
  Agent-Dialog. Die Passphrase kommt aus `--passphrase-datei` oder wird am
  Terminal einmal abgefragt; ein eigener Agent für `<ORDNER>` wird am Ende
  beendet (vergisst die Passphrase).
- **Werkzeuge:** reprepro, aptly und apt-utils (`apt-ftparchive`) sind auf
  entwicklungs-vm nicht installiert. `Packages` erzeugt `dpkg-scanpackages`,
  Contents und Release erzeugt `quelle-bauen.sh` selbst.

### Upload

- Reihenfolge: `pool/` → `by-hash/` → Indexdateien → Schlüssel und Vorlage
  → `Release`, `Release.gpg` → `InRelease` zuletzt. Ein abgebrochener
  Upload lässt die Quelle konsistent (alte InRelease zeigt auf vorhandene
  by-hash-Dateien); Lauf einfach wiederholen.
- Vorher prüft das Skript Signatur, Fingerabdruck und Hashes und fragt per
  HEAD den Server: Pool- und by-hash-Dateien, die schon dort liegen (gleiche
  Größe, bei einfachem ETag gleiche MD5), entfallen. Antwortet der Server
  nicht eindeutig (weder 200 noch 404), lädt es nichts hoch.
- Content-Type: `.deb` `application/vnd.debian.binary-package`, `.gz`
  `application/gzip`, `.xz` `application/x-xz`, `Release.gpg`
  `application/pgp-signature`, Schlüssel `application/pgp-keys`, by-hash
  `application/octet-stream`, sonst `text/plain; charset=utf-8`.
- Cache-Control: Pool und by-hash `public, max-age=31536000, immutable`,
  Indexdateien und Release `no-cache`, Schlüssel und Vorlage eine Stunde.
  Die Domain cacht heute nicht (`cf-cache-status: DYNAMIC`); die Angaben
  gelten für Proxys und spätere Cache-Regeln.
- Gelöscht wird nie etwas. wrangler muss angemeldet sein
  (`npx wrangler whoami`); eine Datei darf höchstens 300 MiB groß sein.
- Der Bucket enthält außerdem die beiden ISO-Abbilder von Querencia Linux
  (Wurzel, `querencia-linux-*-20260315.iso`); die Quelle liegt getrennt unter
  `apt/`.

## Nachtrag 24.10.2026: Alpha 3

Am 24.10.2026 um 12:18:49 (MESZ) ging der Index von Alpha 3 auf den Server: Satz
`debs-beta-3` (Tag `packaging/alpha3-2`, 22 Pakete, `SHA256SUMS` mit der Summe
`488348b6…`), Metapaket `querencia-desktop 0.1.0~alpha3-1`, dazu Querencia Dateien
0.2.0-1 und Querencia Files 0.2.0-1 als Übergangspaket.

| Was | Wert |
|---|---|
| Release-Datum | Sat, 24 Oct 2026 10:04:01 UTC (vorher Alpha 2.1: 22 Oct 2026 08:55:57 UTC) |
| InRelease (SHA256) | `6ab038d29be1b2aff1305da4b3f3863af7a70a09f215f79c4ee675a51ca1d0bc` |
| Index | binary-amd64 22, binary-all 5; Pool 67 Dateien, davon 9 neu; ältere Fassungen bleiben liegen |
| Upload | 37 Dateien (27115 KiB), 88 lagen schon auf dem Server, nichts gelöscht |
| Prüfung | lokal 22/1 (bekannt: `querencia-anmeldung` in der Wegwerf-Hülle), Server 10/0 |

- **Passphrase:** `quelle-bauen.sh` öffnet kein pinentry-Fenster. Es fragt
  einmal mit `read -s` an `/dev/tty`. Aus einer Werkstatt-Sitzung heraus läuft
  der Bau deshalb in einem Reiter des Terminal-Bereichs der App, und pottrauschen
  tippt die Passphrase dort ein. Ohne Terminal und ohne `--passphrase-datei`
  scheitert das Signieren.
- **Rückfall:** Den Index von Alpha 2.1 sauber wieder anbieten heißt, die Quelle
  mit dem Satz `debs-final-alpha21` neu zu bauen (neues Datum, neue Signatur) und
  hochzuladen. Werden nur die alten Release-Dateien zurückgeschrieben, hilft das
  bloß Clients, die Alpha 3 noch nicht geholt haben. Ein Client mit dem
  Alpha-3-Index übernimmt die ältere Release-Datei nicht und behält Alpha 3,
  ohne Fehlermeldung (Wegwerf-apt-Probe am 24.10.2026).

## Nachtrag 24.10.2026: Alpha 3.1

Am 24.10.2026 um 14:48:53 (MESZ) ging der Index von Alpha 3.1 auf den Server: Satz
`debs-alpha31-1` (Tag `packaging/alpha31-1`, 23 Pakete, `SHA256SUMS` mit der Summe
`f87a4a5f…`). Neu gegenüber Alpha 3 sind `querencia-desktop 0.1.0~alpha3.1-1`,
`querencia-dateien 0.2.1-1` und `querencia-webhuelle 0.2.0-1`. Die übrigen 20 Pakete
lagen byte-gleich im Pool.

| Was | Wert |
|---|---|
| Release-Datum | Sat, 24 Oct 2026 12:04:07 UTC |
| InRelease (SHA256) | `9e25de04ed44a6d9125d44c8ff2e284782fdd04bea65abe1a3698e0bfa67b9f9` |
| Index | binary-amd64 23, binary-all 5; Pool 70 Dateien, davon 3 neu |
| Upload | 29 Dateien (1594 KiB), 107 lagen schon auf dem Server, nichts gelöscht |
| Prüfung | lokal 22/1 (bekannt: `querencia-anmeldung` in der Wegwerf-Hülle), Server 10/0 |

`querencia-webhuelle` steht im Index, aber kein Paket hängt davon ab, auch das
Metapaket nicht. `apt install querencia-desktop` installiert sie deshalb nicht mit.

## Nachtrag 26.10.2026: Alpha 3.2

Am 26.10.2026 um 22:11:10 (MEZ) ging der Index von Alpha 3.2 auf den Server: Satz
`debs-alpha32-1` (Tag `packaging/alpha32-1`, 24 Pakete, `SHA256SUMS` mit der
Summe `fbf26227…`). Neu gegenüber Alpha 3.1 sind vier Pakete:

| Paket | Version | Änderung |
|---|---|---|
| `querencia-desktop` | 0.1.0~alpha3.2-1 | nur Version und Versionsdatei „Alpha 3.2“ |
| `querencia-dateien` | 0.2.2-1 | Kontextmenüs springen nicht mehr in die Menüleiste; Titel „Netzwerk“ |
| `querencia-schnatter` | 0.3.0-1 | neu, optional: Schnatter, so heißt die Webhülle jetzt |
| `querencia-webhuelle` | 0.3.0-1 | Übergangspaket auf `querencia-schnatter` (Architecture all) |

Die übrigen 20 Pakete lagen byte-gleich im Pool.

| Was | Wert |
|---|---|
| Release-Datum | Mon, 26 Oct 2026 09:35:14 UTC |
| InRelease (SHA256) | `d67cfaa70b4cc0f1ec2a950da24aaf5ab822d4325dbf0bbd7bf378d3e33a85ed` |
| Index | binary-amd64 24, binary-all 6; Pool 74 Dateien, davon 4 neu; ältere Fassungen bleiben liegen |
| Upload | 32 Dateien (1689 KiB), 118 lagen schon auf dem Server, nichts gelöscht |
| Prüfung | lokal 22/1 (bekannt: `querencia-anmeldung` in der Wegwerf-Hülle), Server 10/0 |

Vor dem Upload liefen Neuinstallation und Upgrade 3.1 → 3.2 (mit Webhülle 0.2.0
aus der veröffentlichten Quelle) in einer frischen Ubuntu-VM; beides ohne
Rückfrage, beim Upgrade nichts entfernt.

- **Schnatter bleibt optional.** Das Metapaket nennt es nicht;
  `apt install querencia-desktop` installiert es nicht. Wer die Webhülle 0.2.0
  installiert hat, bekommt mit dem Upgrade das Übergangspaket
  `querencia-webhuelle` 0.3.0-1 und damit Schnatter. Schnatter übernimmt beim
  ersten Start Anmeldung und Einstellungen, indem es die Ordner umbenennt.
  Wer die Webhülle nicht hatte, bekommt nichts Neues dazu.
- **Einzeln installieren:** `sudo apt install querencia-schnatter`.
- **autoremove:** Nach dem Upgrade meldet apt `querencia-webhuelle` als nicht
  mehr benötigt (apt überträgt die Markierung „manuell“ auf
  `querencia-schnatter`). Als Kandidat für `sudo apt autoremove` nennt es nur
  das Übergangspaket; Schnatter ist manuell markiert (VM-Probe 26.10.2026,
  autoremove selbst nicht ausgeführt).

## Nachtrag [Datum]: Alpha 3.3 (Entwurf)

*Entwurf des Packaging-Workers; Datum, Uhrzeit, InRelease-Summe und Upload-Zahlen
trägt der Betreuer der Quelle nach dem Upload ein.*

Am [Datum] um [Uhrzeit] ging der Index von Alpha 3.3 auf den Server: Satz
`debs-alpha33-2` (Tag `packaging/alpha33-2`, 24 Pakete, `SHA256SUMS` mit der
Summe `ad018bf1…`). Alpha 3.3 bringt **fünf Sprachen**: Alle Programme, das Panel
und die Arbeitsfläche sprechen Deutsch, Englisch, Italienisch, Spanisch und
Französisch. Neu gegenüber Alpha 3.2 sind 18 Pakete:

| Paket | Version | Änderung |
|---|---|---|
| `querencia-desktop` | 0.1.0~alpha3.3-1 | Versionsdatei „Alpha 3.3“; empfiehlt neu `locales-all` |
| `querencia-shell` | 0.1.0~alpha11-1 | Panel 0.4.0 mit Infobereich; Panel und Arbeitsfläche it/es/fr |
| `querencia-dateien` | 0.2.4-1 | it/es/fr; Kompaktansicht kürzt Namen nicht mehr; Statusleiste nach der Suche |
| `querencia-anmeldung` | 0.1.3-1 | Anmeldebildschirm durchgehend Deutsch oder Englisch (wahlweise) |
| `querencia-schnatter` | 0.3.1-1 | it/es/fr (wahlweise) |
| übrige 13 Programme | neue Versionen | it/es/fr (Editor, Terminal, Sitzung, Einstellungen, Software, Rechner, Bilder, Dokumente, Archiv, Systemmonitor, Dateisuche, Screenshot, Benachrichtigungen) |

Byte-gleich im Pool blieben `labwc`, `querencia-session`, `-symbole`,
`-hintergruende`, `-files` und `-webhuelle`.

| Was | Wert |
|---|---|
| Release-Datum | [Date aus InRelease] |
| InRelease (SHA256) | `[…]` |
| Index | binary-amd64 24, binary-all 6 (erwartet); Pool [n] Dateien, davon 18 neu |
| Upload | [n] Dateien ([n] KiB), [n] lagen schon auf dem Server, nichts gelöscht |
| Prüfung | lokal [n/n], Server [n/n] |

- **Sprache:** Welche Sprache gilt, bestimmt die Spracheinstellung des Systems
  (Einstellungen → „Sprache und Region“). Das Metapaket empfiehlt `locales-all`,
  damit `it_IT`, `es_ES` und `fr_FR` dort wählbar sind (rund 230 MB auf der
  Platte). `apt full-upgrade` installiert es beim Upgrade mit; wer mit
  `--no-install-recommends` installiert, bekommt es nicht.
- **GTK-eigene Texte** (Dateidialog, Tastennamen im Dialog) kommen aus
  `language-pack-gnome-<xx>` des Systems, nicht aus dem Metapaket.
- **Infobereich:** Im Standard-Panel oben rechts vor der Glocke. Wer das Panel
  schon angepasst hat, fügt ihn über „Zum Panel hinzufügen“ hinzu; das Paket
  ändert die gespeicherte Anordnung nicht.
- **Noch fest deutsch:** Sperrbildschirm, Fenster des Lautstärkereglers,
  Tastenkürzel-Hilfe.
- **Software:** Thunderbird und Firefox stehen mit eigener Beschreibung im
  Software-Center; ohne die Paketquelle des Mozilla-Teams bzw. von Mozilla
  zeigen sie „Nicht verfügbar“ (keine Snap-Hüllen).
