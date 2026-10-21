#!/bin/bash
# Prüft eine APT-Quelle, wie sie werkzeuge/apt/quelle-bauen.sh erzeugt, mit
# apt in einem Wegwerf-Verzeichnis (-o Dir=...): eigene sources, eigener
# dpkg-Status, eigener Cache. Das System-apt, /etc/apt und die
# Paketdatenbank bleiben unberührt; nichts wird installiert; kein root.
#
#   bash werkzeuge/apt/quelle-pruefen.sh [--schluessel <querencia.gpg>]
#       [--fingerabdruck <fpr>] [--nachweis <ordner>] [--ohne-ubuntu]
#       [--installieren] <repo-ordner | https://.../apt>
#
# Lokaler Ordner:
#   1 Struktur: Release-Felder, Hashes aller Indexdateien, by-hash,
#     jede Pool-Datei aus Packages vorhanden mit Größe und SHA256
#   2 Signatur: InRelease und Release.gpg mit gpgv gegen den öffentlichen
#     Schlüssel (Standard: querencia.gpg im Repo; --schluessel nimmt einen
#     unabhängigen, --fingerabdruck verlangt einen bestimmten)
#   3 apt über file://: update ohne Warnung, Contents laden,
#     querencia-desktop als Kandidat in der Version aus dem Index
#   4 apt über http:// (lokaler http.server unter /apt/, wie der Server):
#     update, by-hash, alle Querencia-Pakete herunterladen (Hash-Prüfung
#     durch apt), Abgleich mit dem Pool
#   5 Auflösung auf einem frischen System: leerer dpkg-Status, Ubuntu-Listen
#     des Rechners (nur gelesen, Kopie) + diese Quelle:
#     apt-get install --simulate querencia-desktop (mit und ohne Recommends)
#   6 Gegenproben: manipulierte Packages-Datei, fremder Schlüssel,
#     unsignierte Quelle: apt muss jeweils ablehnen
#   --installieren: zusätzlich tests/wegwerf-installation.sh mit den in 4
#     heruntergeladenen Paketen (bubblewrap-Hülle, kopflos)
# URL (nach dem Hochladen): 2, 3 (über https) und 5 gegen den Server.
# Ergebnis: PASS/FAIL je Prüfung, Exit 1 bei einem FAIL.
set -uo pipefail
# tests/wegwerf-installation.sh wertet deutsche dpkg-Meldungen aus und läuft
# deshalb mit dem Gebietsschema des Aufrufs.
AUFRUF_LC_ALL=${LC_ALL-}
export LC_ALL=C.UTF-8
HIER=$(dirname "$(readlink -f "$0")")
PK=$(cd "$HIER/../.." && pwd)

die() { printf 'quelle-pruefen: FEHLER: %s\n' "$*" >&2; exit 2; }
KEYFILE= FPR_SOLL= OUT= UBUNTU=1 INSTALL= SUITE=resolute KOMP=main
while [ $# -gt 0 ]; do
    case $1 in
    --schluessel) KEYFILE=$(readlink -f "$2"); shift 2 ;;
    --fingerabdruck) FPR_SOLL=${2^^}; FPR_SOLL=${FPR_SOLL// /}; shift 2 ;;
    --nachweis) OUT=$2; shift 2 ;;
    --ohne-ubuntu) UBUNTU=; shift ;;
    --installieren) INSTALL=1; shift ;;
    --suite) SUITE=$2; shift 2 ;;
    --komponente) KOMP=$2; shift 2 ;;
    -h | --help) sed -n '2,/^set -uo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unbekannte Option $1" ;;
    *) break ;;
    esac
done
[ $# -eq 1 ] || die "Aufruf: $0 [Optionen] <repo-ordner | https://.../apt> (--help)"
QUELLE=$1
T=$(mktemp -d)
HTTP_PID=
trap '[ -z "$HTTP_PID" ] || kill "$HTTP_PID" 2>/dev/null; rm -rf "$T"' EXIT
OUT=${OUT:-$T/nachweis}
mkdir -p "$OUT"
OUT=$(readlink -f "$OUT")
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "PASS $*"; }
nok() { fail=$((fail + 1)); echo "FAIL $*"; }
hinweis() { echo "HINW $*"; }

case $QUELLE in
http://* | https://*) FERN=1 URL=${QUELLE%/} ;;
*) FERN= REPO=$(readlink -f "$QUELLE"); [ -f "$REPO/dists/$SUITE/InRelease" ] || die "keine Quelle: $REPO/dists/$SUITE/InRelease fehlt" ;;
esac

# Kopie der für die Prüfung nötigen Dateien (lokal oder vom Server)
holen() { # $1 relativer Pfad, $2 Ziel
    if [ -n "$FERN" ]; then curl -fsS --max-time 60 -o "$2" "$URL/$1"; else cp "$REPO/$1" "$2"; fi
}
mkdir -p "$T/meta"
holen "dists/$SUITE/InRelease" "$T/meta/InRelease" || die "InRelease nicht lesbar"
holen "dists/$SUITE/Release" "$T/meta/Release" || die "Release nicht lesbar"
holen "dists/$SUITE/Release.gpg" "$T/meta/Release.gpg" || die "Release.gpg nicht lesbar"
if [ -z "$KEYFILE" ]; then
    holen querencia.gpg "$T/meta/querencia.gpg" || die "querencia.gpg nicht lesbar"
    KEYFILE=$T/meta/querencia.gpg
    hinweis "Schlüssel aus der Quelle selbst (nur Konsistenz); unabhängig prüfen mit --schluessel oder --fingerabdruck"
fi
# Genau ein Hauptschlüssel im Keyring: gpgv nimmt jeden Schlüssel darin an,
# ein zusätzlicher fremder Schlüssel würde sonst unbemerkt mitgelten (CLEAN-1 B3).
SCHLUESSEL=$(gpg --batch --no-tty --with-colons --show-keys "$KEYFILE" 2>/dev/null)
ANZAHL=$(grep -c '^pub:' <<<"$SCHLUESSEL")
FPR_IST=$(awk -F: '/^pub:/ {p=1; next} p && /^fpr:/ {print $10; exit}' <<<"$SCHLUESSEL")
echo "Schlüssel: $FPR_IST ($KEYFILE, $ANZAHL Hauptschlüssel)"
[ "$ANZAHL" = 1 ] || die "Keyring $KEYFILE enthält $ANZAHL Hauptschlüssel, erwartet genau einen"
[ -z "$FPR_SOLL" ] || [ "$FPR_IST" = "$FPR_SOLL" ] || die "Keyring hat $FPR_IST, erwartet $FPR_SOLL"

# ---- 1 Struktur (nur lokal)
if [ -z "$FERN" ]; then
    R=$REPO/dists/$SUITE
    feld() { sed -n "s/^$1: //p" "$R/Release"; }
    fehler=
    [ "$(feld Suite)" = "$SUITE" ] && [ "$(feld Codename)" = "$SUITE" ] || fehler+=" Suite/Codename"
    [ "$(feld Components)" = "$KOMP" ] || fehler+=" Components"
    [ "$(feld Architectures)" = "amd64 all" ] || fehler+=" Architectures"
    [ "$(feld Acquire-By-Hash)" = yes ] || fehler+=" Acquire-By-Hash"
    [ -n "$(feld Date)" ] || fehler+=" Date"
    [ -z "$fehler" ] && ok "Release-Felder (Suite $SUITE, $KOMP, amd64 all, by-hash)" || nok "Release-Felder:$fehler"
    n=0 falsch=
    while read -r h size f; do
        n=$((n + 1))
        [ -f "$R/$f" ] && [ "$(stat -c %s "$R/$f")" = "$size" ] && [ "$(sha256sum <"$R/$f" | cut -d' ' -f1)" = "$h" ] || falsch+=" $f"
        case $f in */Release) ;; *) [ -f "$R/$(dirname "$f")/by-hash/SHA256/$h" ] || falsch+=" by-hash:$f" ;; esac
    done < <(awk '/^SHA256:/ {s=1; next} /^[A-Za-z]/ {s=0} s {print $1, $2, $3}' "$R/Release")
    [ -z "$falsch" ] && ok "Release: $n Indexdateien mit SHA256 und by-hash" || nok "Release-Hashes:$falsch"
    grep -q -E '^(SHA512|SHA1|MD5Sum):' "$R/Release" && nok "Release führt weitere Hashes (by-hash gibt es nur für SHA256)"
    for f in $KOMP/binary-amd64/Packages $KOMP/binary-all/Packages $KOMP/Contents-amd64 $KOMP/Contents-amd64.gz \
        $KOMP/Contents-all $KOMP/Contents-all.gz; do
        grep -q " $f\$" "$R/Release" || nok "fehlt in Release: $f"
    done
    m=0 falsch=
    for a in amd64 all; do
        while read -r fn size h; do
            m=$((m + 1))
            [ -f "$REPO/$fn" ] && [ "$(stat -c %s "$REPO/$fn")" = "$size" ] && [ "$(sha256sum <"$REPO/$fn" | cut -d' ' -f1)" = "$h" ] || falsch+=" $fn"
        done < <(awk '/^Filename:/ {f=$2} /^Size:/ {s=$2} /^SHA256:/ {print f, s, $2}' "$R/$KOMP/binary-$a/Packages")
    done
    [ -z "$falsch" ] && ok "Pool: $m Index-Einträge mit Größe und SHA256" || nok "Pool:$falsch"
    for a in amd64 all; do
        zcat "$R/$KOMP/Contents-$a.gz" | awk '!/^[^ ]+ +[^ ]+\/[^ ]+$/ {f++} END {exit (f > 0 || NR == 0)}' ||
            nok "Contents-$a.gz: leer oder Zeile nicht im Format <pfad> <bereich>/<paket>"
    done
    falsch=$(find "$REPO/dists" "$REPO/pool" \( -type f ! -perm 0644 \) -o \( -type d ! -perm 0755 \) | head -3)
    [ -z "$falsch" ] && ok "Dateirechte 0644/0755" || nok "Dateirechte: $falsch"
fi

# ---- 2 Signatur
# VALIDSIG nennt als letztes Feld den Hauptschlüssel, der signiert hat.
signierer() { awk '$2 == "VALIDSIG" {print $NF}' "$1"; }
if gpgv --status-fd 3 --keyring "$KEYFILE" "$T/meta/InRelease" >"$T/gpgv1.log" 2>&1 3>"$T/gpgv1.status" &&
    gpgv --status-fd 3 --keyring "$KEYFILE" "$T/meta/Release.gpg" "$T/meta/Release" >"$T/gpgv2.log" 2>&1 3>"$T/gpgv2.status" &&
    [ "$(signierer "$T/gpgv1.status")" = "$FPR_IST" ] && [ "$(signierer "$T/gpgv2.status")" = "$FPR_IST" ]; then
    ok "Signatur: InRelease und Release.gpg gültig, signiert von $FPR_IST"
else
    nok "Signatur ungültig"; sed 's/^/     /' "$T/gpgv1.log" "$T/gpgv2.log" | tail -6
fi
gpgv --quiet --keyring "$KEYFILE" --output "$T/meta/InRelease.text" "$T/meta/InRelease" 2>/dev/null
cmp -s "$T/meta/InRelease.text" "$T/meta/Release" && ok "InRelease enthält genau Release" || nok "InRelease weicht von Release ab"
if [ -n "$FPR_SOLL" ]; then
    [ "$(signierer "$T/gpgv1.status")" = "$FPR_SOLL" ] && [ "$FPR_IST" = "$FPR_SOLL" ] &&
        ok "Schlüssel ist $FPR_SOLL (einziger im Keyring, signiert InRelease)" || nok "Schlüssel $FPR_IST, erwartet $FPR_SOLL"
fi
ablauf=$(gpg --batch --no-tty --with-colons --show-keys "$KEYFILE" 2>/dev/null | awk -F: '/^pub/ {print $7; exit}')
if [ -n "$ablauf" ]; then
    rest=$(((ablauf - $(date +%s)) / 86400))
    [ "$rest" -gt 60 ] && ok "Schlüssel gültig bis $(date -u -d "@$ablauf" +%F) ($rest Tage)" || nok "Schlüssel läuft in $rest Tagen ab"
fi
grep -q '^Valid-Until:' "$T/meta/Release" && hinweis "Release hat Valid-Until: $(sed -n 's/^Valid-Until: //p' "$T/meta/Release")"

# ---- apt in einer Wegwerf-Wurzel
aptroot() { # $1 Name, $2 URI, $3 Keyring, [$4 ubuntu]
    local W=$T/apt-$1
    mkdir -p "$W/etc/apt/sources.list.d" "$W/etc/apt/apt.conf.d" "$W/etc/apt/preferences.d" \
        "$W/etc/apt/trusted.gpg.d" "$W/var/lib/apt/lists/partial" "$W/var/cache/apt/archives/partial" \
        "$W/var/lib/dpkg" "$W/var/log/apt"
    : >"$W/var/lib/dpkg/status"
    cat >"$W/etc/apt/sources.list.d/querencia.sources" <<E
Types: deb
URIs: $2
Suites: $SUITE
Components: $KOMP
Architectures: amd64
Signed-By: $3
E
    # Eigene Konfiguration statt /etc/apt (APT_CONFIG wird vor allem anderen
    # gelesen); Contents wie apt-file laden (prüft auch deren Hashes)
    cat >"$W/apt.conf" <<E
Dir "$W/";
Dir::State::status "$W/var/lib/dpkg/status";
Dir::Etc::main "/dev/null";
Dir::Etc::Parts "$W/etc/apt/apt.conf.d";
E
    cat >"$W/etc/apt/apt.conf.d/50contents.conf" <<'E'
Acquire::IndexTargets::deb::Contents-deb {
    MetaKey "$(COMPONENT)/Contents-$(ARCHITECTURE)";
    ShortDescription "Contents-$(ARCHITECTURE)";
    Description "$(RELEASE)/$(COMPONENT) $(ARCHITECTURE) Contents (deb)";
    flatMetaKey "Contents-$(ARCHITECTURE)";
    flatDescription "$(RELEASE) Contents (deb)";
    PDiffs "false";
    KeepCompressed "true";
};
E
    if [ "${4-}" = ubuntu ]; then
        cp /etc/apt/sources.list.d/ubuntu.sources "$W/etc/apt/sources.list.d/"
        find /var/lib/apt/lists -maxdepth 1 -type f -readable \( -name '*ubuntu.com_ubuntu_dists_resolute*_InRelease' \
            -o -name '*ubuntu.com_ubuntu_dists_resolute*_binary-amd64_Packages*' \) -exec cp -p {} "$W/var/lib/apt/lists/" \;
    fi
    echo "$W"
}
apt_in() { # $1 Wurzel, Rest: apt-Befehl
    local W=$1; shift
    APT_CONFIG=$W/apt.conf "$@" -o Debug::NoLocking=1 \
        -o APT::Sandbox::User="$(id -un)" -o APT::Architecture=amd64 -o APT::Architectures::=amd64 \
        -o Acquire::Languages=none
}
nur_querencia_update() { # $1 Wurzel: nur die Querencia-Quelle aktualisieren, Ubuntu-Listen behalten
    apt_in "$1" apt-get update -o Dir::Etc::SourceList=/dev/null \
        -o Dir::Etc::SourceParts=- -o APT::Get::List-Cleanup=0 \
        -o Dir::Etc::SourceList="$1/etc/apt/sources.list.d/querencia.sources"
}
update_ok() { # $1 Name, $2 Log
    if grep -q -E '^(W|E|Err):' "$2"; then nok "$1: apt-get update"; grep -E '^(W|E|Err):' "$2" | head -6 | sed 's/^/     /'; return 1; fi
    ok "$1: apt-get update ohne Warnung"
}
SOLL=$(awk '/^Package: querencia-desktop$/ {p=1} p && /^Version:/ {print $2; exit}' \
    <(if [ -n "$FERN" ]; then curl -fsS "$URL/dists/$SUITE/$KOMP/binary-all/Packages"; else cat "$REPO/dists/$SUITE/$KOMP/binary-all/Packages"; fi))
[ -n "$SOLL" ] || nok "querencia-desktop fehlt im Index binary-all"
kandidat() { # $1 Name, $2 Wurzel
    apt_in "$2" apt-cache policy querencia-desktop >"$OUT/policy-$1.txt" 2>&1
    grep -q "Candidate: $SOLL\$" "$OUT/policy-$1.txt" && ok "$1: querencia-desktop $SOLL ist Kandidat" ||
        { nok "$1: querencia-desktop $SOLL nicht Kandidat"; sed 's/^/     /' "$OUT/policy-$1.txt" | head -6; }
}
contents_ok() { # $1 Name, $2 Wurzel
    local n
    n=$(find "$2/var/lib/apt/lists" -maxdepth 1 -name '*Contents-*' | wc -l)
    [ "$n" -ge 2 ] && ok "$1: Contents-amd64 und Contents-all geladen" || nok "$1: Contents nicht geladen ($n)"
}

if [ -z "$FERN" ]; then
    # ---- 3 file://
    W=$(aptroot datei "file:$REPO/" "$KEYFILE")
    apt_in "$W" apt-get update >"$OUT/update-datei.log" 2>&1
    update_ok "file://" "$OUT/update-datei.log" && { kandidat file "$W"; contents_ok "file://" "$W"; }

    # ---- 4 http:// über einen lokalen Server, Pfad /apt/ wie der echte
    mkdir -p "$T/www"
    ln -s "$REPO" "$T/www/apt"
    PORT=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
    python3 -I -m http.server --bind 127.0.0.1 --directory "$T/www" "$PORT" >"$T/http.log" 2>&1 &
    HTTP_PID=$!
    for _ in $(seq 50); do curl -fs -o /dev/null "http://127.0.0.1:$PORT/apt/querencia.gpg" && break; sleep 0.1; done
    W=$(aptroot http "http://127.0.0.1:$PORT/apt/" "$KEYFILE")
    apt_in "$W" apt-get update >"$OUT/update-http.log" 2>&1
    if update_ok "http://" "$OUT/update-http.log"; then
        kandidat http "$W"
        contents_ok "http://" "$W"
        grep -q 'by-hash/SHA256/' "$T/http.log" && ok "http://: apt holt die Indexdateien über by-hash" || nok "http://: kein by-hash-Abruf"
        pakete=$(apt_in "$W" apt-cache dumpavail 2>/dev/null | sed -n 's/^Package: //p' | sort -u)
        mkdir -p "$OUT/heruntergeladen"
        if (cd "$OUT/heruntergeladen" && apt_in "$W" apt-get download $pakete) >"$OUT/download-http.log" 2>&1; then
            n=$(ls "$OUT/heruntergeladen"/*.deb | wc -l)
            falsch=
            for d in "$OUT/heruntergeladen"/*.deb; do
                b=$(basename "$d"); b=${b//%3a/:}
                q=$(find "$REPO/pool" -name "$(basename "$d")" -print -quit)
                [ -n "$q" ] && cmp -s "$d" "$q" || falsch+=" $b"
            done
            [ -z "$falsch" ] && ok "http://: $n Pakete heruntergeladen, byte-gleich mit dem Pool" || nok "http://: abweichend:$falsch"
        else
            nok "http://: apt-get download"; tail -5 "$OUT/download-http.log" | sed 's/^/     /'
        fi
    fi
    UBU_URI="http://127.0.0.1:$PORT/apt/"
else
    # ---- 3 über den Server
    W=$(aptroot server "$URL/" "$KEYFILE")
    apt_in "$W" apt-get update >"$OUT/update-server.log" 2>&1
    update_ok "$URL" "$OUT/update-server.log" && { kandidat server "$W"; contents_ok "$URL" "$W"; }
    UBU_URI="$URL/"
fi

# ---- 5 frisches System: leerer Status, Ubuntu-Listen des Rechners
if [ -n "$UBUNTU" ]; then
    if ls /var/lib/apt/lists/*ubuntu.com_ubuntu_dists_resolute_main_binary-amd64_Packages* >/dev/null 2>&1; then
        W=$(aptroot frisch "$UBU_URI" "$KEYFILE" ubuntu)
        nur_querencia_update "$W" >"$OUT/update-frisch.log" 2>&1
        update_ok "frisch" "$OUT/update-frisch.log"
        for art in mit ohne; do
            extra=()
            [ $art = ohne ] && extra=(--no-install-recommends)
            if apt_in "$W" apt-get install --simulate "${extra[@]}" querencia-desktop >"$OUT/simulation-$art-recommends.txt" 2>&1; then
                n=$(grep -c '^Inst ' "$OUT/simulation-$art-recommends.txt")
                q=$(grep -c '^Inst .* Querencia Desktop:' "$OUT/simulation-$art-recommends.txt")
                ok "frisch: querencia-desktop auflösbar $art Recommends ($n Pakete, davon $q aus dieser Quelle)"
            else
                nok "frisch: querencia-desktop nicht auflösbar $art Recommends"
                grep -E '^( |E:)' "$OUT/simulation-$art-recommends.txt" | head -8 | sed 's/^/     /'
            fi
        done
    else
        hinweis "keine Ubuntu-resolute-Listen in /var/lib/apt/lists: Auflösungsprobe übersprungen"
    fi
fi

# ---- 6 Gegenproben (nur lokal)
if [ -z "$FERN" ]; then
    leer() { [ "$(apt_in "$1" apt-cache dumpavail 2>/dev/null | grep -c '^Package:')" -eq 0 ]; }
    cp -a "$REPO" "$T/repo-manip"
    for f in Packages Packages.gz Packages.xz; do
        p=$T/repo-manip/dists/$SUITE/$KOMP/binary-amd64/$f
        printf '\n' >>"$p"
        rm -rf "$T/repo-manip/dists/$SUITE/$KOMP/binary-amd64/by-hash"
    done
    W=$(aptroot manip "file:$T/repo-manip/" "$KEYFILE")
    apt_in "$W" apt-get update >"$OUT/gegenprobe-manipuliert.log" 2>&1
    grep -q -i -E 'hash sum mismatch|unexpected size|mismatch|Hashsumme' "$OUT/gegenprobe-manipuliert.log" &&
        ! apt_in "$W" apt-cache show querencia-shell >/dev/null 2>&1 &&
        ok "Gegenprobe: manipulierte Packages-Datei abgelehnt" || nok "manipulierte Packages-Datei nicht abgelehnt"

    mkdir -m 0700 "$T/fremd"
    gpg --batch --quiet --homedir "$T/fremd" --passphrase '' --quick-gen-key 'Fremd <fremd@querencia.invalid>' ed25519 sign 1d
    gpg --batch --quiet --homedir "$T/fremd" --export >"$T/fremd.gpg"
    gpgconf --homedir "$T/fremd" --kill gpg-agent 2>/dev/null
    W=$(aptroot fremd "file:$REPO/" "$T/fremd.gpg")
    apt_in "$W" apt-get update >"$OUT/gegenprobe-fremd.log" 2>&1
    grep -q -E 'NO_PUBKEY|not signed|Missing key|could not be verified|Signature by key|keyring|public key' "$OUT/gegenprobe-fremd.log" && leer "$W" &&
        ok "Gegenprobe: fremder Signed-By-Schlüssel abgelehnt" || nok "fremder Schlüssel nicht abgelehnt"

    cp -a "$REPO" "$T/repo-ohne"
    rm -f "$T/repo-ohne/dists/$SUITE/InRelease" "$T/repo-ohne/dists/$SUITE/Release.gpg"
    W=$(aptroot ohne "file:$T/repo-ohne/" "$KEYFILE")
    apt_in "$W" apt-get update >"$OUT/gegenprobe-unsigniert.log" 2>&1
    grep -q -E 'not signed|is not signed' "$OUT/gegenprobe-unsigniert.log" && leer "$W" &&
        ok "Gegenprobe: unsignierte Quelle abgelehnt" || nok "unsignierte Quelle nicht abgelehnt"
fi

# ---- Installation in der Wegwerf-Hülle
if [ -n "$INSTALL" ]; then
    if [ -z "$FERN" ] && ls "$OUT"/heruntergeladen/*.deb >/dev/null 2>&1; then
        echo "--- tests/wegwerf-installation.sh mit den über apt geladenen Paketen"
        if (if [ -n "$AUFRUF_LC_ALL" ]; then export LC_ALL=$AUFRUF_LC_ALL; else unset LC_ALL; fi
            exec bash "$PK/tests/wegwerf-installation.sh" "$OUT/wegwerf" "$OUT"/heruntergeladen/*.deb) >"$OUT/wegwerf-lauf.txt" 2>&1; then
            ok "Wegwerf-Installation: $(grep -c '^PASS' "$OUT/wegwerf-lauf.txt") PASS, 0 FAIL"
        else
            nok "Wegwerf-Installation: $(grep -c '^FAIL' "$OUT/wegwerf-lauf.txt") FAIL"; grep '^FAIL' "$OUT/wegwerf-lauf.txt" | head -5 | sed 's/^/     /'
        fi
    else
        hinweis "--installieren nur mit lokalem Ordner und erfolgreichem Download"
    fi
fi

cp "$T/meta/Release" "$OUT/Release"
echo "$FPR_IST" >"$OUT/schluessel-fingerabdruck.txt"
echo "Ergebnis: $pass PASS, $fail FAIL"
[ $fail -eq 0 ]
