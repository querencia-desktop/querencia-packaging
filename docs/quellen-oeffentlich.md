# Quellen der Pakete in den öffentlichen Repos

`quellen.conf` nennt in der Spalte `<repository>` die öffentlichen Repo-Namen (als
Geschwisterordner dieses Repos) und in `<git-revision>` die Commits der
Arbeitsrepos, aus denen Alpha 2 gebaut ist. Die Hashes bleiben dort, damit der Bau
nachvollziehbar ist.

Die öffentlichen Repos unter `github.com/querencia-desktop` tragen dieselben Tags.
Ihre Historie ist bereinigt, deshalb weichen die Commit-Hashes ab. Für Alpha 2
(Tag `packaging/alpha-2`) gilt:

| Paket | Öffentliches Repo | Tag |
|---|---|---|
| querencia-shell | `querencia-shell`, dazu `querencia-thema` | `desktop/0.2.2`; Thema gebaut aus `thema/gtk-0.2.1-int` (Integrationsstand), öffentlich `thema/gtk-0.2.1-1` = Vorlagen-Commit mit stimmiger `SHA256SUMS` |
| querencia-terminal | `querencia-terminal` | `terminal/0.3.0` |
| querencia-screenshot | `querencia-screenshot` | `screenshot/0.2.9` |
| querencia-files | `querencia-files-intern` (später Fork `querencia-files` von Strata), Zweig `querencia` | `querencia/qf-0r-1` |
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
| querencia-session | `querencia-session` | `session/0.1.0-alpha7` |
| querencia-desktop (Metapaket) | kein eigenes Repo, nur in diesem Packaging-Repo enthalten (`quellen.conf`: `querencia-desktop-meta`) | – |

Wer aus den öffentlichen Repos baut, klont sie unter diesen Namen neben dieses
Repository und ersetzt in `quellen.conf` die Spalte `<git-revision>` durch die Tags.
