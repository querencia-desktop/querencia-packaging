# Alpha 2.1 nachziehen – Checkliste je fertigem Tag

Grundlage ist Kandidat 1 (Tag `packaging/alpha-2.1-kandidat-1`): Alpha 2 plus
Desktop 0.2.3, Versionsdatei und Anmeldung 0.1.2-1. Für jeden Tag, den die Welle Alpha 2.1 fertig
meldet, gehen diese Schritte im Worktree `~/projects/querencia-packaging-wt-alpha21`
(Zweig `alpha21`) einmal durch. Mehrere Tags dürfen in einem Durchgang landen.

## 0. Vorbedingungen

- [ ] Der Tag ist annotiert, existiert im Arbeits-Repository (Spalte `<repository>` in
      `quellen.conf`) und gilt als geprüft und aktiviert (Journal der Status-Session).
      Nur geprüfte Stände kommen in `quellen.conf`.
- [ ] `git -C ~/projects/<repo> rev-parse <tag>^{commit}` notieren (voller Hash).
- [ ] Ist die Komponente Teil eines Sammel-Repos (`querencia-runtime`: Panel, Desktop,
      Tastenkürzel, Lautstärke, Netzwerk), nimm einen Commit, der **alle** schon
      gemeldeten Tags enthält. Für jeden Tag `git merge-base --is-ancestor <tag> <commit>`
      prüfen. Meist ist das der Merge-Commit der Status-Session auf `main`.

## 1. Zuordnung Tag → Quellpaket

**Stand Kandidat 2 (Tag `packaging/alpha-2.1-kandidat-2`):** Alle Zeilen der Tabelle sind
eingetragen, die Shell aus runtime main `a2eebc8` mit Panel 0.2.3, Desktop 0.2.4 und
Kürzel 0.2.1. Weitere Tags gehen über diese Liste in Kandidat 3. Die Spalte „heute“ gibt
den Stand von Kandidat 1 an.

| Welle | Quellpaket | Repository | heute (Kandidat 1) | beachten |
|---|---|---|---|---|
| Panel 0.2.2/0.2.3, Desktop 0.2.4, Kürzel 0.2.1 | querencia-shell | querencia-runtime | `desktop/0.2.3` e38f402, 0.1.0~alpha8 | ein Commit für alle drei; Patch 0001 (Quellbaum-Rückfall) prüfen |
| Files QF-0s | querencia-files | querencia-files-dev | qf-0r-1 1ca5c0a, 0.1.0~alpha6 | Upstream 0.1.0~alpha7; Fremd-Toolchain 1.98.1 (alle-bauen setzt sie); Patch `0001-ausgabe-alpha-2-1` (fester Text „Alpha 2“ in `src/build_info.rs`) prüfen, er entfällt, wenn Files die Versionsdatei liest |
| Einstellungen 0.1.5 | querencia-einstellungen | querencia-einstellungen | 0.1.4 | liest `/usr/share/querencia/release` (docs/versionsdatei.md) |
| Software 0.1.5 | querencia-software | querencia-software (+ Bausteine in `komponenten.conf`) | 0.1.4 | Baustein-Commits in `querencia-software/komponenten.conf` mitziehen |
| Editor, Bilder, Dateisuche, Dokumente, Archiv, Rechner, Systemmonitor | je eigenes Paket | je eigenes Repo | Alpha 2 | bringt das Repo eine eigene MetaInfo mit, `metainfo_install` → `metainfo_install_from,data,…` umstellen; Patch `0001-metainfo-homepage` (Archiv, Dokumente) entfällt, wenn die Homepage im Repo stimmt |
| Terminal 0.3.1 | querencia-terminal | querencia-terminal-dev | 0.3.0-2 | Patch `0001-metainfo-homepage` und `series` löschen, falls die Homepage im Repo stimmt, sonst neu schneiden |
| Screenshot (neue Version) | querencia-screenshot | querencia-screenshot-dev | 0.2.9-2 | wie Terminal |
| Sitzung 0.1.4 | querencia-sitzung | querencia-sitzung | 0.1.3-3 | – |
| Panel-Überwachung (Autostart) | querencia-session | querencia-werkstatt-w5-release/quellen/querencia-session | 0.1.0~alpha7-2 (ohne Überwachung) | `labwc/autostart` wie runtime `7ad985a` **und** `tests/run.sh` angepasst (3b/3c protokollieren sonst `--faehigkeiten`); nur ein neuer Quellstand mit beidem, kein Paket-Patch nur für den Autostart |
| Anmeldung | querencia-anmeldung | ReGreet + Komponente `querencia` (`komponenten.conf`) | **0.1.2-1 in Kandidat 1** (Komponente c489a15, Tag `anmeldung/0.1.2-int`) | nächste Version: Komponenten-Commit in `querencia-anmeldung/komponenten.conf` |

## 2. Eintragen

- [ ] `quellen.conf`: Spalte `<git-revision>` = voller Hash, `<upstream-version>` = Version
      des Tags (Debian-Schreibweise, `-` → `~` nur bei Vorabversionen). Kopfkommentar:
      Kandidatennummer und neue Tags nennen, ohne Rechnernamen.
- [ ] `<paket>/debian/changelog`: **ein** neuer Eintrag `<upstream>-1` (bzw. die nächste
      Revision, wenn nur `debian/` sich ändert). Datum `date -R`, Trailer
      `pottrauschen <147073098+pottrauschen@users.noreply.github.com>`.
      Inhalt für Nutzer:
      - was sich für Nutzer ändert, in ganzen Sätzen; Vorbild ist das CHANGELOG des Programms
      - **keine** internen Kennungen (`QD-…`, `G2-…`, `QREL`, `CLEAN-1`, `HMP-`, `QF-0…`), keine
        Rollen (Startsession, Status-Session, Worker, Besitzer), keine Rechnernamen, keine
        Ablage-Hashes, kein „Live-Stand“
      - kein Satz über nicht installierte KI-Abschnitte
      - Kandidaten zählen keine Revision hoch. Bis zum Einfrieren behält ein Paket seine
        Zielversion, auch wenn sich der Stand noch ändert. Kandidaten verlassen `build/`
        nicht, nur Wegwerf-VMs mit Rückfall auf den Snapshot. Erkennbar ist ein Kandidat
        an Tag und `SHA256SUMS`.
- [ ] `debian/control`: Depends/Recommends prüfen (neue Bibliotheken, Mindestversionen
      anderer Querencia-Pakete). `dpkg-checkbuilddeps` im Bauordner meldet Fehlendes.
- [ ] `debian/patches/`: jeder Patch muss sauber anwenden, sonst bricht der Bau ab. Entfällt
      ein Patch, ihn aus `series` löschen. Ist `series` dann leer, den Ordner löschen.
- [ ] Metapaket `querencia-desktop`: Mindestversion in `debian/control` anheben und den
      changelog-Eintrag `0.1.0~alpha2.1-1` ergänzen, solange nichts veröffentlicht ist.
      `AUSGABE` in `debian/rules` bleibt `Alpha 2.1`.
- [ ] Ältere changelog-Einträge nicht umschreiben (Entscheidung 22.10.): nur der neue Eintrag ist kennungsfrei.
- [ ] Metapaket: `Recommends: fonts-noto-core, fonts-noto-cjk` (seit Kandidat 2; Schriften für asiatische Zeichen
      in Fenstertiteln) bleibt Recommends, nicht Depends, damit Server-Installationen klein bleiben können.
- [ ] KI-Filter: `git -C ~/projects/<repo> grep -n -E '^#+ +Lizenzvermerk|^Lizenzvermerk:' <commit> -- README.md COPYRIGHT`.
      Ist das für **alle** Quellen in `quellen.conf` leer, entfallen
      `common/doku/ki-abschnitt-entfernen.awk` und der awk-Aufruf in `doc_install`
      (`common/querencia.mk`; dann wieder `install -m 0644`). Sonst bleibt beides (Entscheidung 22.10.: bis die
      16 Quellen bereinigt sind).

## 3. Bauen

```bash
cd ~/projects/querencia-packaging-wt-alpha21 && TMPDIR=$PWD/build/tmp QUERENCIA_JOBS=5 bash werkzeuge/alle-bauen.sh <quellpaket> … querencia-desktop
```

- Ergebnis je Paket in `build/bau-ergebnis.txt` (PASS/FAIL mit Sekunden), Logs in
  `build/nachweis/logs/`. `build/debs/SHA256SUMS` wird neu geschrieben.
- Unveränderte Pakete (gleiche Version wie in Alpha 2) kommen **immer als Alpha-2-Datei**
  in den Satz, nie als Neubau, weil der Pool unveränderlich ist. Ein Neubau ist nicht immer
  byte-gleich: Bei Session, Symbole und Hintergründe weichen die Zeitstempel ab, bei
  Software die Reihenfolge im Binary.
- Satz zusammenstellen (nach `inhalt-vergleich.sh`, liegt nicht in Git, siehe Bericht):
  `GLEICH`/`INHALT-GLEICH` → Datei aus `~/projects/querencia-packaging-wt-alpha2/build/debs-final`,
  `NEU` → `build/debs`, `ANDERS` → nur nach Prüfung (heute nur Software, Alpha-2-Datei).
  Ziel `build/debs-kandidat-<n>` mit eigener `SHA256SUMS`.
- Läuft der Bau auf einen Fehler im Quellcode, zurück an die Session des Tags, nicht
  im Paket flicken. Ausnahme sind Paketfragen (Pfade, MetaInfo, Doku), die per DEP-3-Patch
  gelöst werden.

## 4. Prüfen

```bash
cd ~/projects/querencia-packaging-wt-alpha21 && PRUEF_DEBS=$PWD/build/debs-kandidat-<n> TMPDIR=$PWD/build/tmp bash build/nachweis/pruef-alles.sh 
```

Erwartung (Kandidat 1 als Maßstab, Bericht ):

- [ ] SHA256SUMS OK, 21 Pakete
- [ ] pakete-pruefen 0 FAIL, Lintian 0 E
- [ ] APT-Testquelle 0 FAIL
- [ ] Home-Pfade nur die bekannten Fehlalarme
- [ ] B1/B2 je 0, MetaInfo ungültig 0 in installierter Doku 0
- [ ] Pool-Simulation rc 0: kein Paket hat dieselbe Version wie in Alpha 1/2 und anderen Inhalt
- [ ] quelle-pruefen 0 FAIL, mit Wegwerf-Installation
- [ ] Vergleich mit Alpha 2: `ANDERS` 0. `NEU` sind genau die geänderten Pakete
- [ ] neue changelog-Einträge: Treffer 0
- [ ] Versionsdatei: `Alpha 2.1`, `VERSION_ID="0.1.0~alpha2.1"`
- [ ] Bei Änderungen an Sitzung, Shell oder Anmeldung zusätzlich die Probe in VM 115
      (`werkzeuge/probe-wiederholen.sh`, danach `qm stop` und Rollback auf `frisch`)

## 5. Festhalten

- [ ] Commit(s) auf `alpha21`, ohne `Co-Authored-By`, kein `commit -a`, kein Push.
- [ ] Tag `packaging/alpha-2.1-kandidat-<n>` (annotiert, n = nächste freie Nummer) nur bei
      PASS. Tags nie verschieben.
- [ ] Bericht um den Kandidaten ergänzen: Messzeiten, Paketliste, Prüfzahlen, Summe von
      `SHA256SUMS`.
- [ ] Meldung an die Status-Session und an die Startsession.
- [ ] Öffentliches Packaging-Repo (`~/veroeffentlichung/packaging`, nicht von hier aus
      ändern): `quellen.conf` (öffentliche Repo-Namen, z. B. `querencia-shell`,
      `querencia-files`) und `docs/quellen-oeffentlich.md` (Spalte Tag) brauchen dieselben
      Stände. Das an die Session melden, die das öffentliche Repo pflegt.

## 6. Einfrieren (letzter Kandidat)

- [ ] Alle Tags der Welle drin oder bewusst auf Alpha 3 verschoben (Liste im Bericht)
- [ ] `build/debs` → `build/debs-final`, `chmod -R a-w`, Summe von `SHA256SUMS` melden
- [ ] Pflichtprobe auf frischer VM (`docs/pflichtprobe-frische-vm.md`), Upgrade Alpha 2 → 2.1
      (`apt full-upgrade`) in der Wegwerf-VM
- [ ] Quelle bauen, signieren und hochladen nur durch die Startsession mit dem Besitzer
      (Befehle wie in der Alpha-2-Übergabe §5)
