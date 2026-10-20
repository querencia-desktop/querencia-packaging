#!/bin/bash
# Prüft gebaute .deb-Dateien, ohne etwas zu installieren (Installationstests
# A–G, N und P aus docs/TESTING.md, soweit sie statisch prüfbar sind):
#
#   bash werkzeuge/pakete-pruefen.sh <paket.deb>…
#
#   - Inhalt: nur /usr, /etc (Conffiles); nichts unter /usr/local, /home, /root,
#     /var, /opt; keine Maintainer-Skripte außer erlaubten
#   - Binaries und Skripte ohne Entwicklerpfade (/home/…, target/, Build-Pfad)
#   - Desktop-Dateien gültig (desktop-file-validate), Exec/TryExec im Paketsatz,
#     Symbole in einem installierten Symbolthema vorhanden
#   - Wayland-Sitzungsdatei gültig, Starter im Paketsatz
#   - Regel M (SW-5): jedes Querencia-Paket liefert mindestens eine gültige
#     MetaInfo-Datei unter /usr/share/metainfo (appstreamcli validate --no-net
#     ohne Fehler/Warnung), Dateiname = Komponenten-ID, <pkgname> = Paket,
#     ein launchable desktop-id liegt im Paketsatz. Ausnahmen (Metapaket,
#     Sitzungsstarter, Backports) in QUERENCIA_METAINFO_AUSNAHMEN.
#   - keine Datei in zwei Paketen des Satzes (G2-F)
#   - Abhängigkeiten: apt-get --simulate gegen das laufende System
#     (schreibt nichts, braucht kein root)
# Ausgabe: PASS/FAIL je Prüfung, Exit 1 bei einem FAIL.
set -uo pipefail
[ $# -ge 1 ] || { echo "Aufruf: $0 <paket.deb>…" >&2; exit 2; }
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
pass=0 fail=0 warn=0
ok() { pass=$((pass + 1)); echo "PASS $*"; }
nok() { fail=$((fail + 1)); echo "FAIL $*"; }
hinweis() { warn=$((warn + 1)); echo "HINW $*"; }

ALLOWED_SCRIPTS='^(postinst|prerm)$'   # nur update-alternatives (querencia-terminal)
debs=()
for deb in "$@"; do debs+=("$(readlink -f "$deb")"); done

# Alle Pakete auspacken: Gesamtbaum für Exec-/Symbolprüfungen.
mkdir -p "$T/alle"
for deb in "${debs[@]}"; do
    p=$(dpkg-deb -f "$deb" Package)
    mkdir -p "$T/$p/root" "$T/$p/ctl"
    dpkg-deb -x "$deb" "$T/$p/root"
    dpkg-deb -e "$deb" "$T/$p/ctl"
    cp -a "$T/$p/root/." "$T/alle/"
done

# Keine Datei in zwei Paketen des Satzes (dpkg würde die Installation des
# zweiten abbrechen, solange kein Replaces/Breaks die Übergabe regelt).
for deb in "${debs[@]}"; do
    p=$(dpkg-deb -f "$deb" Package)
    (cd "$T/$p/root" && find . ! -type d -printf '%P\n') | sed "s|^|$p /|"
done | sort -k2 >"$T/dateien.txt"
doppelt=$(awk '{n[$2]++; w[$2]=w[$2] " " $1} END {for (f in n) if (n[f] > 1) print f ":" w[f]}' "$T/dateien.txt" | sort)
[ -z "$doppelt" ] && ok "Paketsatz: keine Datei in zwei Paketen" ||
    nok "Paketsatz: Dateien in mehreren Paketen: $(echo "$doppelt" | tr '\n' ' ')"

for deb in "${debs[@]}"; do
    p=$(dpkg-deb -f "$deb" Package)
    v=$(dpkg-deb -f "$deb" Version)
    R=$T/$p/root C=$T/$p/ctl
    echo "== $p $v ($(basename "$deb"))"

    bad=$(cd "$R" && find . -mindepth 1 \( -path ./usr -o -path './usr/*' -o -path ./etc -o -path './etc/*' \) -prune -o -print)
    [ -z "$bad" ] && ok "$p: nur /usr und /etc" || nok "$p: Dateien außerhalb /usr, /etc: $bad"
    [ ! -e "$R/usr/local" ] && ok "$p: nichts unter /usr/local" || nok "$p: /usr/local"

    if [ -d "$R/etc" ]; then
        want=$(cd "$R" && find etc -type f | sed 's|^|/|' | sort)
        have=$(sort "$C/conffiles" 2>/dev/null)
        [ "$want" = "$have" ] && ok "$p: alle Dateien in /etc sind Conffiles" || nok "$p: conffiles passt nicht"
    fi

    scripts=$(cd "$C" && ls | grep -v -E '^(control|md5sums|conffiles|shlibs|triggers)$' || true)
    for s in $scripts; do
        if [[ $s =~ $ALLOWED_SCRIPTS ]] && ! grep -q -E 'HOME|~/|/home/|systemctl|greetd|pam' "$C/$s"; then
            ok "$p: Maintainer-Skript $s berührt weder Home noch Dienste"
        else
            nok "$p: Maintainer-Skript $s"
        fi
    done
    [ -z "$scripts" ] && ok "$p: keine Maintainer-Skripte"

    # Entwicklerpfade in allen Dateien (auch in Binaries)
    # absolute Entwicklerpfade; relative "./target/…" aus -ffile-prefix-map und
    # Glob-Muster wie "!**/.cargo/registry/" (Suchausschlüsse in Querencia Files)
    # verraten keinen Rechner und zählen nicht
    # /home/<name>/<ordner> statt /home/[a-z]: Rust legt String-Literale ohne
    # Trenner hintereinander ("/home" "/root" ergibt "/home/root/...").
    hits=$(grep -r -l -a -E '/home/[a-z][a-z0-9_-]*/(projects|opt|src|\.cargo|\.rustup|\.local)/|/projects/querencia|claude-w5|pakete/bau|build/bau/|[^.!*]/target/(debug|release)/|/\.cargo/registry/src' "$R" 2>/dev/null | sed "s|^$R||")
    [ -z "$hits" ] && ok "$p: keine Entwicklerpfade" || nok "$p: Entwicklerpfade in: $hits"

    # md5sums vollständig
    (cd "$R" && md5sum --quiet -c "$C/md5sums" >/dev/null 2>&1) && ok "$p: md5sums stimmen" || nok "$p: md5sums"

    # GTK 4.22 + xdg-toplevel-icon: Liegt ein Symbol sowohl in hicolor/48x48 als
    # auch in einem Scalable-Verzeichnis (scalable, 256x256, 512x512), zeichnet
    # GTK zwei 48-px-Puffer derselben Textur, gibt einen sofort frei und beim
    # Schließen eines Dialogs erneut -> SIGSEGV (Bericht
    # querencia-gtk-symbolabsturz-pruefung.md). Solche Symbole sind verboten.
    icondir=$R/usr/share/icons/hicolor
    if [ -d "$icondir" ]; then
        for f in "$icondir"/48x48/apps/*; do
            [ -e "$f" ] || continue
            n=$(basename "${f%.*}")
            dup=$(ls "$icondir"/{scalable,256x256,512x512}/apps/"$n".* 2>/dev/null | sed "s|^$R||" | tr '\n' ' ')
            [ -z "$dup" ] && ok "$p: Symbol $n ohne doppelte 48er-Stufe" ||
                nok "$p: Symbol $n in 48x48 und in $dup – GTK-4.22-Absturz bei Fenstersymbolen; Scalable-Variante oder 48er weglassen"
        done
    fi

    # Desktop-Dateien
    for d in "$R"/usr/share/applications/*.desktop "$R"/usr/share/wayland-sessions/*.desktop; do
        [ -f "$d" ] || continue
        name=${d#"$R"}
        out=$(desktop-file-validate "$d" 2>&1 | grep -v 'key "DesktopNames"' | grep -v '^.*: hint:')
        [ -z "$out" ] && ok "$p: $name gültig" || nok "$p: $name: $out"
        for key in Exec TryExec; do
            cmd=$(sed -n "s/^$key=//p" "$d" | head -n 1 | awk '{print $1}')
            [ -n "$cmd" ] || continue
            case $cmd in /*) path=$cmd ;; *) path=/usr/bin/$cmd ;; esac
            [ -x "$T/alle$path" ] && ok "$p: $name $key=$cmd im Paketsatz" ||
                nok "$p: $name $key=$cmd nicht im Paketsatz"
        done
        icon=$(sed -n 's/^Icon=//p' "$d" | head -n 1)
        if [ -n "$icon" ]; then
            if find /usr/share/icons "$T/alle/usr/share/icons" -name "$icon.*" 2>/dev/null | grep -q .; then
                ok "$p: Symbol $icon vorhanden"
            else
                hinweis "$p: Symbol $icon in keinem hier installierten Thema"
            fi
        fi
    done
    # Regel M (SW-5, Querencia Software): Ohne MetaInfo-Datei ist ein
    # Querencia-Programm im eigenen Installer unsichtbar (G2-I 5.5, 06 §3).
    case " ${QUERENCIA_METAINFO_AUSNAHMEN:-querencia-desktop querencia-session querencia-symbole labwc} " in
    *" $p "*) hinweis "$p: ohne MetaInfo-Pflicht (Ausnahme: Metapaket/Sitzungsstarter/Symbole/Backport)" ;;
    *)
        case $p in
        querencia-*)
            mis=$(ls "$R"/usr/share/metainfo/*.metainfo.xml 2>/dev/null)
            if [ -z "$mis" ]; then
                nok "$p: keine MetaInfo-Datei unter /usr/share/metainfo (Regel M)"
            fi
            for m in $mis; do
                mname=${m#"$R"}
                mid=$(sed -n 's|^ *<id>\(.*\)</id>.*|\1|p' "$m" | head -n 1)
                [ "$(basename "$m")" = "$mid.metainfo.xml" ] && ok "$p: $mname Dateiname = ID" ||
                    nok "$p: $mname passt nicht zur ID $mid"
                if command -v appstreamcli >/dev/null; then
                    mout=$(appstreamcli validate --no-net "$m" 2>&1)
                    if [ $? -eq 0 ] && ! echo "$mout" | grep -q -E '^(E|W): '; then ok "$p: $mname gültig (appstreamcli)"
                    else nok "$p: $mname: $(echo "$mout" | grep -E '^(E|W): ' | tr '\n' ' ')"; fi
                else
                    hinweis "$p: appstreamcli fehlt, $mname nicht validiert"
                fi
                mpkg=$(sed -n 's|^ *<pkgname>\(.*\)</pkgname>.*|\1|p' "$m" | head -n 1)
                [ "$mpkg" = "$p" ] && ok "$p: $mname pkgname = $p" || nok "$p: $mname pkgname „$mpkg“ ≠ $p"
                ml=$(sed -n 's|^ *<launchable type="desktop-id">\(.*\)</launchable>.*|\1|p' "$m" | head -n 1)
                if [ -n "$ml" ]; then
                    [ -f "$T/alle/usr/share/applications/$ml" ] && ok "$p: $mname launchable $ml im Paketsatz" ||
                        nok "$p: $mname launchable $ml nicht im Paketsatz"
                fi
            done
            ;;
        esac
        ;;
    esac
done

# Abhängigkeiten gegen das laufende System (nur Simulation).
echo "== apt-get --simulate (Paketsatz: ${#debs[@]})"
sim=$(LC_ALL=C apt-get --simulate -o Debug::NoLocking=1 install "${debs[@]}" 2>&1)
rc=$?
echo "$sim" >"$T/sim.txt"
if [ $rc -eq 0 ] && ! grep -q -E '^E:|unmet dependencies|Unmet' "$T/sim.txt"; then
    ok "Abhängigkeiten auflösbar"
    grep -E '^Inst ' "$T/sim.txt" | sed 's/^/     /'
else
    nok "Abhängigkeiten nicht auflösbar"
    grep -E 'Depends|E:|broken' "$T/sim.txt" | sed 's/^/     /' | head -20
fi
echo "Ergebnis: $pass PASS, $fail FAIL, $warn Hinweise"
[ $fail -eq 0 ]
