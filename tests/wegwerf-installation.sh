#!/bin/bash
# Installationsprobe ohne zweite VM (G2-F): installiert den Paketsatz mit
# dpkg -i in eine Wegwerf-Wurzel und startet ihn kopflos. Das echte System
# bleibt unverändert:
#   - alles läuft in einer bubblewrap-Hülle: / nur lesbar, beschreibbar ist
#     nur der Arbeitsordner; kein Netz, eigener PID- und IPC-Namensraum;
#     /run/user und /run/dbus sind leer (weder Sitzungs- noch Systembus,
#     keine Wayland-Sitzung erreichbar);
#   - dpkg arbeitet mit --root auf einer Kopie von /var/lib/dpkg (status,
#     info, alternatives): Abhängigkeiten werden gegen die installierten
#     Pakete des Rechners geprüft, Maintainer-Skripte laufen chrootless mit
#     DPKG_ROOT, Trigger werden nicht ausgeführt.
#
#   bash tests/wegwerf-installation.sh <nachweisordner> paket.deb ...
#
# Prüft: 1 dpkg -i ohne Fehler, alle Pakete "install ok installed";
# 2 kein Paket halb installiert (wartende Trigger nur als Hinweis); 3 x-terminal-emulator-Alternative; 4 jedes Programm:
# keine fehlende Bibliothek, Aufruf mit --version/--help ohne Absturz;
# 5 kopflose labwc-Sitzung mit dem Autostart des Pakets querencia-session:
# Panel, Desktop, polkit-Agent, Benachrichtigungen, Leerlaufsperre laufen,
# Bildschirmfoto; 6 jedes Programm aus /usr/share/applications startet in
# dieser Sitzung und läuft 4 s ohne Absturz (Bildschirmfoto je Programm).
# Ergebnis: PASS/FAIL je Prüfung, Exit 1 bei einem FAIL.
set -uo pipefail
HIER=$(readlink -f "$0")

if [ "${1-}" = --innen ]; then
    # ---- läuft in der Hülle: Teil "installieren" mit uid 0 im eigenen
    # Benutzer-Namensraum (dpkg setzt Eigentümer root), Teil "pruefen" als
    # gewöhnlicher Benutzer -------------------------------------------------
    shift
    TEIL=$1 A=$2 OUT=$3; shift 3
    R=$A/wurzel
    pass=0 fail=0
    ok() { pass=$((pass + 1)); echo "PASS $*"; }
    nok() { fail=$((fail + 1)); echo "FAIL $*"; }
    hinweis() { echo "HINW $*"; }
    D() { dpkg --root="$R" --force-not-root "$@"; }

    if [ "$TEIL" = installieren ]; then
    # 1 Installation
    pakete=()
    for deb in "$@"; do pakete+=("$(dpkg-deb -f "$deb" Package)"); done
    if D --force-script-chrootless --no-triggers --log="$OUT/dpkg.log" -i "$@" \
        >"$OUT/dpkg-i.txt" 2>&1; then
        ok "dpkg -i: ${#pakete[@]} Pakete ohne Fehler"
    else
        nok "dpkg -i: $(grep -E 'dpkg: (Fehler|error)|Abhängigkeitsprobleme|dependency problems' "$OUT/dpkg-i.txt" | head -5 | tr '\n' ' ')"
    fi
    for p in "${pakete[@]}"; do
        st=$(D -s "$p" 2>/dev/null | sed -n 's/^Status: //p')
        [ "$st" = "install ok installed" ] && ok "$p: $st" || nok "$p: ${st:-nicht installiert}"
    done
    # 2 Paketdatenbank konsistent. Wartende Trigger sind erwartet (--no-triggers:
    # z. B. hicolor-icon-theme für den Symbol-Cache); jeder andere halbe
    # Zustand (entpackt, halb konfiguriert ...) ist ein Fehler.
    halb=$(dpkg-query --root="$R" -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null |
        awk '$1 !~ /^(ii|iW|it|rc|un|pn)/ { print $2 "(" $1 ")" }' | tr '\n' ' ')
    [ -z "$halb" ] && ok "Paketdatenbank: kein Paket halb installiert" || nok "Paketdatenbank: $halb"
    trig=$(dpkg-query --root="$R" -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null |
        awk '$1 ~ /^i[Wt]/ { print $2 }' | tr '\n' ' ')
    [ -z "$trig" ] || hinweis "Trigger nicht ausgeführt (Probe mit --no-triggers): $trig"
    # 3 Alternative des Terminals (postinst mit update-alternatives)
    if printf '%s\n' "${pakete[@]}" | grep -qx querencia-terminal; then
        alt=$(update-alternatives --root "$R" --query x-terminal-emulator 2>/dev/null | grep -c '^Alternative: /usr/bin/querencia-terminal$')
        [ "$alt" = 1 ] && ok "x-terminal-emulator: querencia-terminal eingetragen" || nok "x-terminal-emulator fehlt"
    fi
    echo "Teil installieren: $pass PASS, $fail FAIL"
    [ $fail -eq 0 ]
    exit
    fi

    # Umgebung der Programme: Dateien aus der Wegwerf-Wurzel, Bibliotheken
    # des Rechners (dieselben Pakete, gegen die dpkg die Abhängigkeiten geprüft hat).
    export HOME=$A/home XDG_CONFIG_HOME=$A/home/.config XDG_DATA_HOME=$A/home/.local/share \
        XDG_STATE_HOME=$A/home/.local/state XDG_CACHE_HOME=$A/home/.cache \
        XDG_DATA_DIRS=$R/usr/share:/usr/share XDG_CONFIG_DIRS=$R/etc/xdg:/etc/xdg \
        PATH=$R/usr/bin:/usr/bin:/bin LANG=de_DE.UTF-8 LANGUAGE=de \
        GSETTINGS_BACKEND=memory NO_AT_BRIDGE=1 GTK_A11Y=none
    mkdir -p "$HOME/.config" "$XDG_STATE_HOME/querencia"

    # 4 Programme: Bibliotheken und Aufruf ohne Sitzung
    for b in "$R"/usr/bin/*; do
        [ -f "$b" ] && [ ! -L "$b" ] || continue   # Alternativen zeigen ins echte System
        n=$(basename "$b")
        head -c 4 "$b" | grep -q ELF || continue
        fehlt=$(ldd "$b" 2>&1 | grep 'not found' | tr '\n' ' ')
        [ -z "$fehlt" ] && ok "$n: alle Bibliotheken gefunden" || { nok "$n: fehlt $fehlt"; continue; }
        out=$(timeout 10 "$b" --version 2>&1); rc=$?
        if [ $rc -ne 0 ] || [ -z "$out" ]; then out=$(timeout 10 "$b" --help 2>&1); rc=$?; fi
        echo "$out" >"$OUT/aufruf-$n.txt"
        if echo "$out" | grep -q -E 'panicked at|Segmentation|core dumped'; then
            nok "$n: Absturz beim Aufruf ($OUT/aufruf-$n.txt)"
        elif [ $rc -eq 0 ]; then
            ok "$n: Aufruf ohne Sitzung: $(echo "$out" | head -n 1 | cut -c1-70)"
        else
            hinweis "$n: Exit $rc ohne Sitzung (GUI braucht Wayland): $(echo "$out" | head -n 1 | cut -c1-70)"
        fi
    done
    if [ -x "$R/usr/bin/querencia-session" ]; then
        out=$(QUERENCIA_SYSCONFDIR=$R/etc QUERENCIA_BINDIR=$R/usr/bin "$R/usr/bin/querencia-session" --check 2>&1); rc=$?
        echo "$out" >"$OUT/session-check.txt"
        [ $rc -eq 0 ] && ok "querencia-session --check (labwc $(echo "$out" | sed -n 's/^labwc: .*(\(.*\))$/\1/p'))" ||
            nok "querencia-session --check: $(echo "$out" | grep -E 'FEHLT|ZU ALT' | tr '\n' ' ')"
    fi

    # 5 kopflose Sitzung: labwc aus dem Paket, Konfiguration und Autostart aus
    # querencia-session, Programme aus der Wegwerf-Wurzel
    [ -x "$R/usr/bin/labwc" ] && [ -d "$R/etc/querencia/labwc" ] || {
        nok "kopflose Sitzung: labwc oder /etc/querencia/labwc fehlt"
        echo "Teil pruefen: $pass PASS, $fail FAIL"; exit 1
    }
    # Kurzer Pfad (Wayland-Socket höchstens 108 Zeichen); /tmp ist in der
    # Hülle ein eigenes tmpfs.
    export XDG_RUNTIME_DIR=/tmp/q-run
    mkdir -p -m 0700 "$XDG_RUNTIME_DIR"
    S=$XDG_STATE_HOME/querencia
    opt() { [ -x "$R/usr/bin/$1" ] && echo "$R/usr/bin/$1"; }
    export QUERENCIA_PANEL=$R/usr/bin/querencia-panel QUERENCIA_DESKTOP=$(opt querencia-desktop) \
        QUERENCIA_STATE_DIR=$S QUERENCIA_PANEL_RECORD=$S/panel.probe.pid QUERENCIA_DESKTOP_RECORD=$S/desktop.probe.pid \
        QUERENCIA_SITZUNG=$(opt querencia-sitzung) QUERENCIA_LEERLAUF_MINUTEN=10 \
        QUERENCIA_POLKIT_AGENT=$(opt querencia-polkit-agent) \
        QUERENCIA_BENACHRICHTIGUNGEN=$(opt querencia-benachrichtigungen) \
        QUERENCIA_EINSTELLUNGEN=$(opt querencia-einstellungen)
    export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1
    dbus-run-session -- sh -c '
        "$1" -C "$2" >"$3/labwc.log" 2>&1 &
        echo $! >"$3/labwc.probe.pid"
        wait' _ "$R/usr/bin/labwc" "$R/etc/querencia/labwc" "$S" &
    sitzung=$!
    for _ in $(seq 1 50); do
        sock=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -n 1)
        [ -n "$sock" ] && break
        sleep 0.2
    done
    if [ -z "$sock" ]; then
        nok "kopflose Sitzung: labwc legt keinen Wayland-Socket an ($S/labwc.log)"
    else
        export WAYLAND_DISPLAY=$sock
        sleep 8
        for p in querencia-panel querencia-desktop querencia-polkit-agent querencia-benachrichtigungen; do
            [ -x "$R/usr/bin/$p" ] || continue
            n=$(pgrep -c -f "^$R/usr/bin/$p( |\$)")
            [ "$n" = 1 ] && ok "Sitzung: $p läuft" || nok "Sitzung: $p läuft nicht ($n Prozesse, $S/*.log)"
        done
        if [ -x "$R/usr/bin/querencia-sitzung" ]; then
            pgrep -f "^$R/usr/bin/querencia-sitzung --leerlauf" >/dev/null &&
                ok "Sitzung: Leerlaufsperre läuft" || nok "Sitzung: Leerlaufsperre läuft nicht"
        fi
        if command -v grim >/dev/null && grim "$OUT/sitzung.png" 2>/dev/null; then
            ok "Sitzung: Bildschirmfoto $OUT/sitzung.png"
        else
            hinweis "Sitzung: kein Bildschirmfoto (grim)"
        fi
        # 6 jedes Programm mit Starter
        for d in "$R"/usr/share/applications/*.desktop; do
            [ -f "$d" ] || continue
            id=$(basename "$d" .desktop)
            cmd=$(sed -n 's/^Exec=//p' "$d" | head -n 1 | sed 's/ *%[UuFf]//g')
            prog=${cmd%% *}
            [ -x "$R/usr/bin/$prog" ] || { nok "$id: Exec $prog nicht im Paketsatz"; continue; }
            # shellcheck disable=SC2086
            (cd "$HOME" && exec $R/usr/bin/$cmd) >"$S/start-$id.log" 2>&1 &
            pid=$!
            sleep 4
            if kill -0 "$pid" 2>/dev/null; then
                grim "$OUT/start-$id.png" 2>/dev/null
                ok "$id: startet und läuft nach 4 s ($prog)"
                kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
            else
                wait "$pid"; rc=$?
                if grep -q -E 'panicked at|Segmentation|core dumped' "$S/start-$id.log"; then
                    nok "$id: Absturz beim Start (Exit $rc, $S/start-$id.log)"
                else
                    hinweis "$id: nach 4 s beendet (Exit $rc), Log $S/start-$id.log"
                fi
            fi
        done
        if grep -q -E 'panicked at' "$S"/*.log 2>/dev/null; then
            nok "Sitzung: Panik in $(grep -l 'panicked at' "$S"/*.log | xargs -n1 basename | tr '\n' ' ')"
        else
            ok "Sitzung: keine Panik in den Logs"
        fi
    fi
    kill "$(cat "$S/labwc.probe.pid" 2>/dev/null)" 2>/dev/null
    sleep 2
    kill "$sitzung" 2>/dev/null
    cp -a "$S" "$OUT/logs" 2>/dev/null
    echo "Teil pruefen: $pass PASS, $fail FAIL"
    [ $fail -eq 0 ]
    exit
fi

# ---- außen: Arbeitsordner anlegen, Hülle starten -----------------------------
[ $# -ge 2 ] || { echo "Aufruf: $0 <nachweisordner> paket.deb ..." >&2; exit 2; }
OUT=$(readlink -f "$1"); shift
debs=()
for deb in "$@"; do debs+=("$(readlink -f "$deb")"); done
mkdir -p "$OUT"
A=$(mktemp -d "${TMPDIR:-/tmp}/querencia-wegwerf.XXXXXX")
trap 'chmod -R u+w "$A" 2>/dev/null; rm -rf "$A"' EXIT
mkdir -p "$A/wurzel/var/lib/dpkg/updates" "$A/wurzel/var/lib/dpkg/triggers" "$A/wurzel/var/log" \
    "$A/wurzel/etc" "$A/home"
cp /var/lib/dpkg/status "$A/wurzel/var/lib/dpkg/status"
cp -a /var/lib/dpkg/info "$A/wurzel/var/lib/dpkg/info"
find /var/lib/dpkg/triggers -maxdepth 1 -type f ! -name Lock -exec cp -a {} "$A/wurzel/var/lib/dpkg/triggers/" \;
cp -a /var/lib/dpkg/alternatives "$A/wurzel/var/lib/dpkg/alternatives" 2>/dev/null || mkdir -p "$A/wurzel/var/lib/dpkg/alternatives"
cp -a /etc/alternatives "$A/wurzel/etc/alternatives"
touch "$A/wurzel/var/lib/dpkg/available"
# Nachweis- und Paketordner nur lesbar bzw. für Ergebnisse beschreibbar.
bind=(--bind "$A" "$A" --bind "$OUT" "$OUT")
for deb in "${debs[@]}"; do bind+=(--ro-bind "$(dirname "$deb")" "$(dirname "$deb")"); done
# Reihenfolge zählt: erst die leeren tmpfs, dann die beschreibbaren Ordner
# (die auch unter /tmp liegen dürfen).
huelle() {
    bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run/user --tmpfs /run/dbus \
        --tmpfs /run/needrestart "${bind[@]}" --unshare-pid --unshare-net --unshare-ipc --die-with-parent \
        --unsetenv WAYLAND_DISPLAY --unsetenv DISPLAY --unsetenv DBUS_SESSION_BUS_ADDRESS \
        --unsetenv XDG_RUNTIME_DIR --unsetenv XDG_SESSION_ID --unsetenv SWAYSOCK --unsetenv LABWC_PID "$@"
}
{
    huelle --unshare-user --uid 0 --gid 0 bash "$HIER" --innen installieren "$A" "$OUT" "${debs[@]}"
    huelle bash "$HIER" --innen pruefen "$A" "$OUT" "${debs[@]}"
} 2>&1 | tee "$OUT/ergebnis.txt"
p=$(grep -c '^PASS' "$OUT/ergebnis.txt") f=$(grep -c '^FAIL' "$OUT/ergebnis.txt") h=$(grep -c '^HINW' "$OUT/ergebnis.txt")
echo "Ergebnis: $p PASS, $f FAIL, $h Hinweise" | tee -a "$OUT/ergebnis.txt"
[ "$f" -eq 0 ]
