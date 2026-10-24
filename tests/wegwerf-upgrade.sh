#!/bin/bash
# Upgrade-Probe ohne zweite VM (Welle C, Ablösung Files → Dateien): in derselben
# Wegwerf-Hülle wie tests/wegwerf-installation.sh (bubblewrap, dpkg --root auf
# einer Kopie der Paketdatenbank, kein Netz, kein Bus) wird
#   1. der alte Paketsatz installiert (z. B. Alpha 2.2),
#   2. ein Probe-Benutzer mit Lesezeichen, Files-Einstellungen und einer
#      zweiten Benutzerwahl (eigene mimeapps.list mit der alten Strata-ID)
#      angelegt und der Zustand vorher festgehalten,
#   3. apt-get -s full-upgrade gegen eine Datei-Quelle mit dem neuen Satz
#      simuliert (was apt beim Upgrade täte),
#   4. der neue Satz mit dpkg -i darübergespielt (Upgrade samt
#      Maintainer-Skripten, ohne Rückfrage: stdin ist leer),
#   5. die Ablösung geprüft (Ordnerprogramm, Files-Starter, Lesezeichen,
#      apt autoremove; seit Alpha 3: Files ausgemustert, querencia-files ist
#      ein Übergangspaket ohne Programm, kein Starter und kein Eintrag einer
#      mimeapps.list zeigt ins Leere),
#   6. die volle Prüfung von wegwerf-installation.sh (Teil pruefen: Programme,
#      kopflose Sitzung, jeder Starter) auf dem neuen Stand gefahren und
#      danach Lesezeichen und Files-Übernahme nachgesehen.
# Das echte System bleibt unverändert.
#
#   bash tests/wegwerf-upgrade.sh <nachweisordner> <ordner alter satz> <ordner neuer satz>
#
# UPGRADE_VORHER_ORDNER: Ordnerprogramm des alten Satzes (Vorgabe
# org.querencia.Files.desktop = Alpha 2.2; Alpha 2.1: io.github.lgse.Strata.desktop).
#
# Ergebnis: PASS/FAIL/HINW je Prüfung in <nachweisordner>/ergebnis.txt,
# Exit 1 bei einem FAIL.
set -uo pipefail
HIER=$(readlink -f "$0")
WEGWERF=$(dirname "$HIER")/wegwerf-installation.sh

if [ "${1-}" = --innen ]; then
    shift
    TEIL=$1 A=$2 OUT=$3 ALT=$4 NEU=$5
    R=$A/wurzel
    pass=0 fail=0
    ok() { pass=$((pass + 1)); echo "PASS $*"; }
    nok() { fail=$((fail + 1)); echo "FAIL $*"; }
    hinweis() { echo "HINW $*"; }
    # GIO wie in der Querencia-Sitzung: Programme und Vorgaben aus der
    # Wegwerf-Wurzel, Benutzerdaten aus dem Probe-Home $1. GIO zeigt nur
    # Starter, deren Exec/TryExec im PATH liegt: $R/usr/bin gehört dazu.
    gio_als() {
        local h=$1; shift
        env -i PATH="$R/usr/bin:/usr/bin:/bin" HOME="$h" XDG_CONFIG_HOME="$h/.config" XDG_DATA_HOME="$h/.local/share" \
            XDG_DATA_DIRS="$R/usr/share:/usr/share" XDG_CONFIG_DIRS="$R/etc/xdg:/etc/xdg" \
            XDG_CURRENT_DESKTOP=X-Querencia LANG=C.UTF-8 gio "$@" 2>&1
    }
    vorgabe() { gio_als "$1" mime inode/directory | sed -n 's/^Default application for “inode\/directory”: //p'; }
    APPS=$R/usr/share/applications
    sichtbare_dateimanager() { # Starter mit Kategorie FileManager, die im Menü erscheinen
        for d in "$APPS"/*.desktop; do
            [ -f "$d" ] || continue
            grep -q '^Categories=.*FileManager' "$d" || continue
            grep -qx 'NoDisplay=true' "$d" && continue
            basename "$d"
        done | tr '\n' ' '
    }
    apt_s() { # apt-get gegen die Wegwerf-Paketdatenbank und eine Datei-Quelle
        apt-get -q -o Dir::State::status="$R/var/lib/dpkg/status" -o Dir::State="$A/apt/state" \
            -o Dir::State::extended_states="$A/apt/state/extended_states" -o Dir::Cache="$A/apt/cache" \
            -o Dir::Etc::sourcelist="$A/apt/sources.list" -o Dir::Etc::sourceparts="$A/apt/quellen.d" \
            -o Dir::Etc::preferences="$A/apt/preferences" -o Dir::Etc::preferencesparts="$A/apt/leer" \
            -o Dir::Log="$A/apt/log" -o Debug::NoLocking=1 -o APT::Get::List-Cleanup=0 \
            -o Acquire::Languages=none "$@"
    }

    case $TEIL in
    vorher)
        # Probe-Benutzer A ($A/home, auch Home der Sitzungsprüfung): Lesezeichen,
        # Files-Einstellungen, keine eigene Ordnervorgabe. Benutzer B: eigene
        # mimeapps.list mit der alten Strata-ID (Befund 1 aus Alpha 2.2).
        H=$A/home HB=$A/home-b
        mkdir -p "$H/.config/gtk-3.0" "$H/.config/querencia-files" "$H/Dokumente" "$H/Bilder" "$H/Projekt Ä" \
            "$HB/.config"
        printf '%s\n' "file://$H/Dokumente" "file://$H/Bilder Urlaubsbilder" "file://$H/Projekt%20%C3%84 Projekt Ä" \
            "sftp://server.invalid/srv/daten Netzordner" >"$H/.config/gtk-3.0/bookmarks"
        printf '%s\n' 'show_hidden = true' 'browser_mode = "columns"' 'sort_key = "modified"' 'folders_first = true' \
            'grid_folder_clicks = 2' 'list_folder_clicks = 2' 'sidebar_expanded = true' >"$H/.config/querencia-files/settings.toml"
        printf '%s\n' '[Default Applications]' 'inode/directory=io.github.lgse.Strata.desktop' >"$HB/.config/mimeapps.list"
        (cd "$H" && sha256sum .config/gtk-3.0/bookmarks .config/querencia-files/settings.toml) >"$OUT/home-vorher.sha256"
        dpkg-query --root="$R" -W -f='${Package} ${Version} ${db:Status-Abbrev}\n' 'querencia-*' labwc 2>/dev/null |
            sort >"$OUT/versionen-vorher.txt"
        echo "Ordnerprogramm A: $(vorgabe "$H")" >"$OUT/gio-vorher.txt"
        echo "Ordnerprogramm B: $(vorgabe "$HB")" >>"$OUT/gio-vorher.txt"
        echo "Dateimanager im Menü: $(sichtbare_dateimanager)" >>"$OUT/gio-vorher.txt"
        gio_als "$H" mime inode/directory >"$OUT/gio-mime-vorher.txt"
        cat "$OUT/gio-vorher.txt"
        vo=${UPGRADE_VORHER_ORDNER:-org.querencia.Files.desktop}
        grep -q "^Ordnerprogramm A: $vo\$" "$OUT/gio-vorher.txt" &&
            ok "vorher: Ordnerprogramm $vo (alter Satz)" ||
            nok "vorher: Ordnerprogramm $(sed -n 's/^Ordnerprogramm A: //p' "$OUT/gio-vorher.txt")"

        # apt-Simulation des Upgrades: Datei-Quelle mit dem neuen Satz, Quelle
        # des alten Satzes daneben (sonst fehlen apt die installierten Pakete
        # als Kandidaten nicht, aber Kandidaten für ältere Abhängigkeiten).
        # Wie nach "apt install querencia-desktop": alles außer dem Metapaket
        # ist automatisch installiert.
        mkdir -p "$A/apt/state/lists/partial" "$A/apt/cache/archives/partial" "$A/apt/log" "$A/apt/neu" "$A/apt/alt" "$A/apt/leer"
        : >"$A/apt/preferences"
        # Ubuntu-Archiv aus den Paketlisten des Rechners (kein Netz in der
        # Hülle: apt-get update behält sie, die Datei-Quellen kommen neu dazu),
        # damit Abhängigkeiten wie fonts-dejavu auflösbar sind wie auf der VM
        for f in /var/lib/apt/lists/*_Packages /var/lib/apt/lists/*_InRelease /var/lib/apt/lists/*_Release; do
            [ -f "$f" ] && cp "$f" "$A/apt/state/lists/"
        done
        mkdir -p "$A/apt/quellen.d"; cp /etc/apt/sources.list.d/*.sources "$A/apt/quellen.d/" 2>/dev/null
        [ -f /etc/apt/sources.list ] && cat /etc/apt/sources.list >"$A/apt/sources.list.rechner" 2>/dev/null
        ln -s "$NEU"/*.deb "$A/apt/neu/" && ln -s "$ALT"/*.deb "$A/apt/alt/"
        (cd "$A/apt/neu" && dpkg-scanpackages -m . 2>/dev/null >Packages)
        (cd "$A/apt/alt" && dpkg-scanpackages -m . 2>/dev/null >Packages)
        { cat "$A/apt/sources.list.rechner" 2>/dev/null
          printf '%s\n' "deb [trusted=yes] file:$A/apt/neu ./" "deb [trusted=yes] file:$A/apt/alt ./"; } >"$A/apt/sources.list"
        for p in $(awk '$1 ~ /^(querencia-|labwc$)/ && $1 != "querencia-desktop" && $3 == "ii" {print $1}' "$OUT/versionen-vorher.txt"); do
            printf 'Package: %s\nArchitecture: %s\nAuto-Installed: 1\n\n' "$p" "$(dpkg-query --root="$R" -W -f='${Architecture}' "$p")"
        done >"$A/apt/state/extended_states"
        apt_s update >"$OUT/apt-update.txt" 2>&1
        grep -q "file:$A/apt/neu ./ Packages" "$OUT/apt-update.txt" && ok "apt-get update: Datei-Quellen gelesen (Ubuntu-Archiv aus den Listen des Rechners)" ||
            nok "apt-get update: $(tail -2 "$OUT/apt-update.txt" | tr '\n' ' ')"
        apt_s -s full-upgrade >"$OUT/apt-full-upgrade-simulation.txt" 2>&1
        rc=$?
        # apt -s: "Inst p [alt] (neu …)" = Aktualisierung, "Inst p (neu …)" = neu;
        # gewertet werden die Pakete des Satzes (andere Zeilen sind ausstehende
        # Updates dieses Rechners aus seinen Paketlisten)
        satz=$(for d in "$NEU"/*.deb "$ALT"/*.deb; do dpkg-deb -f "$d" Package; done | sort -u | tr '\n' ' ')
        imsatz() { while read -r p; do [[ " $satz " == *" $p "* ]] && echo "$p"; done | tr '\n' ' '; }
        remv=$(awk '/^Remv / {print $2}' "$OUT/apt-full-upgrade-simulation.txt" | tr '\n' ' ')
        neu=$(awk '/^Inst [^ ]+ \(/ {print $2}' "$OUT/apt-full-upgrade-simulation.txt" | imsatz)
        hoch=$(awk '/^Inst [^ ]+ \[/ {print $2}' "$OUT/apt-full-upgrade-simulation.txt" | imsatz)
        fremd=$(awk '/^Inst / {print $2}' "$OUT/apt-full-upgrade-simulation.txt" | while read -r p; do [[ " $satz " == *" $p "* ]] || echo "$p"; done | wc -l)
        echo "apt -s full-upgrade: neu: ${neu}| aktualisiert: ${hoch}| entfernt: ${remv:-keins} (dazu $fremd ausstehende Updates dieses Rechners)"
        [ $rc -eq 0 ] && [ -z "$remv" ] && [ "$neu" = "querencia-dateien " ] &&
            ok "apt -s full-upgrade: neu nur querencia-dateien, aktualisiert ${hoch}, nichts entfernt" ||
            nok "apt -s full-upgrade: rc $rc, neu: $neu, entfernt: ${remv:-keins} ($OUT/apt-full-upgrade-simulation.txt)"
        # Neuinstallation (M7): apt install querencia-desktop auf dem Stand des
        # Rechners ohne Querencia, mit Empfehlungen wie apt sie standardmäßig nimmt
        apt-get -q -o Dir::State::status=/var/lib/dpkg/status -o Dir::State="$A/apt/state" \
            -o Dir::State::extended_states="$A/apt/leer/extended_states" -o Dir::Cache="$A/apt/cache" \
            -o Dir::Etc::sourcelist="$A/apt/sources.list" -o Dir::Etc::sourceparts="$A/apt/quellen.d" \
            -o Dir::Etc::preferences="$A/apt/preferences" -o Dir::Etc::preferencesparts="$A/apt/leer" \
            -o Debug::NoLocking=1 -s install querencia-desktop >"$OUT/apt-neuinstallation-simulation.txt" 2>&1
        q=$(awk '/^Inst querencia-|^Inst labwc / {print $2}' "$OUT/apt-neuinstallation-simulation.txt" | sort | tr '\n' ' ')
        n=$(grep -c '^Inst ' "$OUT/apt-neuinstallation-simulation.txt")
        echo "apt -s install querencia-desktop (Neuinstallation): $n Pakete, davon Querencia: $q"
        if echo " $q " | grep -q ' querencia-dateien ' && ! echo " $q " | grep -q ' querencia-files '; then
            ok "Neuinstallation: zieht querencia-dateien, nicht querencia-files ($n Pakete auf diesem Rechner)"
        else
            nok "Neuinstallation: Querencia-Pakete $q"
        fi
        echo " $hoch " | grep -q ' querencia-files ' && ok "apt -s full-upgrade: querencia-files wird auf das Übergangspaket aktualisiert" ||
            nok "apt -s full-upgrade: querencia-files nicht aktualisiert"
        # "apt upgrade" (= apt-get upgrade --with-new-pkgs) installiert neue
        # Pakete, entfernt aber keine: das Upgrade muss auch so vollständig
        # sein (sonst hielte apt Pakete zurück). apt-get upgrade ohne neue
        # Pakete hält das Metapaket zurück (neue Abhängigkeit querencia-dateien).
        apt_s -s upgrade --with-new-pkgs >"$OUT/apt-upgrade-simulation.txt" 2>&1
        rc=$?
        remv=$(awk '/^Remv / {print $2}' "$OUT/apt-upgrade-simulation.txt" | tr '\n' ' ')
        hoch2=$(awk '/^Inst / {print $2}' "$OUT/apt-upgrade-simulation.txt" | sort | imsatz)
        zurueck=$(sed -n '/zurückgehalten\|kept back/,/^[^ ]/p' "$OUT/apt-upgrade-simulation.txt" | grep '^ ' | tr ' ' '\n' | grep . | imsatz)
        echo "apt -s upgrade --with-new-pkgs: installiert/aktualisiert: ${hoch2}| zurückgehalten: ${zurueck:-nichts}| entfernt: ${remv:-keins}"
        [ $rc -eq 0 ] && [ -z "$remv" ] && [ -z "$zurueck" ] && [ "$hoch2" = "$(echo "$neu $hoch" | tr ' ' '\n' | grep . | sort | imsatz)" ] &&
            ok "apt -s upgrade (apt upgrade): dieselben Pakete wie full-upgrade, nichts zurückgehalten, nichts entfernt" ||
            nok "apt -s upgrade: rc $rc, Pakete: $hoch2, zurückgehalten: ${zurueck:-nichts}, entfernt: ${remv:-keins} ($OUT/apt-upgrade-simulation.txt)"
        ;;

    nachher)
        H=$A/home HB=$A/home-b
        dpkg-query --root="$R" -W -f='${Package} ${Version} ${db:Status-Abbrev}\n' 'querencia-*' labwc 2>/dev/null |
            sort >"$OUT/versionen-nachher.txt"
        diff "$OUT/versionen-vorher.txt" "$OUT/versionen-nachher.txt" >"$OUT/versionen-diff.txt"
        sed 's/^/  /' "$OUT/versionen-diff.txt"
        for want in "querencia-dateien $(dpkg-deb -f "$NEU"/querencia-dateien_*.deb Version)" \
            "querencia-files $(dpkg-deb -f "$NEU"/querencia-files_*.deb Version)" \
            "querencia-desktop $(dpkg-deb -f "$NEU"/querencia-desktop_*.deb Version)"; do
            if grep -q "^$want ii" "$OUT/versionen-nachher.txt"; then ok "nachher: $want installiert"
            elif grep -q "^$want iU" "$OUT/versionen-nachher.txt"; then ok "nachher: $want entpackt (Konfiguration wartet auf Archiv-Abhängigkeiten dieses Rechners)"
            else nok "nachher: $want fehlt"; fi
        done
        grep -q -E -i 'conffile|Konfigurationsdatei .*(geändert|modified)|\*\*\* .* \(Y/I/N/O/D/Z\)' "$OUT/../upgrade-installieren/dpkg-i.txt" 2>/dev/null &&
            nok "Upgrade: dpkg fragt nach einer Konfigurationsdatei" || ok "Upgrade: keine Konfigurationsdatei-Rückfrage"

        # Ordnerprogramm
        a=$(vorgabe "$H") b=$(vorgabe "$HB")
        gio_als "$H" mime inode/directory >"$OUT/gio-mime-nachher.txt"
        { echo "Ordnerprogramm A: $a"; echo "Ordnerprogramm B: $b"; echo "Dateimanager im Menü: $(sichtbare_dateimanager)"; } | tee "$OUT/gio-nachher.txt"
        [ "$a" = org.querencia.Dateien.desktop ] && ok "inode/directory → org.querencia.Dateien.desktop (Vorgabe der Sitzung)" ||
            nok "inode/directory → ${a:-nichts} statt org.querencia.Dateien.desktop"
        if [ "$b" = io.github.lgse.Strata.desktop ] && grep -qx 'Exec=querencia-dateien %U' "$APPS/$b"; then
            ok "eigene Wahl io.github.lgse.Strata.desktop bleibt und startet jetzt querencia-dateien (Brücke M4)"
        else
            nok "Benutzer mit alter Strata-Wahl: ${b:-nichts} ($(grep '^Exec=' "$APPS/$b" 2>/dev/null))"
        fi
        reg=$(sed -n '/^Registered applications:/,/^Recommended/p' "$OUT/gio-mime-nachher.txt" | grep -E 'Files|Strata' | tr -d '\t' | tr '\n' ' ')
        [ -z "$reg" ] && ok "Files/Strata nicht mehr für inode/directory registriert" || nok "noch registriert: $reg"

        # Files-Starter: versteckt, ohne MIME-Typen, Exec auf Dateien
        for id in org.querencia.Files io.github.lgse.Strata; do
            f=$APPS/$id.desktop
            if [ -f "$f" ] && grep -qx 'NoDisplay=true' "$f" && ! grep -q '^MimeType=' "$f" &&
                grep -qx 'Exec=querencia-dateien %U' "$f"; then
                ok "$id.desktop: NoDisplay, ohne MimeType, Exec=querencia-dateien %U"
            else
                nok "$id.desktop: $(grep -E '^(NoDisplay|MimeType|Exec)=' "$f" 2>/dev/null | tr '\n' ' ')"
            fi
        done
        menue=$(sichtbare_dateimanager)
        [ "$menue" = "org.querencia.Dateien.desktop " ] && ok "Dateimanager im Menü: nur org.querencia.Dateien.desktop (Files-Starter verschwunden)" ||
            nok "Dateimanager im Menü: $menue"
        aufFiles=$(grep -l -E '^Exec=querencia-files( |$)' "$APPS"/*.desktop 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')
        [ -z "$aufFiles" ] && ok "kein Starter startet mehr querencia-files" || nok "Starter auf querencia-files: $aufFiles"
        # Files ausgemustert (Alpha 3): Übergangspaket ohne Programm und ohne
        # Reste des alten Pakets
        [ "$(dpkg-query --root="$R" -W -f='${Section}' querencia-files 2>/dev/null)" = oldlibs ] &&
            ok "querencia-files ist das Übergangspaket (Section oldlibs)" || nok "querencia-files: Section $(dpkg-query --root="$R" -W -f='${Section}' querencia-files 2>/dev/null)"
        rest=$(for f in /usr/bin/querencia-files /usr/share/querencia-files /usr/share/metainfo/org.querencia.Files.metainfo.xml \
            /usr/share/metainfo/io.github.lgse.Strata.metainfo.xml /usr/share/doc/querencia-files/licenses; do [ -e "$R$f" ] && echo "$f"; done | tr '\n' ' ')
        [ -z "$rest" ] && ok "Files ausgemustert: kein Befehl querencia-files, keine MetaInfo, keine Paketmarke, keine Lizenztexte von Strata" ||
            nok "Reste von Files: $rest"
        dateien=$(dpkg-query --root="$R" -L querencia-files 2>/dev/null | while read -r f; do [ -f "$R$f" ] && echo "$f"; done |
            grep -v -x -E '/usr/share/applications/(org\.querencia\.Files|io\.github\.lgse\.Strata)\.desktop|/usr/share/doc/querencia-files/(README\.Debian|changelog\.Debian\.gz|copyright)|/usr/share/lintian/overrides/querencia-files' | tr '\n' ' ')
        [ -z "$dateien" ] && ok "querencia-files enthält nur die zwei Brücken-Starter und seine Doku" || nok "querencia-files enthält: $dateien"
        # kein verwaister Eintrag: jeder Starter findet sein Programm (Exec und
        # TryExec im Paketsatz oder auf dem Rechner), jede Desktop-ID der
        # Vorgabe der Sitzung und jeder Benutzer-mimeapps.list hat ihren Starter
        verwaist=
        for d in "$APPS"/*.desktop; do
            for key in Exec TryExec; do
                c=$(sed -n "s/^$key=//p" "$d" | head -n 1 | awk '{print $1}')
                [ -n "$c" ] || continue
                case $c in /*) [ -x "$R$c" ] || [ -x "$c" ] ;; *) [ -x "$R/usr/bin/$c" ] || command -v "$c" >/dev/null ;; esac ||
                    verwaist+="$(basename "$d"):$key=$c "
            done
        done
        [ -z "$verwaist" ] && ok "kein Starter zeigt auf ein fehlendes Programm ($(ls "$APPS"/*.desktop | wc -l) Starter)" || nok "verwaiste Starter: $verwaist"
        ids=
        for m in "$APPS/x-querencia-mimeapps.list" "$H/.config/mimeapps.list" "$HB/.config/mimeapps.list"; do
            [ -f "$m" ] || continue
            for id in $(grep -v '^[#\[]' "$m" | cut -d= -f2- | tr ';' '\n' | grep '\.desktop$'); do
                [ -f "$APPS/$id" ] || [ -f "/usr/share/applications/$id" ] || ids+="$(basename "$m"):$id "
            done
        done
        [ -z "$ids" ] && ok "mimeapps: jede genannte Desktop-ID hat ihren Starter (Vorgabe der Sitzung, Benutzer A und B)" || nok "mimeapps verweist ins Leere: $ids"

        # Benutzerdaten unverändert
        (cd "$H" && sha256sum -c --quiet "$OUT/home-vorher.sha256") >/dev/null 2>&1 &&
            ok "Lesezeichen und Files-Einstellungen nach dem Upgrade unverändert" || nok "Benutzerdaten verändert"

        # apt: was "autoremove" danach vorschlüge (auto-Markierung wie oben,
        # querencia-dateien als neue Abhängigkeit ebenfalls automatisch)
        printf 'Package: querencia-dateien\nArchitecture: amd64\nAuto-Installed: 1\n\n' >>"$A/apt/state/extended_states"
        apt_s -s autoremove >"$OUT/apt-autoremove-simulation.txt" 2>&1
        weg=$(grep '^Remv ' "$OUT/apt-autoremove-simulation.txt" | awk '{print $2}' | tr '\n' ' ')
        apt_s -s -o APT::AutoRemove::SuggestsImportant=false autoremove >"$OUT/apt-autoremove-ohne-suggests.txt" 2>&1
        weg2=$(grep '^Remv ' "$OUT/apt-autoremove-ohne-suggests.txt" | awk '{print $2}' | tr '\n' ' ')
        echo "apt -s autoremove: ${weg:-nichts}; ohne Suggests-Schutz: ${weg2:-nichts}"
        grep -q 'Package: querencia-shell' "$R/var/lib/dpkg/status" && sug=$(dpkg-query --root="$R" -W -f='${Suggests}' querencia-shell)
        hinweis "apt autoremove schlüge vor: ${weg:-nichts}; mit APT::AutoRemove::SuggestsImportant=false: ${weg2:-nichts} (querencia-shell Suggests: ${sug:-–})"
        echo " $weg " | grep -q ' querencia-files ' && nok "querencia-files würde mit autoremove entfernt; mit ihm gingen die Brücken" ||
            ok "apt autoremove behält das Übergangspaket querencia-files (Brücken bleiben)"
        apt_s -s -f install >"$OUT/apt-check.txt" 2>&1; grep -q '^0 aktualisiert, 0 neu installiert, 0 zu entfernen\|^0 upgraded, 0 newly installed, 0 to remove' "$OUT/apt-check.txt" && ok "apt-get -s -f install: nach dem Upgrade nichts zu reparieren" ||
            hinweis "apt-get -s -f install: $(grep -E '^(Inst|Remv|Conf) ' "$OUT/apt-check.txt" | awk '{print $1, $2}' | tr '\n' ' ') (Abhängigkeiten aus dem Archiv, die dieser Rechner nicht hat)"
        ;;

    danach)
        # nach der Sitzungsprüfung (Dateien lief dort mit $A/home)
        H=$A/home
        (cd "$H" && sha256sum -c --quiet "$OUT/home-vorher.sha256") >/dev/null 2>&1 &&
            ok "nach dem Start von Dateien: Lesezeichen und Files-Einstellungen unverändert" ||
            nok "nach dem Start von Dateien: Benutzerdaten verändert ($(cd "$H" && sha256sum -c "$OUT/home-vorher.sha256" 2>&1 | grep -v ': OK' | tr '\n' ' '))"
        ini=$H/.config/querencia/dateien.ini
        cp "$ini" "$OUT/dateien.ini" 2>/dev/null
        if grep -qx 'AusFiles=1' "$ini" 2>/dev/null; then
            ok "Dateien hat die Files-Einstellungen beim ersten Start übernommen (AusFiles=1, $OUT/dateien.ini)"
        else
            nok "dateien.ini ohne AusFiles=1 ($ini)"
        fi
        ls "$OUT"/../sitzung/start-org.querencia.Dateien.png >/dev/null 2>&1 &&
            ok "Bildschirmfoto Dateien mit Lesezeichen in der Seitenleiste: sitzung/start-org.querencia.Dateien.png" ||
            hinweis "kein Bildschirmfoto von Dateien"
        ;;
    esac
    echo "Teil $TEIL: $pass PASS, $fail FAIL"
    [ $fail -eq 0 ]
    exit
fi

# ---- außen -------------------------------------------------------------------
[ $# -eq 3 ] || { echo "Aufruf: $0 <nachweisordner> <ordner alter satz> <ordner neuer satz>" >&2; exit 2; }
OUT=$(readlink -f "$1") ALT=$(readlink -f "$2") NEU=$(readlink -f "$3")
for s in "$ALT" "$NEU"; do (cd "$s" && sha256sum -c --quiet SHA256SUMS) || { echo "$s: SHA256SUMS stimmt nicht" >&2; exit 2; }; done
mkdir -p "$OUT"/{alt-installieren,upgrade,upgrade-installieren,sitzung}
A=$(mktemp -d "${TMPDIR:-/tmp}/querencia-upgrade.XXXXXX")
# UPGRADE_BEHALTEN=1 lässt den Arbeitsordner zur Fehlersuche stehen.
[ -n "${UPGRADE_BEHALTEN-}" ] && echo "Arbeitsordner bleibt: $A" || trap 'chmod -R u+w "$A" 2>/dev/null; rm -rf "$A"' EXIT
mkdir -p "$A/wurzel/var/lib/dpkg/updates" "$A/wurzel/var/lib/dpkg/triggers" "$A/wurzel/var/log" \
    "$A/wurzel/etc" "$A/home" "$A/tmp"
cp /var/lib/dpkg/status "$A/wurzel/var/lib/dpkg/status"
cp -a /var/lib/dpkg/info "$A/wurzel/var/lib/dpkg/info"
find /var/lib/dpkg/triggers -maxdepth 1 -type f ! -name Lock -exec cp -a {} "$A/wurzel/var/lib/dpkg/triggers/" \;
cp -a /var/lib/dpkg/alternatives "$A/wurzel/var/lib/dpkg/alternatives" 2>/dev/null || mkdir -p "$A/wurzel/var/lib/dpkg/alternatives"
cp -a /etc/alternatives "$A/wurzel/etc/alternatives"
touch "$A/wurzel/var/lib/dpkg/available"
bind=(--bind "$A" "$A" --bind "$OUT" "$OUT" --ro-bind "$ALT" "$ALT" --ro-bind "$NEU" "$NEU" --ro-bind "$WEGWERF" "$WEGWERF")
leer=(--tmpfs /run/user --tmpfs /run/dbus)
[ -d /run/needrestart ] && leer+=(--tmpfs /run/needrestart)
huelle() {
    bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp "${leer[@]}" \
        "${bind[@]}" --unshare-pid --unshare-net --unshare-ipc --die-with-parent \
        --unsetenv WAYLAND_DISPLAY --unsetenv DISPLAY --unsetenv DBUS_SESSION_BUS_ADDRESS \
        --unsetenv XDG_RUNTIME_DIR --unsetenv XDG_SESSION_ID --unsetenv SWAYSOCK --unsetenv LABWC_PID \
        --setenv TMPDIR "$A/tmp" "$@"
}
# querencia-anmeldung (optional, Suggests) braucht greetd und debconf und
# bleibt ohne beides halb konfiguriert; wie in der Wegwerf-Installation von
# Alpha 2.2 nicht in der Hülle (UPGRADE_OHNE leer: alle Pakete).
OHNE=${UPGRADE_OHNE-querencia-anmeldung}
waehle() { local d n; for d in "$1"/*.deb; do n=$(basename "$d"); n=${n%%_*}; [[ " $OHNE " == *" $n "* ]] || echo "$d"; done; }
mapfile -t alt < <(waehle "$ALT"); mapfile -t neu < <(waehle "$NEU")
# Archiv-Abhängigkeiten, die dieser Rechner nicht installiert hat (auf der VM
# holt apt sie aus dem Ubuntu-Archiv): leere, gekennzeichnete Attrappe mit
# der Version des Archivs, damit das Metapaket konfiguriert wird und apt einen
# heilen Ausgangszustand sieht.
attrappen=()
for x in ${UPGRADE_ATTRAPPEN-fonts-dejavu}; do
    dpkg-query -W -f='${db:Status-Abbrev}' "$x" 2>/dev/null | grep -q '^ii' && continue
    v=$(apt-cache policy "$x" 2>/dev/null | sed -n 's/^ *\(Installationskandidat\|Candidate\): *//p')
    [ -n "$v" ] && [ "$v" != "(none)" ] && [ "$v" != "(keine)" ] || continue
    d=$A/attrappen/$x; mkdir -p "$d/DEBIAN"
    printf '%s\n' "Package: $x" "Version: $v" "Architecture: all" "Maintainer: Probe <probe@invalid>" \
        "Description: Attrappe fuer die Upgrade-Probe (leer)" " Steht fuer das gleichnamige Paket aus dem Ubuntu-Archiv." >"$d/DEBIAN/control"
    dpkg-deb --root-owner-group -b "$d" "$A/attrappen/${x}_attrappe.deb" >/dev/null && attrappen+=("$A/attrappen/${x}_attrappe.deb")
done
{
    echo "== 1 alter Satz: $(basename "$ALT") (${#alt[@]} Pakete, SHA256SUMS $(sha256sum "$ALT/SHA256SUMS" | cut -c1-16)…; ohne: ${OHNE:-nichts})"
    [ ${#attrappen[@]} -eq 0 ] || echo "HINW Attrappen für Archiv-Abhängigkeiten, die dieser Rechner nicht hat: $(printf '%s ' "${attrappen[@]##*/}")"
    huelle --unshare-user --uid 0 --gid 0 bash "$WEGWERF" --innen installieren "$A" "$OUT/alt-installieren" "${attrappen[@]}" "${alt[@]}" </dev/null
    echo "== 2 Probe-Benutzer, Zustand vorher, 3 apt-Simulation"
    huelle bash "$HIER" --innen vorher "$A" "$OUT/upgrade" "$ALT" "$NEU" </dev/null
    echo "== 4 Upgrade: neuer Satz $(basename "$NEU") (${#neu[@]} Pakete, SHA256SUMS $(sha256sum "$NEU/SHA256SUMS" | cut -c1-16)…) mit dpkg -i"
    huelle --unshare-user --uid 0 --gid 0 bash "$WEGWERF" --innen installieren "$A" "$OUT/upgrade-installieren" "${neu[@]}" </dev/null
    echo "== 5 Ablösung Files → Dateien"
    huelle bash "$HIER" --innen nachher "$A" "$OUT/upgrade" "$ALT" "$NEU" </dev/null
    echo "== 6 volle Prüfung des neuen Stands (wegwerf-installation.sh, Teil pruefen)"
    huelle bash "$WEGWERF" --innen pruefen "$A" "$OUT/sitzung" "${neu[@]}" </dev/null
    huelle bash "$HIER" --innen danach "$A" "$OUT/upgrade" "$ALT" "$NEU" </dev/null
} 2>&1 | tee "$OUT/ergebnis.txt"
p=$(grep -c '^PASS' "$OUT/ergebnis.txt") f=$(grep -c '^FAIL' "$OUT/ergebnis.txt") h=$(grep -c '^HINW' "$OUT/ergebnis.txt")
echo "Ergebnis: $p PASS, $f FAIL, $h Hinweise" | tee -a "$OUT/ergebnis.txt"
[ "$f" -eq 0 ]
