# APT-Quelle (Entwurf)

- Erzeugen: `werkzeuge/apt-quelle-erzeugen.py` (Packages, Release mit
  SHA256/SHA512, Valid-Until, Acquire-By-Hash, InRelease/Release.gpg).
- Testen: `werkzeuge/apt-quelle-testen.sh` (Wegwerf-Testschlüssel).
- Einbinden beim Nutzer: [querencia.sources](querencia.sources) nach
  `/etc/apt/sources.list.d/`, Schlüssel nach `/usr/share/keyrings/`.
- Schlüsselverwaltung, HTTPS-Veröffentlichung, Rollback:
  `docs/RELEASE.md` im Repository `querencia`.

**Noch nicht veröffentlicht. Kein Produktionsschlüssel erzeugt.**
`<APT-URL>` wird bei der Freigabe festgelegt (Vorschlag: GitHub Pages eines
eigenen Repositorys `querencia-apt`, HTTPS).
