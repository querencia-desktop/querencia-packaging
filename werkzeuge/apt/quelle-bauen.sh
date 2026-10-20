#!/bin/bash
# Baut aus einem Satz .deb eine vollständige, signierte APT-Quelle als
# statisches Verzeichnis (Inhalt von https://dl.querencialinux.org/apt/).
#
#   bash werkzeuge/apt/quelle-bauen.sh --ziel <repo-ordner> \
#       --gnupghome <gpg-ordner> --schluessel <fingerabdruck> \
#       [--passphrase-datei <datei>] [--suite resolute] [--komponente main] \
#       [--gueltig-tage <n>] <deb-ordner | paket.deb ...>
#
# Ergebnis im Zielordner:
#   pool/main/<anfang>/<quellpaket>/<paket>_<version>_<arch>.deb
#   dists/<suite>/main/binary-{amd64,all}/Packages{,.gz,.xz}
#   dists/<suite>/main/Contents-{amd64,all}{,.gz}
#   dists/<suite>/main/**/by-hash/SHA256/<hash>   (Acquire-By-Hash)
#   dists/<suite>/Release, InRelease, Release.gpg
#   querencia.gpg, querencia.asc   (öffentlicher Schlüssel)
#   querencia.sources              (Deb822-Vorlage für Clients)
#
# Regeln:
#   - Der Index enthält genau den übergebenen Satz. Pakete früherer Läufe
#     bleiben im Pool liegen (Clients mit älterem Index finden sie noch),
#     werden aber gemeldet. Eine Pool-Datei wird nie mit anderem Inhalt
#     überschrieben: eine veröffentlichte Version ist unveränderlich.
#   - Idempotent: Ergibt der Satz denselben Index wie im Zielordner, bleiben
#     Release, InRelease und Release.gpg unverändert (gleiches Datum, gleiche
#     Signatur). Sonst gilt als Datum SOURCE_DATE_EPOCH oder die jetzige Zeit;
#     es muss später als das vorhandene Datum liegen (apt lehnt ältere ab).
#   - Kein Valid-Until (die Quelle wird von Hand signiert; ein Ablauf würde
#     Clients ohne Neusignatur aussperren). --gueltig-tage setzt eines.
#   - Signatur mit gpg --batch und --pinentry-mode loopback, nie ein
#     Agent-Dialog. Passphrase aus --passphrase-datei, sonst (nur an einem
#     Terminal) einmal abgefragt; ein ungeschützter Schlüssel braucht keine.
#   - Dateirechte 0644/0755, Zeitstempel = Datum der Release-Datei.
#   - Nutzt reprepro oder aptly nicht (auf dem Baurechner nicht installiert);
#     Packages kommt von dpkg-scanpackages, Contents und Release von diesem
#     Skript. Ist apt-ftparchive vorhanden, wird es nicht gebraucht.
# Installiert nichts, braucht kein root, schreibt nur in den Zielordner.
set -euo pipefail
export LC_ALL=C.UTF-8 TZ=UTC
umask 022

die() { printf 'quelle-bauen: FEHLER: %s\n' "$*" >&2; exit 1; }
log() { printf 'quelle-bauen: %s\n' "$*"; }

ZIEL= GHOME= KEY= PWDATEI= SUITE=resolute KOMP=main GUELTIG=
ARCHS=(amd64 all)
while [ $# -gt 0 ]; do
    case $1 in
    --ziel) ZIEL=$2; shift 2 ;;
    --gnupghome) GHOME=$2; shift 2 ;;
    --schluessel) KEY=$2; shift 2 ;;
    --passphrase-datei) PWDATEI=$2; shift 2 ;;
    --suite) SUITE=$2; shift 2 ;;
    --komponente) KOMP=$2; shift 2 ;;
    --gueltig-tage) GUELTIG=$2; shift 2 ;;
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) die "unbekannte Option $1" ;;
    *) break ;;
    esac
done
[ -n "$ZIEL" ] && [ -n "$GHOME" ] && [ -n "$KEY" ] && [ $# -ge 1 ] ||
    die "Aufruf: $0 --ziel <ordner> --gnupghome <ordner> --schluessel <fingerabdruck> <deb-ordner | paket.deb ...> (--help)"
[ -z "$GUELTIG" ] || [[ $GUELTIG =~ ^[0-9]+$ ]] || die "--gueltig-tage braucht eine Zahl"
[ -z "$PWDATEI" ] || [ -r "$PWDATEI" ] || die "Passphrase-Datei nicht lesbar: $PWDATEI"
for t in dpkg-deb dpkg-scanpackages gpg gpgv gzip xz sha256sum flock; do
    command -v "$t" >/dev/null || die "$t fehlt"
done
for t in reprepro aptly; do
    command -v "$t" >/dev/null && log "Hinweis: $t ist installiert, wird aber nicht benutzt (ein Weg für alle Rechner)"
done

# ---- Eingabe: Ordner (mit SHA256SUMS, falls vorhanden) oder einzelne .deb
DEBS=()
for a in "$@"; do
    if [ -d "$a" ]; then
        if [ -f "$a/SHA256SUMS" ]; then
            (cd "$a" && sha256sum --quiet -c SHA256SUMS) || die "SHA256SUMS in $a stimmt nicht"
            log "SHA256SUMS in $a geprüft"
        fi
        while IFS= read -r -d '' f; do DEBS+=("$(readlink -f "$f")"); done \
            < <(find "$a" -maxdepth 1 -name '*.deb' -type f -print0 | sort -z)
    elif [ -f "$a" ]; then
        DEBS+=("$(readlink -f "$a")")
    else
        die "nicht gefunden: $a"
    fi
done
[ ${#DEBS[@]} -ge 1 ] || die "keine .deb-Dateien"

mkdir -p "$ZIEL"
ZIEL=$(readlink -f "$ZIEL")
exec 9<"$ZIEL"
flock -n 9 || die "ein anderer Lauf baut gerade in $ZIEL"
T=$(mktemp -d)
GPG_EIGENER_AGENT=
aufraeumen() {
    rm -rf "$T"
    [ -z "$GPG_EIGENER_AGENT" ] || gpgconf --homedir "$GHOME" --kill gpg-agent 2>/dev/null || true
}
trap aufraeumen EXIT

# ---- Pool: Pakete unter kanonischem Namen ablegen
DIST=$ZIEL/dists/$SUITE
declare -A GESEHEN=()
: >"$T/satz.txt"
for deb in "${DEBS[@]}"; do
    pkg=$(dpkg-deb -f "$deb" Package)
    ver=$(dpkg-deb -f "$deb" Version)
    arch=$(dpkg-deb -f "$deb" Architecture)
    src=$(dpkg-deb -f "$deb" Source)
    src=${src%% *}
    src=${src:-$pkg}
    case " ${ARCHS[*]} " in *" $arch "*) ;; *) die "$deb: Architektur $arch nicht in ${ARCHS[*]}" ;; esac
    k="$pkg $ver $arch"
    [ -z "${GESEHEN[$k]:-}" ] || die "doppelt im Satz: $k (${GESEHEN[$k]} und $deb)"
    GESEHEN[$k]=$deb
    case $src in lib?*) anfang=${src:0:4} ;; *) anfang=${src:0:1} ;; esac
    rel=pool/$KOMP/$anfang/$src/${pkg}_${ver#*:}_$arch.deb
    if [ -e "$ZIEL/$rel" ]; then
        cmp -s "$deb" "$ZIEL/$rel" ||
            die "$rel liegt schon mit anderem Inhalt im Pool (veröffentlichte Versionen sind unveränderlich; neue Version bauen)"
    else
        mkdir -p "$ZIEL/$(dirname "$rel")"
        cp "$deb" "$ZIEL/$rel.neu"
        chmod 0644 "$ZIEL/$rel.neu"
        mv "$ZIEL/$rel.neu" "$ZIEL/$rel"
        log "neu im Pool: $rel"
    fi
    mkdir -p "$T/index/$(dirname "$rel")"
    ln -s "$ZIEL/$rel" "$T/index/$rel"
    printf '%s %s\n' "$arch" "$rel" >>"$T/satz.txt"
done
log "${#DEBS[@]} Pakete im Satz"
find "$ZIEL/pool" -name '*.deb' -type f -printf 'pool/%P\n' | sort >"$T/pool.txt"
awk '{print $2}' "$T/satz.txt" | sort >"$T/satz-pfade.txt"
alt=$(comm -23 "$T/pool.txt" "$T/satz-pfade.txt" | wc -l)
[ "$alt" -eq 0 ] || log "Hinweis: $alt ältere Pool-Dateien nicht mehr im Index (bleiben liegen): $(comm -23 "$T/pool.txt" "$T/satz-pfade.txt" | tr '\n' ' ')"

# ---- Indexdateien in einen Neubau-Ordner schreiben
N=$T/neu
for arch in "${ARCHS[@]}"; do
    b=$N/$KOMP/binary-$arch
    mkdir -p "$b"
    # binary-amd64 führt auch die Architecture-all-Pakete (Clients ohne
    # binary-all-Unterstützung); binary-all nur diese.
    (cd "$T/index" && dpkg-scanpackages -m -a "$arch" pool 2>"$T/scan-$arch.log") >"$b/Packages"
    gzip -9 -n -c "$b/Packages" >"$b/Packages.gz"
    xz -9 -T1 -c "$b/Packages" >"$b/Packages.xz"
    printf 'Archive: %s\nComponent: %s\nOrigin: Querencia\nLabel: Querencia Desktop\nArchitecture: %s\n' \
        "$SUITE" "$KOMP" "$arch" >"$b/Release"
done
# Contents-<arch>: "<pfad> <bereich>/<paket>", je Pfad alle Pakete mit Komma
for arch in "${ARCHS[@]}"; do
    awk -v a="$arch" '$1 == a {print $2}' "$T/satz.txt" | while read -r rel; do
        f=$ZIEL/$rel
        sec=$(dpkg-deb -f "$f" Section)
        sec=${sec:-misc}
        p=$(dpkg-deb -f "$f" Package)
        dpkg-deb --fsys-tarfile "$f" | tar -t | sed -e 's|^\./||' -e '/\/$/d' -e '/^$/d' |
            awk -v t="$sec/$p" '{print $0 "\t" t}'
    done | sort -t "$(printf '\t')" -k1,1 -k2,2 | awk -F '\t' '
        $1 == last { list = list "," $2; next }
        { if (NR > 1) print last "\t" list; last = $1; list = $2 }
        END { if (NR > 0) print last "\t" list }' |
        awk -F '\t' '{printf "%-60s %s\n", $1, $2}' >"$N/$KOMP/Contents-$arch"
    # apt (3.2) holt Contents nur, wenn Release auch den unkomprimierten
    # Schlüssel führt; die Datei selbst ist klein und liegt mit dabei.
    gzip -9 -n -c "$N/$KOMP/Contents-$arch" >"$N/$KOMP/Contents-$arch.gz"
done

# ---- Release-Inhalt ohne Datum, um Gleichheit mit dem vorhandenen zu prüfen
indexliste() { (cd "$N" && find . -type f -printf '%P\n' | LC_ALL=C sort); }
release_rumpf() { # $1 Datum (Unixzeit)
    local fmt='%a, %d %b %Y %H:%M:%S UTC' f
    echo "Origin: Querencia"
    echo "Label: Querencia Desktop"
    echo "Suite: $SUITE"
    echo "Codename: $SUITE"
    echo "Date: $(date -u -d "@$1" +"$fmt")"
    [ -z "$GUELTIG" ] || echo "Valid-Until: $(date -u -d "@$(($1 + GUELTIG * 86400))" +"$fmt")"
    echo "Architectures: ${ARCHS[*]}"
    echo "Components: $KOMP"
    echo "Acquire-By-Hash: yes"
    echo "Description: Querencia Desktop for Ubuntu $SUITE"
    # Nur SHA256: apt holt by-hash immer über den stärksten Hash in
    # Release; mit SHA512 bräuchte es zusätzlich by-hash/SHA512.
    echo "SHA256:"
    indexliste | while read -r f; do
        printf ' %s %16d %s\n' "$(sha256sum <"$N/$f" | cut -d' ' -f1)" "$(stat -c %s "$N/$f")" "$f"
    done
}
ohne_datum() { grep -v -E '^(Date|Valid-Until):' "$1"; }

ALT_DATUM=
if [ -f "$DIST/Release" ]; then
    d=$(sed -n 's/^Date: //p' "$DIST/Release")
    [ -z "$d" ] || ALT_DATUM=$(date -u -d "$d" +%s)
fi

# Schlüssel prüfen, öffentlichen Teil exportieren
[ -d "$GHOME" ] || die "GNUPGHOME fehlt: $GHOME"
GHOME=$(readlink -f "$GHOME")
[ "$GHOME" = "$(readlink -f "${GNUPGHOME:-$HOME/.gnupg}")" ] || GPG_EIGENER_AGENT=1
G=(gpg --batch --quiet --no-tty --homedir "$GHOME")
"${G[@]}" --list-secret-keys "$KEY" >/dev/null 2>&1 || die "geheimer Schlüssel $KEY nicht in $GHOME"
FPR=$("${G[@]}" --with-colons --list-keys "$KEY" | awk -F: '/^fpr/ {print $10; exit}')
ablauf=$("${G[@]}" --with-colons --list-keys "$KEY" | awk -F: '/^pub/ {print $7; exit}')
if [ -n "$ablauf" ]; then
    rest=$(((ablauf - $(date +%s)) / 86400))
    [ "$rest" -gt 0 ] || die "Schlüssel $FPR ist abgelaufen"
    [ "$rest" -gt 60 ] || log "WARNUNG: Schlüssel $FPR läuft in $rest Tagen ab (gpg --quick-set-expire, dann neu veröffentlichen)"
fi
"${G[@]}" --export-options export-minimal --export "$FPR" >"$T/querencia.gpg"
"${G[@]}" --export-options export-minimal --armor --export "$FPR" >"$T/querencia.asc"

release_neu=1
if [ -n "$ALT_DATUM" ] && [ -f "$DIST/InRelease" ] && [ -f "$DIST/Release.gpg" ]; then
    release_rumpf "$ALT_DATUM" >"$T/Release.vergleich"
    if ohne_datum "$T/Release.vergleich" | cmp -s - <(ohne_datum "$DIST/Release") &&
        gpgv --quiet --keyring "$T/querencia.gpg" "$DIST/InRelease" 2>/dev/null &&
        gpgv --quiet --keyring "$T/querencia.gpg" "$DIST/Release.gpg" "$DIST/Release" 2>/dev/null; then
        release_neu=
    fi
fi

# Index in den Zielordner übernehmen; by-hash sammelt alle Fassungen, damit
# Clients mit älterem InRelease während eines Uploads weiter passende
# Dateien finden.
while read -r f; do
    mkdir -p "$DIST/$(dirname "$f")"
    cmp -s "$N/$f" "$DIST/$f" 2>/dev/null || cp "$N/$f" "$DIST/$f"
    case $f in */Release) continue ;; esac
    bh=$DIST/$(dirname "$f")/by-hash/SHA256
    h=$(sha256sum <"$N/$f" | cut -d' ' -f1)
    mkdir -p "$bh"
    [ -f "$bh/$h" ] || cp "$N/$f" "$bh/$h"
done < <(indexliste)
# Indexdateien früherer Läufe, die es nicht mehr gibt (z. B. andere Komponente)
(cd "$DIST" && find . -type f ! -path '*/by-hash/*' ! -name Release ! -name InRelease ! -name Release.gpg -printf '%P\n') |
    while read -r f; do [ -f "$N/$f" ] || { log "entfernt (nicht mehr im Index): dists/$SUITE/$f"; rm -f "$DIST/$f"; }; done

if [ -z "$release_neu" ]; then
    log "Index unverändert: Release, InRelease und Release.gpg bleiben (Datum $(sed -n 's/^Date: //p' "$DIST/Release"))"
    DATUM=$ALT_DATUM
else
    DATUM=${SOURCE_DATE_EPOCH:-$(date +%s)}
    if [ -n "$ALT_DATUM" ] && [ "$DATUM" -le "$ALT_DATUM" ]; then
        die "neues Datum $(date -u -d "@$DATUM") liegt nicht nach dem vorhandenen $(date -u -d "@$ALT_DATUM"); apt würde die Quelle ablehnen"
    fi
    release_rumpf "$DATUM" >"$T/Release"
    # Passphrase: Datei, sonst Abfrage am Terminal (kein Agent-Dialog)
    PW=(--pinentry-mode loopback)
    if [ -n "$PWDATEI" ]; then
        PW+=(--passphrase-file "$PWDATEI")
    elif [ -t 0 ]; then
        read -r -s -p "Passphrase für $FPR (leer bei ungeschütztem Schlüssel): " pw </dev/tty
        echo
        if [ -n "$pw" ]; then
            printf '%s' "$pw" >"$T/pw"
            chmod 0600 "$T/pw"
            PW+=(--passphrase-file "$T/pw")
        fi
        unset pw
    fi
    S=("${G[@]}" "${PW[@]}" --local-user "$FPR" --digest-algo SHA512)
    "${S[@]}" --clearsign --output "$T/InRelease" "$T/Release" || die "Signieren fehlgeschlagen (InRelease)"
    "${S[@]}" --armor --detach-sign --output "$T/Release.gpg" "$T/Release" || die "Signieren fehlgeschlagen (Release.gpg)"
    rm -f "$T/pw"
    gpgv --quiet --keyring "$T/querencia.gpg" "$T/InRelease" 2>/dev/null || die "InRelease lässt sich mit dem öffentlichen Schlüssel nicht prüfen"
    gpgv --quiet --keyring "$T/querencia.gpg" "$T/Release.gpg" "$T/Release" 2>/dev/null || die "Release.gpg lässt sich nicht prüfen"
    # Release vor InRelease ersetzen: InRelease zuletzt
    cp "$T/Release" "$DIST/Release.neu" && mv "$DIST/Release.neu" "$DIST/Release"
    cp "$T/Release.gpg" "$DIST/Release.gpg.neu" && mv "$DIST/Release.gpg.neu" "$DIST/Release.gpg"
    cp "$T/InRelease" "$DIST/InRelease.neu" && mv "$DIST/InRelease.neu" "$DIST/InRelease"
    log "signiert mit $FPR, Datum $(sed -n 's/^Date: //p' "$DIST/Release")"
fi

# Öffentlicher Schlüssel und Client-Vorlage
for f in querencia.gpg querencia.asc; do
    cmp -s "$T/$f" "$ZIEL/$f" 2>/dev/null || cp "$T/$f" "$ZIEL/$f"
done
cat >"$T/querencia.sources" <<E
# /etc/apt/sources.list.d/querencia.sources
# Schlüssel: /etc/apt/keyrings/querencia.gpg
#   Fingerabdruck $FPR
Types: deb
URIs: https://dl.querencialinux.org/apt/
Suites: $SUITE
Components: $KOMP
Architectures: amd64
Signed-By: /etc/apt/keyrings/querencia.gpg
E
cmp -s "$T/querencia.sources" "$ZIEL/querencia.sources" 2>/dev/null || cp "$T/querencia.sources" "$ZIEL/querencia.sources"

# Rechte und Zeitstempel einheitlich (Pool-Dateien behalten ihren)
find "$ZIEL" -type d -exec chmod 0755 {} +
find "$ZIEL" -type f -exec chmod 0644 {} +
find "$ZIEL/dists" "$ZIEL/querencia.gpg" "$ZIEL/querencia.asc" "$ZIEL/querencia.sources" \
    -exec touch -h -d "@$DATUM" {} +

n_amd64=$(grep -c '^Package:' "$DIST/$KOMP/binary-amd64/Packages")
n_all=$(grep -c '^Package:' "$DIST/$KOMP/binary-all/Packages")
log "fertig: $ZIEL ($SUITE/$KOMP: binary-amd64 $n_amd64 Einträge, binary-all $n_all; Schlüssel $FPR)"
