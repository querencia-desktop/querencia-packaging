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
    hits=$(grep -r -l -a -E '/home/[a-z]|/projects/querencia|claude-w5|pakete/bau|/target/(debug|release)|\.cargo/registry' "$R" 2>/dev/null | sed "s|^$R||")
    [ -z "$hits" ] && ok "$p: keine Entwicklerpfade" || nok "$p: Entwicklerpfade in: $hits"

    # md5sums vollständig
    (cd "$R" && md5sum --quiet -c "$C/md5sums" >/dev/null 2>&1) && ok "$p: md5sums stimmen" || nok "$p: md5sums"

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
