# Gemeinsame Einstellungen der Werkzeuge (wird mit "." eingelesen).
# Alles läuft im Arbeitsbereich; nichts wird installiert, nichts nach $HOME
# außerhalb dieses Bereichs geschrieben, kein sudo.
PK=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# Quell-Repositories: die Spalte <repository> in quellen.conf ist relativ zu
# QUELLEN (Standard: der Ordner, in dem dieses Repository liegt).
QUELLEN=${QUERENCIA_QUELLEN:-$(dirname "$PK")}
# Erzeugnisse im Ordner build/ dieses Repositorys (nicht in Git, .gitignore).
AUSGABE=${QUERENCIA_AUSGABE:-$PK/build}
NACHWEIS=${QUERENCIA_NACHWEIS:-$AUSGABE/nachweis}
VENDOR_CARGO_HOME=${QUERENCIA_VENDOR_CARGO_HOME:-$AUSGABE/cargo-home}
# Quellstände; für Probebauten (z. B. ein Paket vor seinem Tag) eine Kopie.
QUELLEN_CONF=${QUERENCIA_QUELLEN_CONF:-$PK/quellen.conf}
BUILD_LOCK=${QUERENCIA_BUILD_LOCK:-$HOME/.local/state/querencia/bau.lock}
# Bau-Plätze der Startsession (seit 20.10.2026 13:3x): zwei Plätze, nice 10,
# 4 Jobs. Fehlt das Skript, gilt die alte gemeinsame Sperre $BUILD_LOCK.
BAU_PLATZ=${QUERENCIA_BAU_PLATZ:-$HOME/.local/state/querencia/bau-platz.sh}
JOBS=${QUERENCIA_JOBS:-2}
# Niedrige CPU-Priorität für alle Bauläufe (mehrere Sitzungen bauen parallel).
NICE=${QUERENCIA_NICE:-10}
# Nie ins Quellarchiv: Arbeitsanweisungen, Nachweise, Integrationsskripte
# (ENTSCHEIDUNGEN Nr. 9, 10, 13). komponenten.conf kann das abschalten.
ORIG_AUSSCHLUSS_STANDARD="CLAUDE.md nachweis integration"

log() { printf '%s: %s\n' "$(basename "$0")" "$*"; }
die() { printf '%s: FEHLER: %s\n' "$(basename "$0")" "$*" >&2; exit 1; }

# quelle <quellpaket>: setzt SRC REPO REV VER VENDOR EXCL aus quellen.conf
quelle() {
    local line
    line=$(awk -v s="$1" '$1 == s { print; exit }' "$QUELLEN_CONF")
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
    komponenten
}

# komponenten: liest <src>/komponenten.conf (optional), eine Angabe je Zeile:
#   unterordner <ordner>              Hauptarchiv liegt im Quellbaum unter <ordner>/
#   komponente <name> <repo> <rev>    weiteres Archiv <src>_<ver>.orig-<name>.tar.xz,
#                                     dpkg-source entpackt es nach <name>/
#   ausschluss <glob>                 zusätzlich nicht ins Hauptarchiv (git-Pathspec-Glob)
#   ausschluss-standard nein          ORIG_AUSSCHLUSS_STANDARD nicht anwenden
# Setzt UNTERORDNER, KOMP_NAMEN, KOMP_REPOS, KOMP_REVS, AUSSCHLUSS (Pathspecs).
komponenten() {
    UNTERORDNER= KOMP_NAMEN=() KOMP_REPOS=() KOMP_REVS=() AUSSCHLUSS=()
    local conf=$(dirname "$DEBDIR")/komponenten.conf standard=ja art a b c x
    if [ -f "$conf" ]; then
        while read -r art a b c; do
            case $art in
            '' | '#'*) ;;
            unterordner) UNTERORDNER=$a ;;
            komponente)
                git -C "$QUELLEN/$b" rev-parse --verify -q "$c^{commit}" >/dev/null || die "$conf: $b@$c fehlt"
                KOMP_NAMEN+=("$a") KOMP_REPOS+=("$b") KOMP_REVS+=("$(git -C "$QUELLEN/$b" rev-parse "$c^{commit}")") ;;
            ausschluss) AUSSCHLUSS+=(":(exclude,glob)$a") ;;
            ausschluss-standard) [ "$a" = nein ] && standard=nein ;;
            *) die "$conf: unbekannte Angabe $art" ;;
            esac
        done <"$conf"
    fi
    if [ "$standard" = ja ]; then
        for x in $ORIG_AUSSCHLUSS_STANDARD; do
            AUSSCHLUSS+=(":(exclude,glob)**/$x" ":(exclude,glob)**/$x/**")
        done
    fi
}

# Dateiname des Archivs der Komponente $1.
orig_komp() { echo "${SRC}_${VER}.orig-$1.tar.xz"; }

# bauplatz <befehl ...>: Befehl auf einem Bau-Platz (bau-platz.sh) bzw. unter
# der gemeinsamen Sperre, mit niedriger Priorität. Vor sauber() aufrufen:
# bau-platz.sh findet seine Sperren über $HOME.
bauplatz() {
    if [ -f "$BAU_PLATZ" ]; then
        bash "$BAU_PLATZ" "$@"
    else
        flock "$BUILD_LOCK" nice -n "$NICE" "$@"
    fi
}

# Umgebung ohne Verbindung zur laufenden Sitzung und ohne rustup-Proxys.
sauber() {
    env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR \
        -u RUSTUP_TOOLCHAIN -u CARGO_HOME -u CARGO_TARGET_DIR \
        PATH=/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C.UTF-8 "$@"
}
