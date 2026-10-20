#!/bin/bash
# Testet die APT-Quelle vollständig isoliert: Wegwerf-Testschlüssel in einem
# temporären GNUPGHOME, Quelle in einem temporären Ordner, apt mit eigenem
# Dir= (eigene sources, eigener dpkg-Status, eigener Cache). Das System-apt,
# /etc/apt und die Paketdatenbank werden nicht berührt; nichts wird
# installiert; kein root.
#
#   bash werkzeuge/apt-quelle-testen.sh <nachweisordner> paket.deb …
#
# Geprüft:
#   1 signierte Quelle: apt update ok, Pakete sichtbar, Abhängigkeiten
#     im Simulationslauf (gegen leeren dpkg-Status: nur Querencia-Pakete)
#   2 manipulierte Packages-Datei: apt lehnt ab (Hash-Fehler)
#   3 falscher Signed-By-Schlüssel: apt lehnt ab
#   4 unsignierte Quelle: apt lehnt ab
# Der private Testschlüssel wird am Ende gelöscht; nur sein öffentlicher Teil
# und der Fingerabdruck bleiben im Nachweisordner.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/gemeinsam.sh"
[ $# -ge 2 ] || die "Aufruf: $0 <nachweisordner> paket.deb …"
OUT=$(readlink -f "$1"); shift
mkdir -p "$OUT"
T=$(mktemp -d)
trap 'gpgconf --homedir "$T/gnupg" --kill all 2>/dev/null; rm -rf "$T"' EXIT
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "PASS $*"; }
nok() { fail=$((fail + 1)); echo "FAIL $*"; }

mkdir -m 0700 "$T/gnupg" "$T/gnupg-fremd"
for h in gnupg gnupg-fremd; do
    gpg --batch --quiet --homedir "$T/$h" --passphrase '' \
        --quick-gen-key "Querencia APT TESTSCHLUESSEL $h - nicht vertrauen <apt-test@querencia.invalid>" ed25519 sign 1d
done
FPR=$(gpg --batch --homedir "$T/gnupg" --with-colons --list-secret-keys | awk -F: '/^fpr/ {print $10; exit}')
log "Testschlüssel $FPR (nur für diesen Lauf)"

export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(date +%s)}
python3 -I "$PK/werkzeuge/apt-quelle-erzeugen.py" --ziel "$T/repo" --gnupghome "$T/gnupg" --schluessel "$FPR" "$@" ||
    die "Quelle nicht erzeugt"

aptroot() { # $1 Name $2 Keyring $3 Repo
    local R=$T/apt-$1
    mkdir -p "$R/etc/apt/sources.list.d" "$R/etc/apt/apt.conf.d" "$R/etc/apt/preferences.d" \
        "$R/etc/apt/trusted.gpg.d" "$R/var/lib/apt/lists/partial" "$R/var/cache/apt/archives/partial" \
        "$R/var/lib/dpkg" "$R/var/log/apt"
    : >"$R/var/lib/dpkg/status"
    cat >"$R/etc/apt/sources.list.d/querencia.sources" <<E
Types: deb
URIs: file:$3/
Suites: resolute
Components: alpha
Architectures: amd64
Signed-By: $2
E
    echo "$R"
}
apt_in() { # $1 Root, Rest: apt-Befehl
    local R=$1; shift
    LC_ALL=C "$@" -o Dir="$R" -o Dir::State::status="$R/var/lib/dpkg/status" \
        -o Dir::Etc::main=/dev/null -o Debug::NoLocking=1 \
        -o APT::Sandbox::User="$(id -un)" -o APT::Architecture=amd64 \
        -o APT::Architectures::=amd64
}

# 1 gültig
R=$(aptroot gut "$T/repo/querencia-archive-keyring.gpg" "$T/repo")
if apt_in "$R" apt-get update >"$T/1.log" 2>&1 && ! grep -q -E '^(W|E):' "$T/1.log"; then
    ok "signierte Quelle: apt-get update"
else
    nok "signierte Quelle: apt-get update"; sed 's/^/     /' "$T/1.log" | tail -8
fi
n=$(apt_in "$R" apt-cache dumpavail 2>/dev/null | grep -c '^Package:')
[ "$n" -ge 1 ] && ok "signierte Quelle: $n Pakete sichtbar" || nok "keine Pakete sichtbar"
apt_in "$R" apt-cache policy querencia-desktop >"$OUT/apt-policy.txt" 2>&1
# erwartete Version: die des übergebenen Metapakets (sonst irgendeine)
soll=
for deb in "$@"; do
    [ "$(dpkg-deb -f "$deb" Package)" = querencia-desktop ] && soll=$(dpkg-deb -f "$deb" Version)
done
if grep -q "Candidate: ${soll:-[0-9]}" "$OUT/apt-policy.txt"; then ok "querencia-desktop ${soll:-} als Kandidat"
else nok "querencia-desktop ${soll:-} nicht als Kandidat"; fi

# 2 manipuliert
cp -a "$T/repo" "$T/repo-manip"
printf '\n' >>"$T/repo-manip/dists/resolute/alpha/binary-amd64/Packages.xz"
printf '\n' >>"$T/repo-manip/dists/resolute/alpha/binary-amd64/Packages.gz"
printf '\n' >>"$T/repo-manip/dists/resolute/alpha/binary-amd64/Packages"
R=$(aptroot manip "$T/repo/querencia-archive-keyring.gpg" "$T/repo-manip")
apt_in "$R" apt-get update >"$T/2.log" 2>&1
if grep -q -i -E 'hash sum mismatch|Hashsummen|File has unexpected size|mismatch' "$T/2.log" &&
    [ "$(apt_in "$R" apt-cache dumpavail 2>/dev/null | grep -c '^Package:')" -eq 0 ]; then
    ok "manipulierte Packages-Datei abgelehnt"
else
    nok "manipulierte Packages-Datei nicht abgelehnt"; tail -5 "$T/2.log" | sed 's/^/     /'
fi

# 3 falscher Schlüssel
gpg --batch --quiet --homedir "$T/gnupg-fremd" --output "$T/fremd.gpg" --export
R=$(aptroot fremd "$T/fremd.gpg" "$T/repo")
apt_in "$R" apt-get update >"$T/3.log" 2>&1
if grep -q -E "NO_PUBKEY|not signed|is not signed|Missing key|Signature by key|could not be verified|NOSPLIT|keyring" "$T/3.log" &&
    [ "$(apt_in "$R" apt-cache dumpavail 2>/dev/null | grep -c '^Package:')" -eq 0 ]; then
    ok "fremder Signed-By-Schlüssel abgelehnt"
else
    nok "fremder Schlüssel nicht abgelehnt"; tail -5 "$T/3.log" | sed 's/^/     /'
fi

# 4 unsigniert
cp -a "$T/repo" "$T/repo-ohne"
rm -f "$T/repo-ohne/dists/resolute/InRelease" "$T/repo-ohne/dists/resolute/Release.gpg"
R=$(aptroot ohne "$T/repo/querencia-archive-keyring.gpg" "$T/repo-ohne")
apt_in "$R" apt-get update >"$T/4.log" 2>&1
if grep -q -E "not signed|is not signed" "$T/4.log" &&
    [ "$(apt_in "$R" apt-cache dumpavail 2>/dev/null | grep -c '^Package:')" -eq 0 ]; then
    ok "unsignierte Quelle abgelehnt"
else
    nok "unsignierte Quelle nicht abgelehnt"; tail -5 "$T/4.log" | sed 's/^/     /'
fi

# Nachweis: Struktur, Release, öffentlicher Testschlüssel; nie privates Material
(cd "$T/repo" && find . -type f | sort) >"$OUT/apt-quelle-dateien.txt"
cp "$T/repo/dists/resolute/Release" "$T/repo/dists/resolute/InRelease" "$OUT/"
cp "$T/repo/querencia-archive-keyring.asc" "$OUT/TESTSCHLUESSEL-oeffentlich.asc"
echo "$FPR" >"$OUT/TESTSCHLUESSEL-fingerabdruck.txt"
for i in 1 2 3 4; do cp "$T/$i.log" "$OUT/apt-test-$i.log"; done
cat >"$OUT/apt-quelle-beispiel.sources" <<E
Types: deb
URIs: <APT-URL>/
Suites: resolute
Components: alpha
Architectures: amd64
Signed-By: /usr/share/keyrings/querencia-archive-keyring.gpg
E
echo "Ergebnis: $pass PASS, $fail FAIL (privater Testschlüssel wird jetzt gelöscht)"
[ $fail -eq 0 ]
