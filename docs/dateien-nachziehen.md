# Querencia Dateien nachziehen – Beta-Stand und Ablösung von Files

Stand Welle C (Zweig `dateien-beta`, 23.10.2026): `querencia-dateien` 0.1.0-1 aus runtime
`dateien/0.1.0-2` (`f9a3cda`), Files als Brücke (0.1.0~alpha8-2), Session mit Ordnerprogramm
Dateien (0.1.0~alpha8-2), Symbole 0.8, Metapaket 0.1.0~alpha3-1. Diese Liste beschreibt, wie ein
späterer Stand von Dateien (Beta der Welle C: Netzwerk, Miniaturen/Suche, Reiter/Kompakt,
Migration) ohne Umbau nachgezogen wird, und was beim Entfernen von Files zu tun ist.

## 1. Vorbedingungen

- [ ] Die Zweige der Welle C sind in runtime `main` zusammengeführt, getaggt (z. B.
      `dateien/0.2.0`) und von der Status-Session freigegeben. Nur geprüfte Stände kommen in
      `quellen.conf`.
- [ ] Voller Hash: `git -C ~/projects/querencia-runtime rev-parse <tag>^{commit}`. Liegen mehrere
      Tags vor, einen Commit nehmen, der alle enthält (`git merge-base --is-ancestor`).
- [ ] Upstream-Version aus `crates/querencia-dateien/Cargo.toml` (und dem CHANGELOG des Crates).

## 2. Dateien

1. `quellen.conf`: Zeile `querencia-dateien` auf Commit und Upstream-Version.
2. `bash werkzeuge/orig-erzeugen.sh querencia-dateien` – vendort neu (Welle C kann Crates
   mitbringen) und schreibt `debian/copyright` und `debian/upstream-commit`. Die Ausgabe nennt
   entfernte Fremdarchive und neue Lizenzabsätze; neue Lizenzen in `copyright.in` nur, wenn das
   Werkzeug keinen Text findet.
3. `debian/changelog`: neuer Eintrag `<version>-1`, nutzerlesbar, ohne interne Kennungen
   (`pruef-alles.sh` sucht danach). Datum vor dem Bau.
4. `debian/rules` prüfen:
   - Bringt der Starter upstream selbst `MimeType=inode/directory` mit, bleibt
     `desktop-file-edit --add-mime-type` wirkungslos (fügt nichts doppelt ein); die `grep`-Proben
     danach bleiben.
   - Neue Crates der Welle C, deren Tests mitlaufen sollen, als weiteres `-p` in
     `CARGO_FEATURES`; neue Textdomänen mit `mo_install` (das Programm bindet alle an
     `/usr/share/locale`, siehe `src/i18n.rs`).
   - Neue Laufzeitprogramme: Miniaturen für PDF/Video brauchen Thumbnailer
     (Recherche C, R5) – als `Recommends` in `debian/control` (z. B. `ffmpegthumbnailer`,
     `poppler`-Thumbnailer), nicht als `Depends`. SFTP/SMB laufen über GVfs (`gvfs-backends` steht
     schon in `Recommends`).
5. `common/metainfo/org.querencia.Dateien.metainfo.xml`: `<release>` ergänzen; Beschreibung,
   wenn Netzwerk, Reiter oder Suche dazukommen.
6. `debian/querencia-dateien.1`: Abschnitt KEYS (Strg+3 Kompakt, Strg+T Reiter) und neue
   Dateien nachtragen.
7. Bauen: `bash werkzeuge/paket-bauen.sh querencia-dateien` (Build-Lock über
   `~/.local/state/querencia/bau-platz.sh`).

## 3. Geteilte Kataloge – Shell aus runtime main

`querencia-dateien` liefert neben `querencia-dateien.mo` die Kataloge der Bibliotheken
`querencia-oberflaeche` und `querencia-dateiarbeit`. Die Shell bis 0.1.0~alpha9 (runtime
`a1b3e53`) kennt beide Bibliotheken nicht. **Wird die Shell aus runtime `main` ≥ `f9a3cda` neu
gebaut, nutzen Panel und Arbeitsfläche dieselben Bibliotheken** und brauchen dieselben zwei
Kataloge – zwei Pakete mit derselben Datei bricht `dpkg` ab (`pakete-pruefen.sh`: „keine Datei in
zwei Paketen“). Eine Stelle muss sie besitzen:

- **A (Empfehlung): die Shell.** `querencia-shell` installiert
  `querencia-oberflaeche.mo` und `querencia-dateiarbeit.mo` und bekommt
  `Replaces: querencia-dateien (<< <neue Dateien-Version>)` und
  `Breaks: querencia-dateien (<< <neue Dateien-Version>)`; `querencia-dateien` lässt die beiden
  `mo_install`-Zeilen weg und bekommt `Depends: querencia-shell (>= <neue Shell-Version>)`.
  Beide Pakete im selben Satz.
- B: Dateien behält sie, die Shell hängt für die deutschen Texte von `querencia-dateien` ab
  (zieht den Dateimanager in jede Shell-Installation).
- C: Upstream-Änderung (Runtime): Dateien bindet die beiden Bibliotheksdomänen an ein eigenes
  Verzeichnis. Nur mit Runtime-Worker und Freigabe.

Mit der neuen Shell kommt auch M3 (Panel-Orte und Fensterliste kennen
`org.querencia.Dateien.desktop`; die Arbeitsfläche ab runtime `f9a3cda` schon).

## 4. Files als Brücke und Entfernen

- In der Ausgabe mit Dateien bleibt `querencia-files` 0.1.0~alpha8-2 (unveränderte Datei bei
  einem Beta-Nachzug). Beide Starter sind versteckte Brücken ohne MIME-Typen auf
  `querencia-dateien %U`; `querencia-files` hängt von `querencia-dateien` ab.
- Neuinstallation: Weder das Metapaket noch eine Empfehlung zieht Files (Session und Dateisuche
  empfehlen seit 0.1.0~alpha8-2 bzw. 0.1.5-2 `querencia-dateien`). Nur `querencia-shell` nennt
  `querencia-files` unter `Suggests` – das installiert apt nicht von selbst.
- Upgrade: `apt autoremove` lässt `querencia-files` stehen, weil apt Pakete schützt, die ein
  installiertes Paket vorschlägt (`APT::AutoRemove::SuggestsImportant`, Vorgabe `true`); ohne den
  Schutz schlüge es Files vor (gemessen, `tests/wegwerf-upgrade.sh`). Die Brücken bleiben also, bis
  der Benutzer Files entfernt. **Bei einem Shell-Neubau aus runtime main `Suggests:
  querencia-files` für die Brückenausgabe stehen lassen**, sonst geht Files mit `autoremove`.
- **Eine Ausgabe später:** `querencia-files` aus dem Satz nehmen (die Pool-Datei bleibt liegen),
  Zeile in `quellen.conf` löschen, `common/metainfo/org.querencia.Files.metainfo.xml` löschen,
  Release Notes: „Files entfällt; `sudo apt remove querencia-files`“. Vorher muss die Sitzung oder
  Dateien Nennungen von `io.github.lgse.Strata.desktop` und `org.querencia.Files.desktop` in
  `~/.config/mimeapps.list` umschreiben (QD-059/QD-138), sonst bleibt bei solchen Benutzern das
  Ordnerprogramm leer.

## 5. Kandidat und Prüfung

```bash
bash build/nachweis/satz-zusammenstellen.sh build/debs-<name> querencia-dateien [querencia-shell …]
```

```bash
TMPDIR=$PWD/build/tmp PRUEF_DEBS=$PWD/build/debs-<name> bash build/nachweis/pruef-alles.sh build/nachweis/pruefung-<name>
```

```bash
TMPDIR=/tmp/claude-$(id -u) bash tests/wegwerf-upgrade.sh build/nachweis/upgrade-<name> <alter satz> build/debs-<name>
```

`satz-zusammenstellen.sh` und `pruef-alles.sh` liegen unter `build/nachweis/` (nicht im Git, Kopie
in den Belegen); der alte Satz ist der zuletzt veröffentlichte (oder Alpha-2.2-Kandidat 2).
Erwartung: pakete-pruefen ohne FAIL, Lintian ohne E, Upgrade-Probe ohne FAIL, `inode/directory`
→ `org.querencia.Dateien.desktop`.
