#!/bin/bash
# Erzeugt die Upstream-Quellarchive eines Quellpakets aus einem festen Commit:
#   <src>_<ver>.orig.tar.xz              git archive des Commits (deterministisch)
#   <src>_<ver>.orig-cargo-vendor.tar.xz alle Crates aus Cargo.lock (cargo vendor),
#                                        die in quellen.conf ausgeschlossenen nur als
#                                        entkernte Platzhalter (Manifest ohne Code)
# und aktualisiert debian/copyright (aus copyright.in) und debian/upstream-commit
# im Paketierungs-Repository. Lizenzinventar nach nachweis/lizenzen/.
#
#   bash werkzeuge/orig-erzeugen.sh <quellpaket>
#
# Crates werden zuerst offline aus $VENDOR_CARGO_HOME genommen; fehlen welche,
# lädt cargo sie von crates.io (Prüfsummen aus Cargo.lock). Der gemeinsame
# ~/.cargo wird nie benutzt.
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/gemeinsam.sh"
[ $# -eq 1 ] || die "Aufruf: $0 <quellpaket>"
quelle "$1"

mkdir -p "$AUSGABE/orig" "$NACHWEIS/lizenzen" "$VENDOR_CARGO_HOME"
TMP=$(mktemp -d "$AUSGABE/.orig-XXXXXX")
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

log "$SRC $VER aus $REPO@${COMMIT:0:12}"
git -C "$QUELLEN/$REPO" archive --format=tar --prefix="$DIR/" "$COMMIT" >"$TMP/orig.tar"
xz -T1 -9 -c "$TMP/orig.tar" >"$AUSGABE/orig/$ORIG"
echo "$COMMIT" >"$DEBDIR/upstream-commit"

if [ "$VENDOR" = ja ]; then
    tar -xf "$TMP/orig.tar" -C "$TMP"
    (
        cd "$TMP/$DIR"
        export CARGO_HOME=$VENDOR_CARGO_HOME
        if ! sauber CARGO_HOME="$CARGO_HOME" /usr/bin/cargo vendor --locked --offline --versioned-dirs \
            "$TMP/cargo-vendor" >/dev/null 2>"$TMP/vendor-offline.err"; then
            log "offline unvollständig, lade fehlende Crates von crates.io"
            rm -rf "$TMP/cargo-vendor"
            sauber CARGO_HOME="$CARGO_HOME" /usr/bin/cargo vendor --locked --versioned-dirs \
                "$TMP/cargo-vendor" >/dev/null
        fi
    )
    if [ "$EXCL" != - ]; then
        IFS=, read -r -a muster <<<"$EXCL"
        for m in "${muster[@]}"; do
            for d in "$TMP"/cargo-vendor/$m; do
                [ -d "$d" ] || continue
                # Cargo braucht das Manifest auch abgeschalteter optionaler
                # Crates; der Code wird entfernt (werkzeuge/crate-entkernen.py).
                python3 -I "$PK/werkzeuge/crate-entkernen.py" "$d" "in quellen.conf ausgeschlossen (Lizenz)" >/dev/null
                log "im Vendor-Archiv entkernt (nur Manifest): $(basename "$d")"
            done
        done
    fi
    n=$(find "$TMP/cargo-vendor" -mindepth 1 -maxdepth 1 -type d | wc -l)
    tar --sort=name --mtime="@$EPOCH" --owner=0 --group=0 --numeric-owner \
        --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
        -C "$TMP" -cf - cargo-vendor | xz -T1 -9 -c >"$AUSGABE/orig/$ORIG_VENDOR"
    log "$n Crates -> $ORIG_VENDOR"
    python3 -I "$PK/werkzeuge/copyright-erzeugen.py" "$DEBDIR/copyright.in" \
        "$TMP/cargo-vendor" "$DEBDIR/copyright" "$NACHWEIS/lizenzen/$SRC-crates.tsv"
elif [ -f "$DEBDIR/copyright.in" ]; then
    python3 -I "$PK/werkzeuge/copyright-erzeugen.py" "$DEBDIR/copyright.in" - "$DEBDIR/copyright"
fi
(cd "$AUSGABE/orig" && sha256sum "$ORIG" $([ "$VENDOR" = ja ] && echo "$ORIG_VENDOR")) | tee "$AUSGABE/orig/$SRC.sha256"
