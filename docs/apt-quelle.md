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
  `--gueltig-tage <n>` setzt eines, wenn später automatisch signiert wird.
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
