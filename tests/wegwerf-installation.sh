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
# dieser Sitzung und läuft 4 s ohne Absturz (Bildschirmfoto je Programm);
# 7 Alpha 2: gtk-dark.css, Symbole 0.7, dunkle Fassung für ein GTK-4- und
# ein GTK-3-Fenster über die Helligkeit der Bildmitte.
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
    D --force-script-chrootless --no-triggers --log="$OUT/dpkg.log" -i "$@" >"$OUT/dpkg-i.txt" 2>&1
    rc=$?
    # Abhängigkeiten außerhalb des Paketsatzes, die dieser Rechner nicht hat:
    # apt holt sie auf der frischen VM aus dem Archiv; dpkg in der Probe kann
    # das nicht (kein Netz). Sie sind nur ein Hinweis, wenn das Archiv sie kennt.
    fehlend=$(sed -n -E 's/^ *[^ ]+ (hängt ab von|depends on) ([^ ;(]+).*/\2/p' "$OUT/dpkg-i.txt" | sort -u)
    archiv=() kaputt=()
    for x in $fehlend; do
        if printf '%s\n' "${pakete[@]}" | grep -qx "$x"; then kaputt+=("$x (im Paketsatz)")
        elif apt-cache show "$x" >/dev/null 2>&1; then archiv+=("$x")
        else kaputt+=("$x (unbekannt)"); fi
    done
    [ ${#archiv[@]} -eq 0 ] || hinweis "aus dem Ubuntu-Archiv nachzuinstallieren (apt auf der VM): ${archiv[*]}"
    if [ $rc -eq 0 ]; then ok "dpkg -i: ${#pakete[@]} Pakete ohne Fehler"
    elif [ ${#kaputt[@]} -eq 0 ] && ! grep -q -E 'Fehler beim (Entpacken|Bearbeiten des Archivs)|trying to overwrite|versucht .* zu überschreiben' "$OUT/dpkg-i.txt"; then
        ok "dpkg -i: alle Pakete entpackt; offen nur Abhängigkeiten aus dem Archiv"
    else
        nok "dpkg -i: ${kaputt[*]} $(grep -E 'dpkg: (Fehler|error)' "$OUT/dpkg-i.txt" | head -3 | tr '\n' ' ')"
    fi
    nur_archiv() { # Paket $1 wartet nur auf Archiv-Abhängigkeiten
        [ ${#kaputt[@]} -eq 0 ] && grep -q "Konfiguration von $1:" "$OUT/dpkg-i.txt"
    }
    for p in "${pakete[@]}"; do
        st=$(D -s "$p" 2>/dev/null | sed -n 's/^Status: //p')
        if [ "$st" = "install ok installed" ]; then ok "$p: $st"
        # --no-triggers: z. B. das gschema-Override von querencia-session wartet
        # auf den Trigger von libglib2.0 (Prüfpunkt 2 meldet ihn als Hinweis)
        elif [ "$st" = "install ok triggers-awaited" ] || [ "$st" = "install ok triggers-pending" ]; then ok "$p: $st (Probe ohne Trigger)"
        elif [ "$st" = "install ok unpacked" ] && nur_archiv "$p"; then hinweis "$p: entpackt, Konfiguration wartet auf Archiv-Abhängigkeiten"
        else nok "$p: ${st:-nicht installiert}"; fi
    done
    # 2 Paketdatenbank konsistent. Wartende Trigger sind erwartet (--no-triggers:
    # z. B. hicolor-icon-theme für den Symbol-Cache); jeder andere halbe
    # Zustand (entpackt, halb konfiguriert ...) ist ein Fehler.
    halb=$(dpkg-query --root="$R" -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null |
        awk '$1 !~ /^(ii|iW|it|rc|un|pn)/ { print $2 }' | while read -r x; do
            nur_archiv "$x" || printf '%s ' "$x"; done)
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
    # Privater Sitzungsbus ohne AppArmor-Abfrage (/sys ist in der Hülle nur
    # lesbar; dbus-daemon verweigert sonst jede Namensübernahme).
    cat >/tmp/q-bus.conf <<'BUS'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <apparmor mode="disabled"/>
  <standard_session_servicedirs/>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
BUS
    dbus-run-session --config-file=/tmp/q-bus.conf -- sh -c '
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
            if [ $p = querencia-polkit-agent ] && grep -q 'System-D-Bus nicht erreichbar' "$S/polkit-agent.log" 2>/dev/null; then
                hinweis "Sitzung: polkit-Agent gestartet, beendet sich ohne System-Bus (in der Hülle absichtlich verborgen; Prüfung auf der VM)"
                continue
            fi
            if [ $p = querencia-panel ] && [ "$(pgrep -c -f "^$R/usr/bin/$p --ueberwacht\$")" = 1 ]; then
                # Panel unter seiner Überwachung (Autostart ab querencia-session
                # 0.1.0~alpha7-3): Wachhund "--ueberwacht" plus genau ein Kind
                # ohne Argumente; ein abgestürztes Kind startet er neu.
                kind=$(pgrep -f "^$R/usr/bin/$p\$")
                if [ "$(printf '%s\n' $kind | grep -c .)" = 1 ]; then
                    ok "Sitzung: $p läuft unter Überwachung (Wachhund und ein Panel)"
                    ps -o pid,ppid,stat,args -C querencia-panel >"$OUT/panel-ueberwacht-vorher.txt" 2>&1
                    # zweimal: Rusts Laufzeit fängt das erste, von außen geschickte
                    # SIGSEGV ab (Stapelüberlauf-Erkennung) und setzt nur zurück
                    # (querencia-runtime docs/panel-023-absturz-und-ueberwachung.md)
                    kill -SEGV "$kind" 2>>"$OUT/panel-ueberwacht-vorher.txt"; sleep 0.5
                    kill -SEGV "$kind" 2>>"$OUT/panel-ueberwacht-vorher.txt"; sleep 4
                    neu=$(pgrep -f "^$R/usr/bin/$p\$")
                    ps -o pid,ppid,stat,args -C querencia-panel >"$OUT/panel-ueberwacht-nachher.txt" 2>&1
                    cp "$S/panel.log" "$OUT/panel-ueberwacht.log" 2>/dev/null
                    [ -n "$neu" ] && [ "$neu" != "$kind" ] && [ "$(printf '%s\n' $neu | grep -c .)" = 1 ] &&
                        ok "Sitzung: Panel nach SIGSEGV neu gestartet (PID $kind → $neu)" ||
                        nok "Sitzung: Panel nach SIGSEGV nicht neu gestartet (vorher $kind, nachher ${neu:-keins}, $S/panel.log)"
                else
                    nok "Sitzung: $p unter Überwachung, aber $(printf '%s\n' $kind | grep -c .) Panel-Prozesse ($S/panel.log)"
                fi
                continue
            fi
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
        # 7 Alpha 2: dunkle Fassung des Themas, Symbole 0.7, dunkle Darstellung
        # für ein GTK-4- und ein GTK-3-Fenster (color-scheme über das Portal
        # prüft frisches-ubuntu-pruefen.sh sitzung auf der VM)
        T=$R/usr/share/themes/Querencia-Klassisch Q=$R/usr/share/icons/Querencia
        if [ -d "$T" ]; then
            [ -f "$T/gtk-3.0/gtk-dark.css" ] && [ -f "$T/gtk-4.0/gtk-dark.css" ] &&
                ok "A2 Thema mit gtk-dark.css (GTK 3, 4)" || nok "A2 gtk-dark.css fehlt"
        fi
        if [ -d "$Q" ]; then
            fehlt=
            for n in places/user-desktop places/user-desktop-symbolic places/show-desktop places/show-desktop-symbolic \
                apps/org.querencia.Archiv apps/org.querencia.Software apps/org.querencia.Dateisuche \
                apps/org.querencia.Rechner apps/org.querencia.Kuerzel; do
                [ -f "$Q/scalable/$n.svg" ] || fehlt="$fehlt $n"
            done
            [ -z "$fehlt" ] && ok "A2 Symbole 0.7: Arbeitsfläche anzeigen und fünf Programmsymbole im Thema" || nok "A2 Symbole fehlen:$fehlt"
        fi
        if [ -d "$T" ] && command -v grim >/dev/null && command -v gtk4-builder-tool >/dev/null && command -v gtk-builder-tool >/dev/null; then
            printf '%s\n' '<interface><object class="GtkWindow"><property name="maximized">1</property><property name="title">A2 GTK 4</property>' \
                '<child><object class="GtkLabel"><property name="label">Querencia</property></object></child></object></interface>' >/tmp/q-gtk4.ui
            printf '%s\n' '<interface><object class="GtkWindow"><property name="default-width">1920</property><property name="default-height">1080</property><property name="title">A2 GTK 3</property>' \
                '<child><object class="GtkLabel"><property name="label">Querencia</property><property name="visible">1</property></object></child></object></interface>' >/tmp/q-gtk3.ui
            hell() { # mittlere Helligkeit (0–255) der Bildmitte eines PPM
                python3 -I -c 'import sys
d=open(sys.argv[1],"rb").read(); t=d.split(maxsplit=4); w,h=int(t[1]),int(t[2]); px=t[4]
s=n=0
for y in range(h//3,2*h//3,4):
    for x in range(w//3,2*w//3,4):
        i=3*(y*w+x); s+=0.2126*px[i]+0.7152*px[i+1]+0.0722*px[i+2]; n+=1
print(int(s/n))' "$1"; }
            # Dunkel über die Toolkit-Einstellung (settings.ini): GTK 4
            # gtk-interface-color-scheme=dark und gtk-application-prefer-dark-theme
            # (was Portal/color-scheme in der Sitzung setzen), GTK 3 gtk-application-prefer-dark-theme (GTK 3
            # wertet color-scheme nicht aus); Thema Querencia-Klassisch.
            for tk in gtk4 gtk3; do
                werte=
                for modus in hell dunkel; do
                    # nur settings.ini: gtk-3.0/bookmarks im Probe-Home bleibt
                    # (Lesezeichen-Probe in tests/wegwerf-upgrade.sh)
                    rm -f "$XDG_CONFIG_HOME/gtk-4.0/settings.ini" "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
                    if [ $tk = gtk4 ]; then
                        tool=gtk4-builder-tool d=$XDG_CONFIG_HOME/gtk-4.0 k=gtk-interface-color-scheme v="dark\ngtk-application-prefer-dark-theme=1"
                    else
                        tool=gtk-builder-tool d=$XDG_CONFIG_HOME/gtk-3.0 k=gtk-application-prefer-dark-theme v=1
                    fi
                    mkdir -p "$d"
                    { echo "[Settings]"; echo "gtk-theme-name=Querencia-Klassisch"; [ $modus = dunkel ] && printf "%b\n" "$k=$v"; } >"$d/settings.ini"
                    GDK_DEBUG=no-portals $tool preview /tmp/q-$tk.ui >"$S/a2-$tk-$modus.log" 2>&1 &
                    pid=$!
                    sleep 3
                    grim -t ppm "/tmp/q-$tk-$modus.ppm" 2>/dev/null && grim "$OUT/a2-$tk-$modus.png" 2>/dev/null
                    kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
                    werte="$werte $(hell "/tmp/q-$tk-$modus.ppm" 2>/dev/null || echo ?)"
                done
                set -- $werte
                if [ "$1" != "?" ] && [ "$2" != "?" ] && [ "$1" -ge 150 ] && [ "$2" -le 100 ]; then
                    ok "A2 Dunkle Fassung $tk: hell → Helligkeit $1, dunkel → $2 ($OUT/a2-$tk-*.png)"
                else
                    nok "A2 Dunkle Fassung $tk: hell $1, dunkel $2 (erwartet ≥150 / ≤100; $OUT/a2-$tk-*.png)"
                fi
            done
            rm -f "$XDG_CONFIG_HOME/gtk-4.0/settings.ini" "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
        else
            hinweis "A2 Dunkelmodus nicht geprüft (Thema, grim, gtk4-builder-tool oder gtk-builder-tool fehlt)"
        fi
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
    "$A/wurzel/etc" "$A/home" "$A/tmp"
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
# /run/needrestart gibt es nur, solange needrestart seit dem Boot lief
# (tmpfs); bwrap kann den Ordner im schreibgeschützten / nicht anlegen.
leer=(--tmpfs /run/user --tmpfs /run/dbus)
[ -d /run/needrestart ] && leer+=(--tmpfs /run/needrestart)
huelle() {
    bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp "${leer[@]}" \
        "${bind[@]}" --unshare-pid --unshare-net --unshare-ipc --die-with-parent \
        --unsetenv WAYLAND_DISPLAY --unsetenv DISPLAY --unsetenv DBUS_SESSION_BUS_ADDRESS \
        --unsetenv XDG_RUNTIME_DIR --unsetenv XDG_SESSION_ID --unsetenv SWAYSOCK --unsetenv LABWC_PID \
        --setenv TMPDIR "$A/tmp" "$@"
}
{
    huelle --unshare-user --uid 0 --gid 0 bash "$HIER" --innen installieren "$A" "$OUT" "${debs[@]}"
    huelle bash "$HIER" --innen pruefen "$A" "$OUT" "${debs[@]}"
} 2>&1 | tee "$OUT/ergebnis.txt"
p=$(grep -c '^PASS' "$OUT/ergebnis.txt") f=$(grep -c '^FAIL' "$OUT/ergebnis.txt") h=$(grep -c '^HINW' "$OUT/ergebnis.txt")
echo "Ergebnis: $p PASS, $f FAIL, $h Hinweise" | tee -a "$OUT/ergebnis.txt"
[ "$f" -eq 0 ]
