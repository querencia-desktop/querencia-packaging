# Pakete bauen

Voraussetzungen: `dpkg-dev`, `fakeroot`, `xz-utils`, `python3`, `git`,
`desktop-file-utils` und die `Build-Depends` des jeweiligen Pakets
(`dpkg-checkbuilddeps` meldet Fehlendes). **Kein debhelper nötig.**

```bash
bash werkzeuge/orig-erzeugen.sh querencia-shell    # Upstream-Archive, debian/copyright
bash werkzeuge/paket-bauen.sh  querencia-shell     # dpkg-buildpackage -us -uc
```

Reihenfolge für den vollständigen Satz: `querencia-shell`,
`querencia-terminal`, `querencia-screenshot`, `querencia-files`,
`querencia-session`, `querencia-desktop`, `labwc`.

labwc auf einem Rechner ohne `scdoc`, `librsvg2-dev`, `gettext`:

```bash
DEB_BUILD_PROFILES="nodoc pkg.labwc.nosvg pkg.labwc.nonls" bash werkzeuge/paket-bauen.sh labwc
```

Umgebung: `QUERENCIA_JOBS` (Standard 2), `QUERENCIA_BUILD_LOCK`
(Standard `~/.local/state/querencia/bau.lock`),
`DEB_BUILD_OPTIONS=nocheck` überspringt Tests.

Ein Release baut **nicht** auf einem Entwicklungsrechner, sondern in einer
sauberen Umgebung (CI-Container `ubuntu:26.04` oder sbuild) aus Tags.
