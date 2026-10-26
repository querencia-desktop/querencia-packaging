#!/bin/bash
# Upgrade-Probe Querencia Webhülle 0.2.0-1 → Schnatter 0.3.0-1 (Umbenennung,
# Übergangspaket querencia-webhuelle 0.3.0-1) ohne zweite VM, in derselben
# Wegwerf-Hülle wie tests/wegwerf-installation.sh (bubblewrap, dpkg --root
# auf einer Kopie der Paketdatenbank, kein Netz, kein Bus):
#   1. der alte Satz wird installiert (Vorgabe ohne querencia-anmeldung, wie
#      in wegwerf-upgrade.sh),
#   2. ein Probe-Benutzer bekommt die Ordner der Webhülle AM ECHTEN PFAD
#      (~/.local/share, ~/.cache, ~/.config je querencia-webhuelle, 0700) mit
#      einer Attrappe der Anmeldung und den Einstellungen, wie 0.2.0 sie
#      schreibt (Lehre aus QD-172: Ausgangsstand wie beim Nutzer),
#   3. apt-get -s full-upgrade und upgrade --with-new-pkgs gegen eine
#      Datei-Quelle mit dem neuen Satz (bringt apt Schnatter mit?),
#   4. die geänderten Pakete des neuen Satzes werden mit dpkg -i
#      darübergespielt (Upgrade samt Maintainer-Skripten),
#   5. geprüft: Pakete und Dateien, Brücken-Starter, die Ordner sind vom
#      Upgrade unberührt (Paketskripte fassen Benutzerdaten nie an),
#   6. Schnatter startet einmal ohne Bildschirm als Probe-Benutzer: der Umzug
#      läuft vor allem anderen (rename, gleiche Inode, Attrappe und
#      Einstellungen gleich), ein zweiter Start findet nichts mehr,
#   7. apt-get -s autoremove nach dem Upgrade.
# Das echte System bleibt unverändert.
#
#   bash tests/wegwerf-upgrade-schnatter.sh <nachweisordner> <ordner alter satz> <ordner neuer satz>
#
# Ergebnis: PASS/FAIL/HINW je Prüfung in <nachweisordner>/ergebnis.txt,
# Exit 1 bei einem FAIL.
set -uo pipefail
HIER=$(readlink -f "$0")
WEGWERF=$(dirname "$HIER")/wegwerf-installation.sh
ORDNER="daten:.local/share cache:.cache konfig:.config"

if [ "${1-}" = --innen ]; then
    shift
    TEIL=$1 A=$2 OUT=$3 ALT=$4 NEU=$5
    R=$A/wurzel H=$A/home
    pass=0 fail=0
    ok() { pass=$((pass + 1)); echo "PASS $*"; }
    nok() { fail=$((fail + 1)); echo "FAIL $*"; }
    hinweis() { echo "HINW $*"; }
    apt_s() { # apt-get gegen die Wegwerf-Paketdatenbank und Datei-Quellen
        apt-get -q -o Dir::State::status="$R/var/lib/dpkg/status" -o Dir::State="$A/apt/state" \
            -o Dir::State::extended_states="$A/apt/state/extended_states" -o Dir::Cache="$A/apt/cache" \
            -o Dir::Etc::sourcelist="$A/apt/sources.list" -o Dir::Etc::sourceparts="$A/apt/quellen.d" \
            -o Dir::Etc::preferences="$A/apt/preferences" -o Dir::Etc::preferencesparts="$A/apt/leer" \
            -o Dir::Log="$A/apt/log" -o Debug::NoLocking=1 -o APT::Get::List-Cleanup=0 \
            -o Acquire::Languages=none "$@"
    }
    version() { dpkg-query --root="$R" -W -f='${Version} ${db:Status-Abbrev}' "$1" 2>/dev/null | sed 's/ *$//'; }
    ordnerstand() { # je Ordner: Name Inode Rechte Prüfsummen der Dateien
        local n=$1 e
        for e in $ORDNER; do
            local d=$H/${e#*:}/$n
            if [ -d "$d" ]; then
                echo "${e%%:*} $(stat -c '%i %a' "$d") $(cd "$d" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16)"
            else
                echo "${e%%:*} fehlt"
            fi
        done
    }
    programm() { # Schnatter als Probe-Benutzer starten, ohne Bildschirm
        env -i PATH="$R/usr/bin:/usr/bin:/bin" HOME="$H" LANG=de_DE.UTF-8 LANGUAGE=de \
            XDG_DATA_DIRS="$R/usr/share:/usr/share" QUERENCIA_SCHNATTER_DEBUG=1 GSETTINGS_BACKEND=memory \
            timeout 20 "$R/usr/bin/querencia-schnatter" >"$OUT/$1.out" 2>&1
        echo "rc=$?" >>"$OUT/$1.out"
    }

    case $TEIL in
    vorher)
        # Ordner der Webhülle am echten Pfad, Attrappe der Anmeldung (Zufall,
        # nie echte Daten) und Einstellungen wie von 0.2.0 geschrieben
        for e in $ORDNER; do
            d=$H/${e#*:}/querencia-webhuelle
            mkdir -p "$d/storage/attrappe" && chmod 0700 "$d"
            head -c 4096 /dev/urandom >"$d/storage/attrappe/anmeldung.db"
        done
        printf '[Fenster]\nbreite=1000\nhoehe=700\nmaximiert=false\n\n[Seite]\nkennung=standard\nzoom=1.25\n' \
            >"$H/.config/querencia-webhuelle/einstellungen.ini"
        ordnerstand querencia-webhuelle >"$OUT/ordner-vorher.txt"
        cat "$OUT/ordner-vorher.txt"
        v=$(version querencia-webhuelle)
        [ "$v" = "0.2.0-1 ii" ] && ok "vorher: querencia-webhuelle 0.2.0-1 installiert" || nok "vorher: querencia-webhuelle $v"
        [ -x "$R/usr/bin/querencia-webhuelle" ] && ok "vorher: /usr/bin/querencia-webhuelle da" || nok "vorher: Programm fehlt"
        dpkg-query --root="$R" -W -f='${Package} ${Version} ${db:Status-Abbrev}\n' 'querencia-*' labwc 2>/dev/null |
            sort >"$OUT/versionen-vorher.txt"

        # apt-Simulation wie wegwerf-upgrade.sh: Datei-Quellen mit neuem und
        # altem Satz, Ubuntu-Archiv aus den Listen des Rechners; alles außer
        # querencia-desktop und querencia-webhuelle automatisch installiert
        # (beide hat der Nutzer ausdrücklich gewählt)
        mkdir -p "$A/apt/state/lists/partial" "$A/apt/cache/archives/partial" "$A/apt/log" "$A/apt/neu" "$A/apt/alt" "$A/apt/leer" "$A/apt/quellen.d"
        : >"$A/apt/preferences"
        for f in /var/lib/apt/lists/*_Packages /var/lib/apt/lists/*_InRelease /var/lib/apt/lists/*_Release; do
            [ -f "$f" ] && cp "$f" "$A/apt/state/lists/"
        done
        cp /etc/apt/sources.list.d/*.sources "$A/apt/quellen.d/" 2>/dev/null
        ln -s "$NEU"/*.deb "$A/apt/neu/" && ln -s "$ALT"/*.deb "$A/apt/alt/"
        (cd "$A/apt/neu" && dpkg-scanpackages -m . 2>/dev/null >Packages)
        (cd "$A/apt/alt" && dpkg-scanpackages -m . 2>/dev/null >Packages)
        printf '%s\n' "deb [trusted=yes] file:$A/apt/neu ./" "deb [trusted=yes] file:$A/apt/alt ./" >"$A/apt/sources.list"
        for p in $(awk '$1 ~ /^(querencia-|labwc$)/ && $1 != "querencia-desktop" && $1 != "querencia-webhuelle" && $3 == "ii" {print $1}' "$OUT/versionen-vorher.txt"); do
            printf 'Package: %s\nArchitecture: %s\nAuto-Installed: 1\n\n' "$p" "$(dpkg-query --root="$R" -W -f='${Architecture}' "$p")"
        done >"$A/apt/state/extended_states"
        apt_s update >"$OUT/apt-update.txt" 2>&1
        grep -q "file:$A/apt/neu ./ Packages" "$OUT/apt-update.txt" && ok "apt-get update: Datei-Quellen gelesen" ||
            nok "apt-get update: $(tail -2 "$OUT/apt-update.txt" | tr '\n' ' ')"
        satz=$(for d in "$NEU"/*.deb "$ALT"/*.deb; do dpkg-deb -f "$d" Package; done | sort -u | tr '\n' ' ')
        imsatz() { while read -r p; do [[ " $satz " == *" $p "* ]] && echo "$p"; done | sort | tr '\n' ' '; }
        for art in full-upgrade "upgrade --with-new-pkgs"; do
            datei=$OUT/apt-$(echo "$art" | tr -d ' -')-simulation.txt
            # shellcheck disable=SC2086
            apt_s -s $art >"$datei" 2>&1; rc=$?
            neu=$(awk '/^Inst [^ ]+ \(/ {print $2}' "$datei" | imsatz)
            hoch=$(awk '/^Inst [^ ]+ \[/ {print $2}' "$datei" | imsatz)
            remv=$(awk '/^Remv / {print $2}' "$datei" | tr '\n' ' ')
            zurueck=$(sed -n '/zurückgehalten\|kept back/,/^[^ ]/p' "$datei" | grep '^ ' | tr ' ' '\n' | grep . | imsatz)
            echo "apt -s $art: neu: ${neu}| aktualisiert: ${hoch}| entfernt: ${remv:-keins}| zurückgehalten: ${zurueck:-nichts}"
            [ $rc -eq 0 ] && [ "$neu" = "querencia-schnatter " ] && [[ " $hoch " == *" querencia-webhuelle "* ]] && [ -z "$remv" ] && [ -z "$zurueck" ] &&
                ok "apt -s $art: querencia-schnatter neu, querencia-webhuelle auf das Übergangspaket, nichts entfernt oder zurückgehalten" ||
                nok "apt -s $art: rc $rc, neu: $neu, aktualisiert: $hoch, entfernt: ${remv:-keins}, zurückgehalten: ${zurueck:-nichts} ($datei)"
        done
        ;;

    nachher)
        dpkg-query --root="$R" -W -f='${Package} ${Version} ${db:Status-Abbrev}\n' 'querencia-*' labwc 2>/dev/null |
            sort >"$OUT/versionen-nachher.txt"
        diff "$OUT/versionen-vorher.txt" "$OUT/versionen-nachher.txt" >"$OUT/versionen-diff.txt"
        sed 's/^/  /' "$OUT/versionen-diff.txt"
        sv=$(dpkg-deb -f "$NEU"/querencia-schnatter_*.deb Version)
        [ "$(version querencia-schnatter)" = "$sv ii" ] && ok "nachher: querencia-schnatter $sv installiert" || nok "nachher: querencia-schnatter $(version querencia-schnatter)"
        [ "$(version querencia-webhuelle)" = "0.3.0-1 ii" ] && ok "nachher: querencia-webhuelle 0.3.0-1 (Übergangspaket)" || nok "nachher: querencia-webhuelle $(version querencia-webhuelle)"
        [ "$(dpkg-query --root="$R" -W -f='${Section}' querencia-webhuelle)" = oldlibs ] && ok "querencia-webhuelle: Section oldlibs" || nok "querencia-webhuelle: Section $(dpkg-query --root="$R" -W -f='${Section}' querencia-webhuelle)"
        rest=$(for f in /usr/bin/querencia-webhuelle /usr/share/locale/de/LC_MESSAGES/querencia-webhuelle.mo \
            /usr/share/metainfo/org.querencia.Webhuelle.metainfo.xml /usr/share/icons/hicolor/scalable/apps/org.querencia.Webhuelle.svg \
            /usr/share/man/man1/querencia-webhuelle.1.gz; do [ -e "$R$f" ] && echo "$f"; done | tr '\n' ' ')
        [ -z "$rest" ] && ok "Webhülle ausgemustert: kein Befehl, Katalog, MetaInfo, Symbol, Handbuch der Webhülle" || nok "Reste der Webhülle: $rest"
        for f in /usr/bin/querencia-schnatter /usr/share/applications/org.querencia.Schnatter.desktop \
            /usr/share/icons/hicolor/scalable/apps/org.querencia.Schnatter.svg /usr/share/locale/de/LC_MESSAGES/querencia-schnatter.mo \
            /usr/share/metainfo/org.querencia.Schnatter.metainfo.xml /usr/share/man/man1/querencia-schnatter.1.gz; do
            [ -e "$R$f" ] && ok "Schnatter: $f" || nok "Schnatter: $f fehlt"
        done
        b=$R/usr/share/applications/org.querencia.Webhuelle.desktop
        if [ -f "$b" ] && grep -qx 'NoDisplay=true' "$b" && grep -qx 'Exec=querencia-schnatter' "$b" && ! grep -q '^MimeType=' "$b"; then
            ok "Brücken-Starter org.querencia.Webhuelle.desktop: versteckt, startet querencia-schnatter"
        else
            nok "Brücken-Starter: $(grep -E '^(NoDisplay|Exec)=' "$b" 2>/dev/null | tr '\n' ' ')"
        fi
        inhalt=$(dpkg-query --root="$R" -L querencia-webhuelle 2>/dev/null | while read -r f; do [ -f "$R$f" ] && echo "$f"; done |
            grep -v -x -E '/usr/share/applications/org\.querencia\.Webhuelle\.desktop|/usr/share/doc/querencia-webhuelle/(README\.Debian|changelog\.Debian\.gz|copyright)|/usr/share/lintian/overrides/querencia-webhuelle' | tr '\n' ' ')
        [ -z "$inhalt" ] && ok "querencia-webhuelle enthält nur den Brücken-Starter und seine Doku" || nok "querencia-webhuelle enthält: $inhalt"
        sichtbar=$(for d in "$R"/usr/share/applications/org.querencia.{Schnatter,Webhuelle}.desktop; do
            grep -qx 'NoDisplay=true' "$d" || basename "$d"; done | tr '\n' ' ')
        [ "$sichtbar" = "org.querencia.Schnatter.desktop " ] && ok "im Menü nur Schnatter" || nok "im Menü: $sichtbar"
        grep -q -E -i 'conffile|Konfigurationsdatei .*(geändert|modified)' "$OUT/../upgrade-installieren/dpkg-i.txt" 2>/dev/null &&
            nok "Upgrade: dpkg fragt nach einer Konfigurationsdatei" || ok "Upgrade: keine Konfigurationsdatei-Rückfrage"
        # Benutzerdaten: das Upgrade fasst sie nicht an
        ordnerstand querencia-webhuelle >"$OUT/ordner-nach-upgrade.txt"
        cmp -s "$OUT/ordner-vorher.txt" "$OUT/ordner-nach-upgrade.txt" &&
            ok "Upgrade: Ordner der Webhülle unberührt (Inode, Rechte, Inhalt)" || nok "Upgrade hat die Ordner verändert ($OUT/ordner-nach-upgrade.txt)"
        [ "$(ordnerstand querencia-schnatter | grep -c fehlt)" = 3 ] && ok "Upgrade: noch keine Ordner von Schnatter (der Umzug ist Sache des Programms)" ||
            nok "Upgrade legte Ordner von Schnatter an"

        # erster Start ohne Bildschirm: der Umzug läuft vor GTK
        programm start1
        # (das Prüfereignis „umzug“ schreibt die Hülle erst nach dem Start von
        # GTK; ohne Bildschirm zählen die Protokollzeilen des Umzugs)
        n=0
        for e in $ORDNER; do
            grep -q "Umzug: $H/${e#*:}/querencia-webhuelle nach $H/${e#*:}/querencia-schnatter umbenannt" "$OUT/start1.out" && n=$((n + 1))
        done
        [ "$n" = 3 ] && ok "erster Start: querencia-webhuelle → querencia-schnatter in allen drei Ordnern (Protokoll)" || nok "erster Start: $n von 3 Protokollzeilen ($OUT/start1.out)"
        ordnerstand querencia-schnatter >"$OUT/ordner-nach-start.txt"
        cmp -s "$OUT/ordner-vorher.txt" "$OUT/ordner-nach-start.txt" &&
            ok "Umzug: querencia-schnatter mit derselben Inode, 0700 und demselben Inhalt (umbenannt, nicht kopiert)" ||
            nok "Umzug: $(diff "$OUT/ordner-vorher.txt" "$OUT/ordner-nach-start.txt" | tr '\n' ' ')"
        [ "$(ordnerstand querencia-webhuelle | grep -c fehlt)" = 3 ] && ok "Umzug: keine Ordner der Webhülle mehr" || nok "Umzug: Ordner der Webhülle noch da"
        grep -qx 'zoom=1.25' "$H/.config/querencia-schnatter/einstellungen.ini" && ok "Umzug: Einstellungen (Zoom 1,25) übernommen" || nok "Umzug: Einstellungen fehlen"
        if grep -q -E 'panicked at|Segmentation|core dumped' "$OUT/start1.out"; then nok "erster Start: Absturz ($OUT/start1.out)"
        else hinweis "erster Start ohne Bildschirm endet mit $(tail -1 "$OUT/start1.out") (GTK braucht Wayland): $(grep -v '^querencia-schnatter: \|^rc=' "$OUT/start1.out" | head -1 | cut -c1-80)"; fi
        programm start2
        ordnerstand querencia-schnatter >"$OUT/ordner-nach-start2.txt"
        ! grep -q 'Umzug' "$OUT/start2.out" && cmp -s "$OUT/ordner-nach-start.txt" "$OUT/ordner-nach-start2.txt" &&
            ok "zweiter Start: nichts mehr umzuziehen, Ordner unverändert" || nok "zweiter Start: $(grep Umzug "$OUT/start2.out" | head -2 | tr '\n' ' ')"

        # autoremove: Schnatter hängt am Übergangspaket und bleibt
        printf 'Package: querencia-schnatter\nArchitecture: amd64\nAuto-Installed: 1\n\n' >>"$A/apt/state/extended_states"
        apt_s -s autoremove >"$OUT/apt-autoremove-simulation.txt" 2>&1
        weg=$(grep '^Remv ' "$OUT/apt-autoremove-simulation.txt" | awk '{print $2}' | tr '\n' ' ')
        echo "apt -s autoremove: ${weg:-nichts}"
        [[ " $weg " != *" querencia-schnatter "* ]] && [[ " $weg " != *" querencia-webhuelle "* ]] &&
            ok "apt autoremove behält Schnatter und das Übergangspaket" || nok "apt autoremove entfernte: $weg"
        apt_s -s remove querencia-webhuelle >"$OUT/apt-remove-uebergang.txt" 2>&1
        apt_s -s -o APT::Get::AutomaticRemove=true remove querencia-webhuelle >"$OUT/apt-remove-uebergang-auto.txt" 2>&1
        if grep -q '^Remv querencia-schnatter' "$OUT/apt-remove-uebergang-auto.txt"; then
            hinweis "apt remove --autoremove querencia-webhuelle nähme das automatisch installierte Schnatter mit; README.Debian rät deshalb zuerst zu apt install querencia-schnatter (manuell markieren)"
        else
            ok "apt remove querencia-webhuelle lässt Schnatter stehen"
        fi
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
ls "$ALT"/querencia-webhuelle_0.2.0-1_*.deb >/dev/null 2>&1 || { echo "$ALT: querencia-webhuelle 0.2.0-1 fehlt" >&2; exit 2; }
ls "$NEU"/querencia-schnatter_*.deb "$NEU"/querencia-webhuelle_0.3.0-1_*.deb >/dev/null 2>&1 || { echo "$NEU: Schnatter oder Übergangspaket fehlt" >&2; exit 2; }
mkdir -p "$OUT"/{alt-installieren,upgrade,upgrade-installieren}
A=$(mktemp -d "${TMPDIR:-/tmp}/querencia-upgrade-schnatter.XXXXXX")
[ -n "${UPGRADE_BEHALTEN-}" ] && echo "Arbeitsordner bleibt: $A" || trap 'chmod -R u+w "$A" 2>/dev/null; rm -rf "${A:?}"' EXIT
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
OHNE=${UPGRADE_OHNE-querencia-anmeldung}
waehle() { local d n; for d in "$1"/*.deb; do n=$(basename "$d"); n=${n%%_*}; [[ " $OHNE " == *" $n "* ]] || echo "$d"; done; }
mapfile -t alt < <(waehle "$ALT")
# Upgrade: nur was sich gegenüber dem alten Satz geändert hat (gleiche Datei =
# schon installiert). Das Übergangspaket zuerst: dpkg -i ordnet nicht um wie
# apt, und querencia-schnatter bricht querencia-webhuelle (<< 0.3.0~); erst
# nach dem Entpacken von querencia-webhuelle 0.3.0-1 ist das erfüllt.
neu=()
for d in "$NEU"/querencia-webhuelle_*.deb "$NEU"/*.deb; do
    [[ " ${neu[*]} " == *" $d "* ]] && continue
    n=$(basename "$d"); [[ " $OHNE " == *" ${n%%_*} "* ]] && continue
    [ -f "$ALT/$n" ] && cmp -s "$ALT/$n" "$d" && continue
    neu+=("$d")
done
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
    huelle --unshare-user --uid 0 --gid 0 bash "$WEGWERF" --innen installieren "$A" "$OUT/alt-installieren" "${attrappen[@]}" "${alt[@]}" </dev/null
    echo "== 2 Probe-Benutzer mit den Ordnern der Webhülle, 3 apt-Simulation"
    huelle bash "$HIER" --innen vorher "$A" "$OUT/upgrade" "$ALT" "$NEU" </dev/null
    echo "== 4 Upgrade: $(basename "$NEU"), geändert: $(printf '%s ' "${neu[@]##*/}")"
    huelle --unshare-user --uid 0 --gid 0 bash "$WEGWERF" --innen installieren "$A" "$OUT/upgrade-installieren" "${neu[@]}" </dev/null
    echo "== 5 Pakete und Ordner nach dem Upgrade, 6 erster Start, 7 autoremove"
    huelle bash "$HIER" --innen nachher "$A" "$OUT/upgrade" "$ALT" "$NEU" </dev/null
} 2>&1 | tee "$OUT/ergebnis.txt"
p=$(grep -c '^PASS' "$OUT/ergebnis.txt") f=$(grep -c '^FAIL' "$OUT/ergebnis.txt") h=$(grep -c '^HINW' "$OUT/ergebnis.txt")
echo "Ergebnis: $p PASS, $f FAIL, $h Hinweise" | tee -a "$OUT/ergebnis.txt"
[ "$f" -eq 0 ]
