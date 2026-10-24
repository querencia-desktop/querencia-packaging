# Pakete bauen

Voraussetzungen: `dpkg-dev`, `fakeroot`, `xz-utils`, `python3`, `git`,
`desktop-file-utils`, `appstream` und die `Build-Depends` des jeweiligen
Pakets (`dpkg-checkbuilddeps` meldet Fehlendes). **Kein debhelper nötig.**

Die Quell-Repositories liegen neben diesem Repository (Spalte
`<repository>` in [quellen.conf](../quellen.conf), relativ zu
`QUERENCIA_QUELLEN`, Standard: der Ordner über diesem Repository).
Erzeugnisse gehen nach `build/` (nicht in Git): `orig/` Upstream-Archive,
`bau/<paket>/` Bauordner mit `.deb`, `.dsc`, `.changes`, `debs/` alle Pakete
mit `SHA256SUMS`, `nachweis/` Logs und Lizenzinventar.

## Ganzer Paketsatz

```bash
QUERENCIA_JOBS=4 bash werkzeuge/alle-bauen.sh
```

Reihenfolge und Quellstände kommen aus `quellen.conf`. Jeder Bau hält den
gemeinsamen Build-Lock (`QUERENCIA_BUILD_LOCK`, Standard
`~/.local/state/querencia/bau.lock`) und läuft mit `nice -n 10`
(`QUERENCIA_NICE`). Ergebnis je Paket in `build/bau-ergebnis.txt`.

## Ein Paket

```bash
bash werkzeuge/orig-erzeugen.sh querencia-rechner   # Upstream-Archive, debian/copyright
bash werkzeuge/paket-bauen.sh  querencia-rechner    # dpkg-buildpackage -us -uc
```

- `orig-erzeugen.sh` packt den Commit aus `quellen.conf` mit `git archive`
  (ohne `CLAUDE.md`, `nachweis/`, `integration/`; abschaltbar in
  `<paket>/komponenten.conf`), vendort die Crates aus `Cargo.lock` und
  schreibt `debian/copyright` aus `copyright.in`.
- `<paket>/komponenten.conf` beschreibt weitere Upstream-Archive desselben
  Quellpakets, z. B. die Bausteine von `querencia-software`, die als
  Cargo-Pfadabhängigkeit neben dem Workspace liegen.
- `paket-bauen.sh` legt `common/querencia.mk` und `common/metainfo/`
  (MetaInfo aller Komponenten, Quelle `querencia-software-paket`) nach
  `debian/` und ruft `dpkg-buildpackage`.

## Besonderheiten

**querencia-files** ist seit Alpha 3 ein Übergangspaket ohne Programm (nur
die zwei Brücken-Starter auf Querencia Dateien, Quelle wie das Metapaket);
es baut ohne Rust wie jedes Datenpaket. Bis Alpha 2.2 brauchte der
Strata-Fork rustc ≥ 1.98 über das Bauprofil `pkg.querencia.fremdrust` mit
`QUERENCIA_RUST_BIN` (`common/querencia.mk` kennt das Profil weiter).

**labwc** baut `alle-bauen.sh` mit Manpages und SVG-Knöpfen, wenn `scdoc`
und `librsvg2-dev` installiert sind (entwicklungs-vm seit 20.10.), sonst mit
den Profilen unten. Von Hand auf einem Rechner ohne beides:

```bash
DEB_BUILD_PROFILES="nodoc pkg.labwc.nosvg" bash werkzeuge/paket-bauen.sh labwc
```

Rust-Builds bekommen `--remap-path-prefix` für Bauordner und Cargo-Home und
die C-Flags von `dpkg-buildflags`; `pakete-pruefen.sh` meldet trotzdem jeden
Home- oder Bauordnerpfad im Paket.

Umgebung: `QUERENCIA_JOBS` (Standard 2), `DEB_BUILD_OPTIONS=nocheck`
überspringt die Tests.

Ein Release baut **nicht** auf einem Entwicklungsrechner, sondern in einer
sauberen Umgebung (CI-Container `ubuntu:26.04` oder sbuild) aus Tags.
