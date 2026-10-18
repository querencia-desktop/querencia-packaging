# Querencia Packaging

Debian-Paketierung, APT-Quelle und CI-Vorlagen für Querencia Desktop.

> **Status: Entwurf (QREL-01).** Pakete `0.1.0~alpha1-1` bauen lokal mit
> `dpkg-buildpackage`; nichts ist veröffentlicht oder signiert.

## Inhalt

```
quellen.conf              Quellpaket → Repository → Commit → Version
common/querencia.mk       gemeinsames debian/rules-Fragment (ohne debhelper)
querencia-shell/debian/   Panel + Desktop
querencia-terminal/debian/
querencia-screenshot/debian/
querencia-files/debian/   Dateimanager (ohne UnRAR, ohne Update-Prüfung)
querencia-bilder/debian/  Bildbetrachter (QI-01, ohne MIME-Zuordnung)
querencia-session/debian/ Sitzung (Architecture: all)
querencia-desktop/debian/ Metapaket (Quelle: Repository querencia)
backports/labwc/debian/   labwc 0.9.8 für Ubuntu 26.04
werkzeuge/                orig-erzeugen, paket-bauen, pakete-pruefen,
                          copyright-erzeugen, apt-quelle-erzeugen/-testen,
                          veroeffentlichung-pruefen
ci/                       GitHub-Actions-Vorlagen (nicht aktiv)
patches/                  isolierte Patches für Repositories anderer Worker
tests/                    Ablauf des Installationstests auf frischem Ubuntu
```

Die Repositories der Komponenten liegen als Geschwisterordner (`../querencia-shell`
usw.); Erzeugnisse gehen nach `../../pakete` und `../../nachweis`
(änderbar über `QUERENCIA_QUELLEN`, `QUERENCIA_AUSGABE`, `QUERENCIA_NACHWEIS`).

Anleitung: [BUILDING.md](BUILDING.md), [TESTING.md](TESTING.md); Hintergrund:
`docs/PACKAGING.md` und `docs/RELEASE.md` im Repository `querencia`.

## Lizenz

GPL-3.0-or-later (Paketierung und Werkzeuge), siehe [LICENSE](LICENSE).
