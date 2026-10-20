#!/bin/bash
# Baut den ganzen Paketsatz aus quellen.conf: Upstream-Archive, Pakete,
# Sammelordner $AUSGABE/debs mit SHA256SUMS. Jeder Bau läuft über
# werkzeuge/paket-bauen.sh (Build-Lock, nice, $QUERENCIA_JOBS Cargo-Jobs).
#
#   bash werkzeuge/alle-bauen.sh [<quellpaket>...]     (ohne Angabe: alle)
#
# Umgebung wie paket-bauen.sh, dazu:
#   QUERENCIA_FREMDRUST_BIN   Toolchain für querencia-files (rustc >= 1.98,
#                             Ubuntu 26.04 hat 1.93); Standard: rustup 1.98.1
#   QUERENCIA_LABWC_PROFILE   Bauprofile für labwc (Standard: keine, also mit
#                             Manpages und SVG-Knöpfen; ohne scdoc bzw.
#                             librsvg2-dev automatisch nodoc bzw. pkg.labwc.nosvg)
#   QUERENCIA_NUR_BAUEN=1     Archive nicht neu erzeugen
# Ergebnis je Paket: PASS/FAIL in $AUSGABE/bau-ergebnis.txt; Exit 1 bei einem FAIL.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/gemeinsam.sh"
W=$PK/werkzeuge
FREMDRUST=${QUERENCIA_FREMDRUST_BIN:-$HOME/.rustup/toolchains/1.98.1-x86_64-unknown-linux-gnu/bin}
if [ -z "${QUERENCIA_LABWC_PROFILE+x}" ]; then
    LABWC_PROFILE=
    command -v scdoc >/dev/null || LABWC_PROFILE="nodoc"
    pkg-config --exists librsvg-2.0 2>/dev/null || LABWC_PROFILE="${LABWC_PROFILE:+$LABWC_PROFILE }pkg.labwc.nosvg"
else
    LABWC_PROFILE=$QUERENCIA_LABWC_PROFILE
fi

if [ $# -gt 0 ]; then
    pakete=("$@")
else
    mapfile -t pakete < <(awk '!/^#/ && NF { print $1 }' "$PK/quellen.conf")
fi
mkdir -p "$AUSGABE/debs" "$NACHWEIS/logs"
ERG=$AUSGABE/bau-ergebnis.txt
fehler=0
for p in "${pakete[@]}"; do
    start=$(date +%s)
    if [ -z "${QUERENCIA_NUR_BAUEN:-}" ]; then
        if ! bash "$W/orig-erzeugen.sh" "$p" >"$NACHWEIS/logs/orig-$p.log" 2>&1; then
            echo "FAIL $p (orig-erzeugen, $NACHWEIS/logs/orig-$p.log)" | tee -a "$ERG"
            fehler=1; continue
        fi
    fi
    case $p in
    querencia-files)
        ok=$(DEB_BUILD_PROFILES=pkg.querencia.fremdrust QUERENCIA_RUST_BIN=$FREMDRUST \
            bash "$W/paket-bauen.sh" "$p" 2>&1) ;;
    labwc)
        ok=$(DEB_BUILD_PROFILES="$LABWC_PROFILE" bash "$W/paket-bauen.sh" "$p" 2>&1) ;;
    *)
        ok=$(bash "$W/paket-bauen.sh" "$p" 2>&1) ;;
    esac
    rc=$?
    dauer=$(( $(date +%s) - start ))
    if [ $rc -eq 0 ]; then
        cp "$AUSGABE/bau/$p"/*.deb "$AUSGABE/debs/"
        echo "PASS $p (${dauer}s)" | tee -a "$ERG"
    else
        echo "$ok" | tail -20 >&2
        echo "FAIL $p (${dauer}s, $NACHWEIS/logs/bau-$p.log)" | tee -a "$ERG"
        fehler=1
    fi
done
(cd "$AUSGABE/debs" && sha256sum -- *.deb >SHA256SUMS)
exit $fehler
