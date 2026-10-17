# Gemeinsame Einstellungen der Werkzeuge (wird mit "." eingelesen).
# Alles läuft im Arbeitsbereich; nichts wird installiert, nichts nach $HOME
# außerhalb dieses Bereichs geschrieben, kein sudo.
PK=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
QUELLEN=${QUERENCIA_QUELLEN:-$(dirname "$PK")}
AUSGABE=${QUERENCIA_AUSGABE:-$(dirname "$QUELLEN")/pakete}
NACHWEIS=${QUERENCIA_NACHWEIS:-$(dirname "$QUELLEN")/nachweis}
VENDOR_CARGO_HOME=${QUERENCIA_VENDOR_CARGO_HOME:-$AUSGABE/cargo-home}
BUILD_LOCK=${QUERENCIA_BUILD_LOCK:-$HOME/.local/state/querencia/bau.lock}
JOBS=${QUERENCIA_JOBS:-2}

log() { printf '%s: %s\n' "$(basename "$0")" "$*"; }
die() { printf '%s: FEHLER: %s\n' "$(basename "$0")" "$*" >&2; exit 1; }

# quelle <quellpaket>: setzt SRC REPO REV VER VENDOR EXCL aus quellen.conf
quelle() {
    local line
    line=$(awk -v s="$1" '$1 == s { print; exit }' "$PK/quellen.conf")
    [ -n "$line" ] || die "unbekanntes Quellpaket: $1 (siehe quellen.conf)"
    read -r SRC REPO REV VER VENDOR EXCL <<<"$line"
    git -C "$QUELLEN/$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "Repository fehlt: $QUELLEN/$REPO"
    COMMIT=$(git -C "$QUELLEN/$REPO" rev-parse --verify "$REV^{commit}") || die "Revision $REV fehlt in $REPO"
    EPOCH=$(git -C "$QUELLEN/$REPO" log -1 --format=%ct "$COMMIT")
    DIR=$SRC-$VER
    ORIG=${SRC}_${VER}.orig.tar.xz
    ORIG_VENDOR=${SRC}_${VER}.orig-cargo-vendor.tar.xz
    # debian/ eigener Pakete unter <src>/, Fremdpakete unter backports/<src>/
    DEBDIR=$PK/$SRC/debian
    [ -d "$DEBDIR" ] || DEBDIR=$PK/backports/$SRC/debian
    [ -d "$DEBDIR" ] || die "debian/ für $SRC fehlt"
}

# Umgebung ohne Verbindung zur laufenden Sitzung und ohne rustup-Proxys.
sauber() {
    env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR \
        -u RUSTUP_TOOLCHAIN -u CARGO_HOME -u CARGO_TARGET_DIR \
        PATH=/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C.UTF-8 "$@"
}
