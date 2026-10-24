# Querencia Dateien nachziehen – Beta-Stand und Ablösung von Files

Stand Alpha 3 (Zweig `dateien-beta`, 24.10.2026): `querencia-dateien` 0.2.0-1 aus runtime
`dateien/0.2.0`, Shell 0.1.0~alpha10-1 aus runtime main `801a016` (besitzt die gemeinsamen
Kataloge), `querencia-files` 0.2.0-1 als Übergangspaket, Session 0.1.0~alpha10 (Ordnerprogramm Dateien in der
Quelle seit `session/alpha9`), Sitzung 0.1.8, Symbole 0.8, Metapaket 0.1.0~alpha3-1 (Satz `debs-beta-2`). Davor (Vorbau 23.10.): Dateien 0.1.0-1
aus `dateien/0.1.0-2` (`f9a3cda`), Files als Brücke (0.1.0~alpha8-2). Diese Liste beschreibt, wie ein
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

**Umgesetzt in Alpha 3: A** (Entscheidung der Startsession). Shell 0.1.0~alpha10 besitzt die
beiden Kataloge (`Replaces`/`Breaks: querencia-dateien (<< 0.2.0)`), Dateien 0.2.0 hängt von
`querencia-shell (>= 0.1.0~alpha10)` ab. Weil die Shell die Kataloge auch für Dateien liefert,
müssen Shell- und Dateien-Commit dieselben Bibliotheks-Kataloge haben – vor jedem Nachzug von
Dateien ohne Shell-Neubau prüfen (leer = passt):

```bash
git -C ~/projects/querencia-runtime diff <shell-commit> <dateien-tag> -- crates/querencia-oberflaeche/po crates/querencia-dateiarbeit/po
```

## 4. Files ausgemustert (Alpha 3)

Seit Alpha 3 (Satz `debs-beta-1`, 24.10.2026) wird Files nicht mehr ausgeliefert
(Vorgabe des Besitzers):

- `querencia-files` 0.2.0-1 ist ein **Übergangspaket** (Section `oldlibs`, Architecture `all`)
  aus dem Projekt-Repository wie das Metapaket – kein Strata-Code, kein Files-Quellarchiv,
  keine MetaInfo. Es enthält nur die beiden Brücken-Starter `org.querencia.Files.desktop` und
  `io.github.lgse.Strata.desktop` (versteckt, ohne MIME-Typen, `Exec=querencia-dateien %U`,
  `TryExec=querencia-dateien`, `StartupWMClass=org.querencia.Dateien`) und hängt von
  `querencia-dateien` ab. Ein Upgrade von Alpha 2.1/2.2 ersetzt das alte Paket (der Befehl
  `querencia-files`, Paketmarke, MetaInfo und Lizenztexte von Strata verschwinden); alte
  Verknüpfungen im Panel, auf der Arbeitsfläche und in einer `~/.config/mimeapps.list` öffnen
  Dateien.
- Gewählt nach der Upgrade-Probe statt „Brücken in querencia-dateien plus
  `Replaces`/`Breaks: querencia-files`“: Das Übergangspaket kommt mit `apt upgrade` aus (keine
  Entfernung nötig); `Breaks` verlangt eine Entfernung, die nur `full-upgrade` macht – `apt
  upgrade` hielte dann Metapaket und Dateien zurück (Bericht `packaging-beta-bericht.md` §2).
- Neuinstallation: Weder das Metapaket noch eine Empfehlung zieht `querencia-files`.
- `apt autoremove` lässt das Übergangspaket stehen, weil `querencia-shell` es unter `Suggests`
  nennt (`APT::AutoRemove::SuggestsImportant`). **Diese Zeile stehen lassen**, solange die
  Brücken gebraucht werden.
- `pakete-pruefen.sh` nimmt `querencia-files` von der MetaInfo-Pflicht aus (Übergangspaket);
  `org.querencia.Dateien` nennt `org.querencia.Files` unter `<replaces>`.
- **Später ganz entfernen:** `querencia-files` aus dem Satz und aus `quellen.conf` nehmen, die
  `Suggests`-Zeile der Shell streichen, Release Notes „`sudo apt remove querencia-files`“.
  Vorher müssen Sitzung oder Dateien Nennungen von `io.github.lgse.Strata.desktop` und
  `org.querencia.Files.desktop` in `~/.config/mimeapps.list` und in Panel-Startern umschreiben
  (QD-059/QD-138), sonst bleibt bei solchen Benutzern das Ordnerprogramm leer.

## 5. Kandidat und Prüfung

```bash
bash build/nachweis-beta/satz-zusammenstellen.sh build/debs-<name> querencia-dateien [querencia-shell …]
```

```bash
TMPDIR=$PWD/build/tmp PRUEF_DEBS=$PWD/build/debs-<name> bash build/nachweis-beta/pruef-alles.sh build/nachweis-<name>/pruefung
```

```bash
TMPDIR=$PWD/build/tmp bash tests/wegwerf-upgrade.sh $PWD/build/nachweis-<name>/upgrade-22 <alter satz> $PWD/build/debs-<name>
```

`satz-zusammenstellen.sh` und `pruef-alles.sh` liegen unter `build/nachweis-beta/` (Alpha 3; nicht
im Git, Kopie in den Belegen ); Vorgänger ist dort der Vorbau
`build/debs`, der alte Satz der Upgrade-Probe der zuletzt veröffentlichte (Alpha 2.1, mit
`UPGRADE_VORHER_ORDNER=io.github.lgse.Strata.desktop`) bzw. Alpha-2.2-Kandidat 2.
Erwartung: pakete-pruefen ohne FAIL, Lintian ohne E, Upgrade-Probe ohne FAIL, `inode/directory`
→ `org.querencia.Dateien.desktop`.
