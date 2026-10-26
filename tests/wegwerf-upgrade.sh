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
# org.querencia.Files.desktop = Alpha 2.2; Alpha 2.1: io.github.lgse.Strata.desktop;
# Alpha 3: org.querencia.Dateien.desktop).
# UPGRADE_NEU: Pakete, die das Upgrade neu installiert (Vorgabe
# "querencia-dateien"; Alpha 3 -> 3.1: leer).
# UPGRADE_FILES_ORDNER: Ordner der Files-Einstellungen des Probe-Benutzers A
# unter ~/.config. Vorgabe (QD-172 T-2): der Ordner, den das Files des alten
# Satzes wirklich schreibt, abgelesen am Programm (Alpha 2.1: strata,
# Alpha-2.2-Kandidat: querencia-files); ab Alpha 3 enthält der alte Satz nur
# das Übergangspaket, dann strata (dort liegen die Einstellungen aller
# veröffentlichten Files-Fassungen; Dateien übernimmt sie ab 0.2.1).
#
# Enthält der alte Satz querencia-webhuelle 0.2.0 und wird es installiert
# (nicht in UPGRADE_OHNE), legt die Probe die Ordner der Webhülle am echten
# Pfad an (~/.local/share, ~/.config, ~/.cache je querencia-webhuelle, 0700,
# Lehre QD-171/172) und prüft den Übergang auf Schnatter. Enthält der neue
# Satz querencia-schnatter, prüft sie außerdem, dass es sich ohne den Desktop
# entfernen lässt und apt es danach nicht wieder holt.
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
    WH_ORDNER=".local/share .config .cache"
    webhuelle_alt() { grep -q '^querencia-webhuelle 0\.2\.' "$OUT/versionen-vorher.txt" 2>/dev/null; }
    schnatter_neu() { ls "$NEU"/querencia-schnatter_*.deb >/dev/null 2>&1; }
    ordnerstand() { # je Ordner: Inode, Rechte, Prüfsumme des Inhalts
        local n=$1 e d
        for e in $WH_ORDNER; do
            d=$A/home/$e/$n
            if [ -d "$d" ]; then
                echo "$e $(stat -c '%i %a' "$d") $(cd "$d" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16)"
            else
                echo "$e fehlt"
            fi
        done
    }
    files_ordner() { # Ordner, in den das Files des alten Satzes schreibt
        local d=$(ls "$ALT"/querencia-files_*.deb 2>/dev/null | head -n 1)
        if [ -n "${UPGRADE_FILES_ORDNER-}" ]; then echo "$UPGRADE_FILES_ORDNER"
        elif [ -z "$d" ] || ! dpkg-deb -c "$d" | grep -q ' \./usr/bin/querencia-files$'; then echo strata
        elif dpkg-deb --fsys-tarfile "$d" | tar -xO ./usr/bin/querencia-files | strings -a | grep -q 'strata/'; then echo strata
        else echo querencia-files; fi
    }
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
        FO=$(files_ordner)
        echo "$FO" >"$A/files-ordner"
        mkdir -p "$H/.config/gtk-3.0" "$H/.config/$FO" "$H/Dokumente" "$H/Bilder" "$H/Projekt Ä" \
            "$HB/.config"
        printf '%s\n' "file://$H/Dokumente" "file://$H/Bilder Urlaubsbilder" "file://$H/Projekt%20%C3%84 Projekt Ä" \
            "sftp://server.invalid/srv/daten Netzordner" >"$H/.config/gtk-3.0/bookmarks"
        printf '%s\n' 'show_hidden = true' 'browser_mode = "columns"' 'sort_key = "modified"' 'folders_first = true' \
            'grid_folder_clicks = 2' 'list_folder_clicks = 2' 'sidebar_expanded = true' >"$H/.config/$FO/settings.toml"
        printf '%s\n' '[Default Applications]' 'inode/directory=io.github.lgse.Strata.desktop' >"$HB/.config/mimeapps.list"
        (cd "$H" && sha256sum .config/gtk-3.0/bookmarks ".config/$FO/settings.toml") >"$OUT/home-vorher.sha256"
        dpkg-query --root="$R" -W -f='${Package} ${Version} ${db:Status-Abbrev}\n' 'querencia-*' labwc 2>/dev/null |
            sort >"$OUT/versionen-vorher.txt"
        ok "vorher: Files-Einstellungen am Pfad des alten Files angelegt: ~/.config/$FO/settings.toml"
        if webhuelle_alt; then
            # Ordner der Webhülle 0.2.0 am echten Pfad, Attrappe der Anmeldung
            # (Zufall, nie echte Daten), Einstellungen wie 0.2.0 sie schreibt
            for e in $WH_ORDNER; do
                d=$H/$e/querencia-webhuelle
                mkdir -p "$d/storage/attrappe" && chmod 0700 "$d"
                head -c 4096 /dev/urandom >"$d/storage/attrappe/anmeldung.db"
            done
            printf '[Fenster]\nbreite=1000\nhoehe=700\nmaximiert=false\n\n[Seite]\nkennung=standard\nzoom=1.25\n' \
                >"$H/.config/querencia-webhuelle/einstellungen.ini"
            ordnerstand querencia-webhuelle >"$OUT/webhuelle-ordner-vorher.txt"
            for e in $WH_ORDNER; do (cd "$H/$e/querencia-webhuelle" && sha256sum storage/attrappe/anmeldung.db | sed "s|  |  $e/|"); done >"$OUT/webhuelle-attrappen.sha256"
            ok "vorher: querencia-webhuelle $(awk '$1 == "querencia-webhuelle" {print $2}' "$OUT/versionen-vorher.txt") mit Ordnern am echten Pfad (~/.local/share, ~/.config, ~/.cache)"
        fi
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
        # querencia-webhuelle 0.2.0 war optional: wer es hat, hat es selbst gewählt
        for p in $(awk '$1 ~ /^(querencia-|labwc$)/ && $1 != "querencia-desktop" && $1 != "querencia-webhuelle" && $3 == "ii" {print $1}' "$OUT/versionen-vorher.txt"); do
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
        neu=$(awk '/^Inst [^ ]+ \(/ {print $2}' "$OUT/apt-full-upgrade-simulation.txt" | sort | imsatz)
        hoch=$(awk '/^Inst [^ ]+ \[/ {print $2}' "$OUT/apt-full-upgrade-simulation.txt" | imsatz)
        fremd=$(awk '/^Inst / {print $2}' "$OUT/apt-full-upgrade-simulation.txt" | while read -r p; do [[ " $satz " == *" $p "* ]] || echo "$p"; done | wc -l)
        echo "apt -s full-upgrade: neu: ${neu}| aktualisiert: ${hoch}| entfernt: ${remv:-keins} (dazu $fremd ausstehende Updates dieses Rechners)"
        soll_neu=$(for p in ${UPGRADE_NEU-querencia-dateien}; do echo "$p"; done | sort | tr '\n' ' ')
        [ $rc -eq 0 ] && [ -z "$remv" ] && [ "$neu" = "$soll_neu" ] &&
            ok "apt -s full-upgrade: neu ${soll_neu:-nichts}, aktualisiert ${hoch}, nichts entfernt" ||
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
        if schnatter_neu; then
            echo " $q " | grep -q ' querencia-schnatter ' && ! echo " $q " | grep -q ' querencia-webhuelle ' &&
                ok "Neuinstallation: zieht querencia-schnatter (Recommends), nicht das Übergangspaket querencia-webhuelle" ||
                nok "Neuinstallation ohne querencia-schnatter oder mit querencia-webhuelle: $q"
        fi
        if webhuelle_alt; then
            echo " $hoch " | grep -q ' querencia-webhuelle ' && ok "apt -s full-upgrade: querencia-webhuelle wird auf das Übergangspaket aktualisiert" ||
                nok "apt -s full-upgrade: querencia-webhuelle nicht aktualisiert"
        fi
        fa=$(dpkg-deb -f "$ALT"/querencia-files_*.deb Version 2>/dev/null) fn=$(dpkg-deb -f "$NEU"/querencia-files_*.deb Version)
        if [ "$fa" = "$fn" ]; then
            ! echo " $hoch " | grep -q ' querencia-files ' && ok "apt -s full-upgrade: Übergangspaket querencia-files $fn bleibt" ||
                nok "apt -s full-upgrade: querencia-files gleicher Version neu installiert"
        else
            echo " $hoch " | grep -q ' querencia-files ' && ok "apt -s full-upgrade: querencia-files wird auf das Übergangspaket aktualisiert" ||
                nok "apt -s full-upgrade: querencia-files nicht aktualisiert"
        fi
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
        wh=; webhuelle_alt && wh="querencia-webhuelle $(dpkg-deb -f "$NEU"/querencia-webhuelle_*.deb Version)"
        sn=; schnatter_neu && sn="querencia-schnatter $(dpkg-deb -f "$NEU"/querencia-schnatter_*.deb Version)"
        for want in "querencia-dateien $(dpkg-deb -f "$NEU"/querencia-dateien_*.deb Version)" ${sn:+"$sn"} ${wh:+"$wh"} \
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
        if webhuelle_alt; then
            ordnerstand querencia-webhuelle >"$OUT/webhuelle-ordner-nach-upgrade.txt"
            cmp -s "$OUT/webhuelle-ordner-vorher.txt" "$OUT/webhuelle-ordner-nach-upgrade.txt" &&
                ok "Upgrade: Ordner der Webhülle unberührt (Inode, Rechte, Inhalt; den Umzug macht Schnatter beim Start)" ||
                nok "Upgrade hat die Ordner der Webhülle verändert ($OUT/webhuelle-ordner-nach-upgrade.txt)"
            b=$APPS/org.querencia.Webhuelle.desktop
            [ -f "$b" ] && grep -qx 'NoDisplay=true' "$b" && grep -qx 'Exec=querencia-schnatter' "$b" &&
                ok "Brücken-Starter org.querencia.Webhuelle.desktop: versteckt, startet querencia-schnatter" ||
                nok "Brücken-Starter der Webhülle: $(grep -E '^(NoDisplay|Exec)=' "$b" 2>/dev/null | tr '\n' ' ')"
        fi

        # apt: was "autoremove" danach vorschlüge (auto-Markierung wie oben,
        # querencia-dateien als neue Abhängigkeit ebenfalls automatisch)
        printf 'Package: querencia-dateien\nArchitecture: amd64\nAuto-Installed: 1\n\n' >>"$A/apt/state/extended_states"
        schnatter_neu && ! webhuelle_alt && printf 'Package: querencia-schnatter\nArchitecture: amd64\nAuto-Installed: 1\n\n' >>"$A/apt/state/extended_states"
        apt_s -s autoremove >"$OUT/apt-autoremove-simulation.txt" 2>&1
        weg=$(grep '^Remv ' "$OUT/apt-autoremove-simulation.txt" | awk '{print $2}' | tr '\n' ' ')
        apt_s -s -o APT::AutoRemove::SuggestsImportant=false autoremove >"$OUT/apt-autoremove-ohne-suggests.txt" 2>&1
        weg2=$(grep '^Remv ' "$OUT/apt-autoremove-ohne-suggests.txt" | awk '{print $2}' | tr '\n' ' ')
        echo "apt -s autoremove: ${weg:-nichts}; ohne Suggests-Schutz: ${weg2:-nichts}"
        grep -q 'Package: querencia-shell' "$R/var/lib/dpkg/status" && sug=$(dpkg-query --root="$R" -W -f='${Suggests}' querencia-shell)
        hinweis "apt autoremove schlüge vor: ${weg:-nichts}; mit APT::AutoRemove::SuggestsImportant=false: ${weg2:-nichts} (querencia-shell Suggests: ${sug:-–})"
        echo " $weg " | grep -q ' querencia-files ' && nok "querencia-files würde mit autoremove entfernt; mit ihm gingen die Brücken" ||
            ok "apt autoremove behält das Übergangspaket querencia-files (Brücken bleiben)"
        if schnatter_neu; then
            echo " $weg " | grep -q -E ' querencia-(schnatter|webhuelle) ' && nok "apt autoremove entfernte Schnatter: $weg" ||
                ok "apt autoremove behält querencia-schnatter$(webhuelle_alt && echo " und das Übergangspaket querencia-webhuelle")"
            # entfernbar ohne Schaden: apt remove nimmt nur Schnatter (und das
            # Übergangspaket, das davon abhängt), nicht den Desktop
            apt_s -s remove querencia-schnatter >"$OUT/apt-remove-schnatter-simulation.txt" 2>&1
            rm_=$(awk '/^Remv / {print $2}' "$OUT/apt-remove-schnatter-simulation.txt" | sort | tr '\n' ' ')
            soll=$(webhuelle_alt && echo "querencia-schnatter querencia-webhuelle " || echo "querencia-schnatter ")
            [ "$rm_" = "$soll" ] && ok "apt -s remove querencia-schnatter: entfernt nur ${soll}(querencia-desktop bleibt)" ||
                nok "apt -s remove querencia-schnatter entfernt: ${rm_:-nichts} ($OUT/apt-remove-schnatter-simulation.txt)"
        fi
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
        # die Probe-Werte (Spalten → Liste, Datum, verborgene Dateien) kamen an
        grep -qx 'Ansicht=liste' "$ini" 2>/dev/null && grep -qx 'Anordnen=datum' "$ini" && grep -qx 'Verborgene=true' "$ini" &&
            ok "übernommene Werte aus ~/.config/$(cat "$A/files-ordner"): Liste, nach Datum, verborgene Dateien" ||
            nok "dateien.ini ohne die Probe-Werte aus ~/.config/$(cat "$A/files-ordner") ($(grep -E '^(Ansicht|Anordnen|Verborgene)=' "$ini" 2>/dev/null | tr '\n' ' '))"
        if webhuelle_alt; then
            # in der Sitzungsprüfung startete jeder Starter, auch Schnatter: der
            # Umzug benennt die Ordner um (gleiche Inode und Rechte, die Attrappe
            # der Anmeldung unverändert). Danach schreibt WebKit eigene Dateien
            # dazu; der Inhalt als Ganzes ist deshalb kein Maß.
            ordnerstand querencia-schnatter >"$OUT/schnatter-ordner-danach.txt"
            ordnerstand querencia-webhuelle >"$OUT/webhuelle-ordner-danach.txt"
            att=0; for e in $WH_ORDNER; do
                (cd "$H/$e/querencia-schnatter" 2>/dev/null && grep " $e/" "$OUT/webhuelle-attrappen.sha256" | sed "s|  $e/|  |" | sha256sum -c --quiet) >/dev/null 2>&1 && att=$((att + 1))
            done
            if [ "$(cut -d' ' -f1-3 "$OUT/webhuelle-ordner-vorher.txt")" = "$(cut -d' ' -f1-3 "$OUT/schnatter-ordner-danach.txt")" ] &&
                [ "$(grep -c fehlt "$OUT/webhuelle-ordner-danach.txt")" = 3 ] && [ $att = 3 ]; then
                ok "nach dem Start von Schnatter: Ordner der Webhülle umbenannt (gleiche Inode, 0700, Attrappe der Anmeldung gleich in allen drei)"
                grep -qx 'zoom=1.25' "$H/.config/querencia-schnatter/einstellungen.ini" && ok "Schnatter: Einstellungen der Webhülle (Zoom 1,25) übernommen" ||
                    nok "Schnatter: Einstellungen der Webhülle fehlen"
            elif cmp -s "$OUT/webhuelle-ordner-vorher.txt" "$OUT/webhuelle-ordner-danach.txt"; then
                hinweis "Schnatter lief in der Sitzungsprüfung nicht bis zum Umzug; Ordner der Webhülle unverändert"
            else
                nok "Ordner nach dem Start von Schnatter: $(paste -sd' ' "$OUT/schnatter-ordner-danach.txt") / Webhülle: $(paste -sd' ' "$OUT/webhuelle-ordner-danach.txt")"
            fi
        fi
        ls "$OUT"/../sitzung/start-org.querencia.Dateien.png >/dev/null 2>&1 &&
            ok "Bildschirmfoto Dateien mit Lesezeichen in der Seitenleiste: sitzung/start-org.querencia.Dateien.png" ||
            hinweis "kein Bildschirmfoto von Dateien"
        ;;
    entfernen)
        # als root der Hülle: Schnatter wirklich entfernen (dpkg -r), danach
        # sieht apt nach, ob ein Upgrade es wieder holte (Recommends, die schon
        # vorher galten, installiert apt nicht nach) und ob alles heil bleibt
        D() { dpkg --root="$R" --force-not-root "$@"; }
        weg=querencia-schnatter; webhuelle_alt && weg="querencia-webhuelle querencia-schnatter"
        # shellcheck disable=SC2086
        D --force-script-chrootless --no-triggers --log="$OUT/dpkg-remove.log" -r $weg >"$OUT/dpkg-remove-schnatter.txt" 2>&1
        rc=$?
        st=$(dpkg-query --root="$R" -W -f='${db:Status-Abbrev}' querencia-desktop 2>/dev/null | tr -d ' ')
        [ $rc -eq 0 ] && [ "$st" = ii ] && ok "dpkg -r $weg: rc 0, querencia-desktop bleibt installiert" ||
            nok "dpkg -r $weg: rc $rc, querencia-desktop $st ($OUT/dpkg-remove-schnatter.txt)"
        rest=$(for f in /usr/bin/querencia-schnatter /usr/share/applications/org.querencia.Schnatter.desktop /usr/share/applications/org.querencia.Webhuelle.desktop; do
            [ -e "$R$f" ] && echo "$f"; done | tr '\n' ' ')
        [ -z "$rest" ] && ok "nach dem Entfernen: kein Programm, kein Starter von Schnatter" || nok "nach dem Entfernen noch da: $rest"
        if webhuelle_alt; then
            [ "$(grep -c fehlt <(ordnerstand querencia-schnatter))" = 0 ] || [ "$(grep -c fehlt <(ordnerstand querencia-webhuelle))" = 0 ] &&
                ok "nach dem Entfernen: Anmeldung und Einstellungen des Benutzers bleiben liegen" || nok "nach dem Entfernen: Benutzerordner fehlen"
        fi
        for art in full-upgrade "upgrade --with-new-pkgs"; do
            datei=$OUT/apt-$(echo "$art" | tr -d ' -')-nach-entfernen.txt
            # shellcheck disable=SC2086
            apt_s -s $art >"$datei" 2>&1; rc=$?
            wieder=$(awk '/^Inst (querencia-|labwc )/ {print $2}' "$datei" | tr '\n' ' ')
            [ $rc -eq 0 ] && [ -z "$wieder" ] && ok "apt -s $art nach dem Entfernen: holt Schnatter nicht wieder, nichts zu tun" ||
                nok "apt -s $art nach dem Entfernen: rc $rc, installierte: ${wieder:-nichts} ($datei)"
        done
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
# dpkg -i ordnet nicht um wie apt: querencia-schnatter bricht
# querencia-webhuelle (<< 0.3.0~), erst das entpackte Übergangspaket
# querencia-webhuelle 0.3.0 erfüllt das. Übergangspakete deshalb zuerst.
mapfile -t neu < <(printf '%s\n' "${neu[@]}" | grep '/querencia-webhuelle_'; printf '%s\n' "${neu[@]}" | grep -v '/querencia-webhuelle_')
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
    if ls "$NEU"/querencia-schnatter_*.deb >/dev/null 2>&1; then
        echo "== 7 Schnatter entfernen (Recommends: entfernbar, apt holt es nicht wieder)"
        huelle --unshare-user --uid 0 --gid 0 bash "$HIER" --innen entfernen "$A" "$OUT/upgrade" "$ALT" "$NEU" </dev/null
    fi
} 2>&1 | tee "$OUT/ergebnis.txt"
p=$(grep -c '^PASS' "$OUT/ergebnis.txt") f=$(grep -c '^FAIL' "$OUT/ergebnis.txt") h=$(grep -c '^HINW' "$OUT/ergebnis.txt")
echo "Ergebnis: $p PASS, $f FAIL, $h Hinweise" | tee -a "$OUT/ergebnis.txt"
[ "$f" -eq 0 ]
