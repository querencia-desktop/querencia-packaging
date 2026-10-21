#!/bin/bash
# Lädt eine mit quelle-bauen.sh erzeugte APT-Quelle in den Cloudflare-R2-
# Bucket hinter https://dl.querencialinux.org/ (Pfad /apt/). Veröffentlicht:
# nur der Besitzer führt das ohne --trockenlauf aus.
#
#   bash werkzeuge/apt/quelle-hochladen.sh --fingerabdruck <fpr> [--trockenlauf]
#       [--bucket querencialinux] [--praefix apt]
#       [--basis-url https://dl.querencialinux.org/apt] <repo-ordner>
#
# Ablauf:
#   1 Vorprüfung: InRelease und Release.gpg mit gpgv gegen querencia.gpg der
#     Quelle; der Schlüssel muss den Fingerabdruck --fingerabdruck haben.
#     Jede Indexdatei aus Release stimmt (SHA256).
#   2 Abgleich mit dem Server (HEAD auf --basis-url, nur lesend):
#     Pool- und by-hash-Dateien sind unveränderlich. Liegen sie schon dort
#     (gleiche Größe, bei einfachem ETag gleiche MD5), entfallen sie; eine
#     Pool-Datei mit anderem Inhalt bricht ab.
#   3 Hochladen in dieser Reihenfolge, damit Clients nie einen Index ohne
#     seine Dateien sehen: pool, by-hash, Indexdateien, Schlüssel und
#     Vorlage, Release und Release.gpg, InRelease zuletzt.
#     Je Datei: wrangler r2 object put --remote mit Content-Type und
#     Cache-Control (unveränderliche Dateien ein Jahr, Index no-cache).
#   Gelöscht wird nichts.
# --trockenlauf: Schritte 1 und 2 laufen, die wrangler-Befehle werden nur
# ausgegeben. Danach (nach echtem Hochladen) prüfen mit
#   bash werkzeuge/apt/quelle-pruefen.sh --fingerabdruck <fpr> https://dl.querencialinux.org/apt
set -euo pipefail
export LC_ALL=C.UTF-8

die() { printf 'quelle-hochladen: FEHLER: %s\n' "$*" >&2; exit 1; }
log() { printf 'quelle-hochladen: %s\n' "$*"; }

TROCKEN= FPR_SOLL= BUCKET=querencialinux PRAEFIX=apt BASIS=https://dl.querencialinux.org/apt SUITE=resolute
WRANGLER=${WRANGLER:-npx --no-install wrangler}
while [ $# -gt 0 ]; do
    case $1 in
    --trockenlauf) TROCKEN=1; shift ;;
    --fingerabdruck) FPR_SOLL=${2^^}; FPR_SOLL=${FPR_SOLL// /}; shift 2 ;;
    --bucket) BUCKET=$2; shift 2 ;;
    --praefix) PRAEFIX=${2%/}; shift 2 ;;
    --basis-url) BASIS=${2%/}; shift 2 ;;
    --suite) SUITE=$2; shift 2 ;;
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unbekannte Option $1" ;;
    *) break ;;
    esac
done
[ $# -eq 1 ] && [ -n "$FPR_SOLL" ] ||
    die "Aufruf: $0 --fingerabdruck <fpr> [--trockenlauf] <repo-ordner> (--help)"
REPO=$(readlink -f "$1")
D=$REPO/dists/$SUITE
[ -f "$D/InRelease" ] && [ -f "$D/Release" ] && [ -f "$D/Release.gpg" ] && [ -f "$REPO/querencia.gpg" ] ||
    die "$REPO ist keine vollständige Quelle (dists/$SUITE/InRelease, Release, Release.gpg, querencia.gpg)"
command -v curl >/dev/null || die "curl fehlt"

# ---- 1 Vorprüfung
# Genau ein Hauptschlüssel, und er muss der erwartete sein: gpgv nimmt jeden
# Schlüssel im Keyring an, und hochgeladen würde der ganze Keyring (CLEAN-1 B3).
SCHLUESSEL=$(gpg --batch --no-tty --with-colons --show-keys "$REPO/querencia.gpg" 2>/dev/null)
ANZAHL=$(grep -c '^pub:' <<<"$SCHLUESSEL")
[ "$ANZAHL" = 1 ] || die "querencia.gpg enthält $ANZAHL Hauptschlüssel, erwartet genau einen"
FPR_IST=$(awk -F: '/^pub:/ {p=1; next} p && /^fpr:/ {print $10; exit}' <<<"$SCHLUESSEL")
[ "$FPR_IST" = "$FPR_SOLL" ] || die "querencia.gpg hat $FPR_IST, erwartet $FPR_SOLL"
signierer() { awk '$2 == "VALIDSIG" {print $NF}'; }
INHALT=$(gpgv --quiet --keyring "$REPO/querencia.gpg" --output - "$D/InRelease" 2>/dev/null) || die "InRelease nicht gültig signiert"
[ "$(gpgv --quiet --status-fd 1 --keyring "$REPO/querencia.gpg" --output /dev/null "$D/InRelease" 2>/dev/null | signierer)" = "$FPR_SOLL" ] ||
    die "InRelease nicht von $FPR_SOLL signiert"
[ "$(gpgv --quiet --status-fd 1 --keyring "$REPO/querencia.gpg" "$D/Release.gpg" "$D/Release" 2>/dev/null | signierer)" = "$FPR_SOLL" ] ||
    die "Release.gpg nicht gültig oder nicht von $FPR_SOLL"
[ "$INHALT" = "$(cat "$D/Release")" ] || die "InRelease und Release weichen ab"
while read -r h size f; do
    [ "$(sha256sum <"$D/$f" | cut -d' ' -f1)" = "$h" ] || die "Hash stimmt nicht: dists/$SUITE/$f (neu bauen)"
done < <(awk '/^SHA256:/ {s=1; next} /^[A-Za-z]/ {s=0} s {print $1, $2, $3}' "$D/Release")
log "Vorprüfung PASS: Signatur $FPR_IST, Release-Hashes"

# ---- Dateiliste in Upload-Reihenfolge
cd "$REPO"
{
    find pool -type f -name '*.deb' | sort | sed 's/^/1 /'
    find dists -type f -path '*/by-hash/*' | sort | sed 's/^/2 /'
    find dists -type f ! -path '*/by-hash/*' ! -name InRelease ! -path "dists/$SUITE/Release" ! -path "dists/$SUITE/Release.gpg" |
        sort | sed 's/^/3 /'
    for f in querencia.gpg querencia.asc querencia.sources; do [ -f "$f" ] && echo "4 $f"; done
    echo "5 dists/$SUITE/Release"
    echo "5 dists/$SUITE/Release.gpg"
    echo "6 dists/$SUITE/InRelease"
} >"${TMPDIR:-/tmp}/quelle-hochladen.$$"
trap 'rm -f "${TMPDIR:-/tmp}/quelle-hochladen.$$"' EXIT

art() { # Content-Type und Cache-Control je Datei
    local f=$1 ct cc=no-cache
    case $f in
    *.deb) ct=application/vnd.debian.binary-package ;;
    */by-hash/*) ct=application/octet-stream ;;
    *.gz) ct=application/gzip ;;
    *.xz) ct=application/x-xz ;;
    */Release.gpg) ct=application/pgp-signature ;;
    *.gpg | *.asc) ct=application/pgp-keys ;;
    *) ct='text/plain; charset=utf-8' ;;
    esac
    case $f in pool/* | */by-hash/*) cc='public, max-age=31536000, immutable' ;; esac
    case $f in querencia.gpg | querencia.asc | querencia.sources) cc='public, max-age=3600' ;; esac
    printf '%s\t%s\n' "$ct" "$cc"
}

# ---- 2 Abgleich mit dem Server (HEAD, nur lesend)
kopf() { curl -sS -I --max-time 30 "$BASIS/$1" 2>/dev/null | tr -d '\r' || true; }
hoch=() uebersprungen=0 bytes=0
while read -r stufe f; do
    size=$(stat -c %s "$f")
    [ "$size" -le $((300 * 1024 * 1024)) ] || die "$f ist größer als 300 MiB (Grenze von wrangler r2 object put)"
    if [ "$stufe" -le 2 ]; then
        k=$(kopf "$f")
        status=$(head -1 <<<"$k" | awk '{print $2}')
        case $status in
        200 | 404) ;;
        *) die "$BASIS/$f: keine eindeutige Antwort (${status:-keine}); ohne Abgleich wird nichts hochgeladen" ;;
        esac
        if [ "$status" = 200 ]; then
            rsize=$(sed -n 's/^content-length: //Ip' <<<"$k")
            etag=$(sed -n 's/^etag: "\{0,1\}\([^"]*\)"\{0,1\}$/\1/Ip' <<<"$k")
            gleich=1
            [ "$rsize" = "$size" ] || gleich=
            if [ -n "$etag" ] && [[ $etag != *-* ]]; then
                [ "$etag" = "$(md5sum <"$f" | cut -d' ' -f1)" ] || gleich=
            fi
            if [ -n "$gleich" ]; then uebersprungen=$((uebersprungen + 1)); continue; fi
            [ "$stufe" = 2 ] && die "$f liegt auf dem Server mit anderem Inhalt (by-hash-Name passt nicht zum Inhalt?)"
            die "$f liegt auf dem Server mit anderem Inhalt; veröffentlichte Pool-Dateien sind unveränderlich (neue Version bauen)"
        fi
    fi
    hoch+=("$f")
    bytes=$((bytes + size))
done <"${TMPDIR:-/tmp}/quelle-hochladen.$$"
log "Abgleich: ${#hoch[@]} Dateien hochzuladen ($((bytes / 1024)) KiB), $uebersprungen schon auf dem Server"

# ---- 3 Hochladen
n=0
for f in "${hoch[@]}"; do
    IFS=$'\t' read -r ct cc < <(art "$f")
    cmd=($WRANGLER r2 object put "$BUCKET/$PRAEFIX/$f" --remote --file "$REPO/$f" --content-type "$ct" --cache-control "$cc")
    n=$((n + 1))
    if [ -n "$TROCKEN" ]; then
        printf '[trockenlauf %d/%d]' "$n" "${#hoch[@]}"
        printf ' %q' "${cmd[@]}"
        printf '\n'
    else
        log "$n/${#hoch[@]} $f"
        "${cmd[@]}" >/dev/null || die "Hochladen fehlgeschlagen: $f (bisher hochgeladene Dateien sind konsistent; Lauf wiederholen)"
    fi
done
if [ -n "$TROCKEN" ]; then
    log "Trockenlauf: nichts hochgeladen"
else
    log "fertig: $BASIS/ (Prüfung: bash werkzeuge/apt/quelle-pruefen.sh --fingerabdruck $FPR_SOLL $BASIS)"
fi
