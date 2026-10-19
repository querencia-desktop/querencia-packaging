#!/bin/bash
# Für die Paketierung: installiert die MetaInfo-Datei EINER Komponente nach
# $DESTDIR/usr/share/metainfo/ – zum Aufruf aus debian/rules (Ziel
# querencia-install) jedes Querencia-Pakets, damit „jedes Querencia-Paket
# liefert eine gültige MetaInfo-Datei“ (pakete-pruefen.sh, Regel M) erfüllt ist.
#
#   bash metainfo-paket-installieren.sh <Komponenten-ID> [<Komponenten-ID>…]
#   Umgebung: DESTDIR (Pflicht), QS_METAINFO_QUELLE (Standard: Ordner dieses Skripts)
#
# Beispiel in debian/rules von querencia-shell (zwei Komponenten):
#   bash debian/metainfo-paket-installieren.sh org.querencia.Desktop org.querencia.Panel
# Beispiel querencia-software:
#   bash debian/metainfo-paket-installieren.sh org.querencia.Software
#
# Die Datei wird vor dem Installieren mit appstreamcli validate --no-net
# geprüft (Pedantisches wird nicht gewertet, Warnungen brechen ab). Der
# <pkgname> muss zum Paketnamen passen, wenn QS_PAKETNAME gesetzt ist.
set -euo pipefail
HIER=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
QUELLE=${QS_METAINFO_QUELLE:-$HIER}
[ -n "${DESTDIR:-}" ] || { echo "DESTDIR fehlt" >&2; exit 2; }
[ $# -ge 1 ] || { echo "Aufruf: DESTDIR=… $0 <Komponenten-ID>…" >&2; exit 2; }
for id in "$@"; do
    f=$QUELLE/$id.metainfo.xml
    [ -f "$f" ] || { echo "MetaInfo fehlt: $f" >&2; exit 1; }
    if command -v appstreamcli >/dev/null; then
        aus=$(appstreamcli validate --no-net "$f" 2>&1) || { echo "$aus" >&2; echo "ungültig: $f" >&2; exit 1; }
    else
        echo "Hinweis: appstreamcli fehlt (Build-Depends: appstream) – ohne Validierung installiert" >&2
    fi
    if [ -n "${QS_PAKETNAME:-}" ]; then
        pkg=$(sed -n 's|^ *<pkgname>\(.*\)</pkgname>|\1|p' "$f" | head -1)
        [ "$pkg" = "$QS_PAKETNAME" ] || { echo "pkgname $pkg ≠ Paket $QS_PAKETNAME in $f" >&2; exit 1; }
    fi
    install -D -m 0644 "$f" "$DESTDIR/usr/share/metainfo/$id.metainfo.xml"
    echo "installiert: /usr/share/metainfo/$id.metainfo.xml"
done
