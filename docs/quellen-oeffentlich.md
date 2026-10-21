# Quellen der Pakete in den öffentlichen Repos

`quellen.conf` beschreibt den Bau in der Entwicklungsumgebung. Die Spalte
`<repository>` nennt die Arbeitsordner neben diesem Repository, die Spalte
`<git-revision>` die Commits der Arbeitsrepos. Die Hashes bleiben dort, damit der
Bau reproduzierbar ist.

Die öffentlichen Repos unter `github.com/querencia-desktop` tragen dieselben Tags.
Ihre Historie ist bereinigt, deshalb weichen die Commit-Hashes ab. Für Alpha 2
(Tag `packaging/alpha-2`) gilt:

| Paket | Öffentliches Repo | Tag |
|---|---|---|
| querencia-shell | `querencia-shell` (dazu `querencia-thema`) | `desktop/0.2.2` (`thema/gtk-0.2.1-1`) |
| querencia-terminal | `querencia-terminal` | `terminal/0.3.0` |
| querencia-screenshot | `querencia-screenshot` | `screenshot/0.2.9` |
| querencia-files | `querencia-files` (Fork von Strata, Zweig `querencia`) | `querencia/qf-0r-1` |
| querencia-bilder | `querencia-bilder` | `bilder/0.2.5` |
| querencia-editor | `querencia-editor` | `editor/0.2.3` |
| querencia-sitzung | `querencia-sitzung` | `sitzung/0.1.3` |
| querencia-benachrichtigungen | `querencia-benachrichtigungen` | `benachrichtigungen/0.2.2` |
| querencia-rechner | `querencia-rechner` | `rechner/0.1.5` |
| querencia-systemmonitor | `querencia-systemmonitor` | `systemmonitor/0.1.4` |
| querencia-dateisuche | `querencia-dateisuche` | `dateisuche/0.1.4` |
| querencia-einstellungen | `querencia-einstellungen` | `einstellungen/0.1.4` |
| querencia-software | `querencia-software` mit `querencia-software-paketkit`, `-katalog`, `-transaktion` | `software/0.1.4-f2` (`paketkit/0.1.0`, `katalog/0.1.0`, `transaktion/0.1.1`) |
| querencia-symbole | `querencia-symbole` | `symbole/0.7` |
| querencia-dokumente | `querencia-dokumente` | `dokumente/0.1.3` |
| querencia-archiv | `querencia-archiv` | `archiv/0.1.1` |
| querencia-anmeldung | ReGreet (Upstream, Commit in `quellen.conf`) und `querencia-anmeldung` | `anmeldung/0.1.1` |
| querencia-hintergruende | `querencia-hintergruende` | `hintergruende/0.2` |
| labwc | Upstream labwc | `0.9.8` |
| querencia-session, querencia-desktop (Metapaket) | kein eigenes Repo, nur in diesem Packaging-Repo enthalten | – |

Wer aus den öffentlichen Repos baut, legt sie neben dieses Repository. Danach
passt er die Spalten `<repository>` und `<git-revision>` in `quellen.conf` auf diese
Ordner und Tags an.
