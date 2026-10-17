#!/bin/bash
# Baut ein Quellpaket und sein Binärpaket mit dpkg-buildpackage (unsigniert):
# entpackt die Archive aus orig-erzeugen.sh, legt debian/ aus diesem
# Repository dazu und ruft dpkg-buildpackage -us -uc in einer Umgebung ohne
# Sitzung (kein WAYLAND_DISPLAY, kein D-Bus, nur /usr/bin). Hält dabei den
# gemeinsamen Build-Lock und baut mit höchstens $JOBS Cargo-Jobs.
#
#   bash werkzeuge/paket-bauen.sh <quellpaket> [weitere dpkg-buildpackage-Optionen]
#
# Ergebnis: $AUSGABE/bau/<src>/*.deb, *.dsc, *.changes, *.buildinfo; Log in
# $NACHWEIS/logs/bau-<src>.log.
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/gemeinsam.sh"
[ $# -ge 1 ] || die "Aufruf: $0 <quellpaket> [dpkg-buildpackage-Optionen]"
quelle "$1"; shift
BAU=$AUSGABE/bau/$SRC
[ -f "$AUSGABE/orig/$ORIG" ] || die "$ORIG fehlt (erst werkzeuge/orig-erzeugen.sh $SRC)"
if [ -d "$BAU" ]; then chmod -R u+w "$BAU"; rm -rf "$BAU"; fi
mkdir -p "$BAU" "$NACHWEIS/logs"
cp "$AUSGABE/orig/$ORIG" "$BAU/"
tar -xf "$BAU/$ORIG" -C "$BAU"
if [ "$VENDOR" = ja ]; then
    cp "$AUSGABE/orig/$ORIG_VENDOR" "$BAU/"
    tar -xf "$BAU/$ORIG_VENDOR" -C "$BAU/$DIR"
fi
[ ! -e "$BAU/$DIR/debian" ] || die "Upstream enthält bereits debian/"
cp -a "$DEBDIR" "$BAU/$DIR/debian"
cp "$PK/common/querencia.mk" "$BAU/$DIR/debian/querencia.mk"
chmod 0755 "$BAU/$DIR/debian/rules"
LOGF=$NACHWEIS/logs/bau-$SRC.log
log "dpkg-buildpackage $SRC (Log: $LOGF)"
(
    cd "$BAU/$DIR"
    sauber DEB_BUILD_OPTIONS="parallel=$JOBS ${DEB_BUILD_OPTIONS:-}" ${DEB_BUILD_PROFILES:+DEB_BUILD_PROFILES="$DEB_BUILD_PROFILES"} \
        HOME="$BAU/home" flock "$BUILD_LOCK" dpkg-buildpackage -us -uc "$@"
) >"$LOGF" 2>&1 || { tail -40 "$LOGF" >&2; die "Bau von $SRC fehlgeschlagen"; }
ls -l "$BAU"/*.deb
