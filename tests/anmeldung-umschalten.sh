#!/bin/bash
# Prüft die Display-Manager-Umschaltung von querencia-anmeldung (config,
# postinst, prerm, postrm aus querencia-anmeldung/debian/) ohne root und
# ohne das laufende System anzufassen: jede Szene bekommt eine
# Wegwerf-Wurzel (DPKG_ROOT) mit eigener debconf-Datenbank; gdm3 wird durch
# seine debconf-Vorlage, /etc/X11/default-display-manager und den Link
# display-manager.service nachgestellt.
#
#   bash tests/anmeldung-umschalten.sh [<ausgabeordner>]
#
# Antworten auf die debconf-Frage gibt die Editor-Oberfläche von debconf
# (EDITOR = kleines sed-Skript). Exit 0 = alle Fälle PASS.
set -uo pipefail
PK=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
DEB=$PK/querencia-anmeldung/debian
AUS=${1:-$(mktemp -d)}
mkdir -p "$AUS"
LOG=$AUS/umschalten.log
: >"$LOG"
pass=0 fail=0
ok() { echo "PASS $*"; pass=$((pass + 1)); }
nein() { echo "FAIL $*"; fail=$((fail + 1)); }

szene() { # szene <name>: neue Wurzel und debconf-Datenbank
    W=$AUS/$1
    rm -rf "$W"
    mkdir -p "$W"/{info,info-rekonf,var/cache/debconf,etc/systemd/system,usr/lib/systemd/system,usr/sbin}
    printf '%s\n' 'Config: configdb' 'Templates: templatedb' '' \
        'Name: configdb' 'Driver: File' 'Filename: /var/cache/debconf/config.dat' '' \
        'Name: templatedb' 'Driver: File' 'Mode: 644' 'Filename: /var/cache/debconf/templates.dat' >"$W/debconf.conf"
    : >"$W/var/cache/debconf/config.dat"
    : >"$W/var/cache/debconf/templates.dat"
    for s in config postinst prerm postrm templates; do
        install -m 0755 "$DEB/querencia-anmeldung.$s" "$W/info/querencia-anmeldung.$s"
    done
    # dpkg-reconfigure ruft postinst ohne erneuten config-Lauf auf
    install -m 0755 "$DEB/querencia-anmeldung.postinst" "$DEB/querencia-anmeldung.templates" "$W/info-rekonf/"
    : >"$W/usr/lib/systemd/system/querencia-anmeldung.service"
    echo "== $1" >>"$LOG"
}

dc() { # Umgebung für debconf in der Wurzel
    env -u DEBIAN_HAS_FRONTEND -u DEBCONF_REDIR \
        DPKG_ROOT="$W" DEBCONF_SYSTEMRC=/debconf.conf DEBIAN_FRONTEND=noninteractive "$@"
}

gdm3_installieren() { # wie ein Ubuntu Desktop mit GDM (Vorlage und Wahl wie gdm3.config)
    mkdir -p "$W/gdm3"
    printf '%s\n' 'Template: gdm3/daemon_name' 'Type: string' 'Default: /usr/sbin/gdm3' \
        'Description: for internal use only' '' \
        'Template: shared/default-x-display-manager' 'Type: select' 'Choices: ${choices}' \
        'Description: Default display manager:' >"$W/gdm3/gdm3.templates"
    printf '%s\n' '#!/bin/sh' '. /usr/share/debconf/confmodule' \
        'db_metaget shared/default-x-display-manager owners' \
        'db_subst shared/default-x-display-manager choices "$RET"' \
        'db_set shared/default-x-display-manager gdm3' >"$W/gdm3/gdm3.config"
    printf '%s\n' '#!/bin/sh' 'exit 0' >"$W/gdm3/gdm3.postinst"
    chmod 0755 "$W/gdm3/gdm3.config" "$W/gdm3/gdm3.postinst"
    # die debconf-Oberfläche lädt gdm3.templates und führt gdm3.config vor gdm3.postinst aus
    (cd "$W/gdm3" && dc perl /usr/share/debconf/frontend ./gdm3.postinst configure) >>"$LOG" 2>&1
    : >"$W/usr/lib/systemd/system/gdm3.service"
    mkdir -p "$W/etc/X11"
    echo /usr/sbin/gdm3 >"$W/etc/X11/default-display-manager"
    ln -sf /usr/lib/systemd/system/gdm3.service "$W/etc/systemd/system/display-manager.service"
}

handgreetd() { # wie entwicklungs-vm: greetd.service von Hand als display-manager
    : >"$W/usr/lib/systemd/system/greetd.service"
    ln -sf /usr/lib/systemd/system/greetd.service "$W/etc/systemd/system/display-manager.service"
}

installieren() { # installieren [VAR=wert …]: Erstinstallation (dpkg ruft postinst configure)
    (cd "$W/info" && dc "$@" perl /usr/share/debconf/frontend ./querencia-anmeldung.postinst configure) >>"$LOG" 2>&1
}
aktualisieren() {
    (cd "$W/info" && dc "$@" perl /usr/share/debconf/frontend ./querencia-anmeldung.postinst configure 0.1.0-1) >>"$LOG" 2>&1
}
rekonfigurieren() { # wie dpkg-reconfigure: config reconfigure, dann postinst configure
    (cd "$W/info" && dc DEBCONF_RECONFIGURE=1 DEBCONF_PACKAGE=querencia-anmeldung "$@" perl /usr/share/debconf/frontend ./querencia-anmeldung.config reconfigure 0.1.0-1) >>"$LOG" 2>&1
    (cd "$W/info-rekonf" && dc DEBCONF_RECONFIGURE=1 "$@" perl /usr/share/debconf/frontend ./querencia-anmeldung.postinst configure 0.1.0-1) >>"$LOG" 2>&1
}
entfernen() {
    (cd "$W/info" && dc "$@" perl /usr/share/debconf/frontend ./querencia-anmeldung.prerm remove) >>"$LOG" 2>&1
    (cd "$W/info" && dc "$@" ./querencia-anmeldung.postrm remove) >>"$LOG" 2>&1
}
purgen() {
    (cd "$W/info" && dc "$@" perl /usr/share/debconf/frontend ./querencia-anmeldung.postrm purge) >>"$LOG" 2>&1
}

# Antwort über die Editor-Oberfläche
antwort() { # antwort <wert>: setzt EDITOR für die nächsten Aufrufe
    cat >"$AUS/editor.sh" <<EOF
#!/bin/sh
sed -i 's|^shared/default-x-display-manager=.*|shared/default-x-display-manager="$1"|' "\$1"
EOF
    chmod 0755 "$AUS/editor.sh"
}

dmf() { cat "$W/etc/X11/default-display-manager" 2>/dev/null; }
link() { readlink "$W/etc/systemd/system/display-manager.service" 2>/dev/null; }
erwarte() { # erwarte <fall> <dmf> <link>
    local d l
    d=$(dmf) l=$(link)
    if [ "$d" = "$2" ] && [ "$l" = "$3" ]; then ok "$1"; else nein "$1 (Datei='$d' Link='$l', erwartet '$2' '$3')"; fi
}
Q=/usr/sbin/querencia-anmeldung QL=/usr/lib/systemd/system/querencia-anmeldung.service
G=/usr/sbin/gdm3 GL=/usr/lib/systemd/system/gdm3.service

# A: frisches System ohne Display-Manager (Server-Weg)
szene a-leer
installieren
erwarte "A1 ohne Display-Manager: Querencia Anmeldung wird Standard" "$Q" "$QL"
aktualisieren
erwarte "A2 Aktualisierung ändert nichts" "$Q" "$QL"
entfernen
erwarte "A3 Entfernen: kein Display-Manager mehr (Textkonsole)" "" ""
mkdir -p "$W/run/querencia-anmeldung/wayland-sessions" "$W/var/lib/querencia-anmeldung" "$W/var/log/querencia-anmeldung"
purgen
if ! grep -q querencia-anmeldung "$W/var/cache/debconf/config.dat"; then ok "A4 purge: debconf-Einträge weg"; else nein "A4 purge: debconf-Einträge weg"; fi
if [ ! -e "$W/run/querencia-anmeldung" ] && [ ! -e "$W/var/lib/querencia-anmeldung" ] && [ ! -e "$W/var/log/querencia-anmeldung" ]; then
    ok "A5 purge: Sitzungsliste, Zustand und Protokoll weg"
else
    nein "A5 purge: Sitzungsliste, Zustand und Protokoll weg"
fi

# B: Ubuntu Desktop mit GDM, Installation ohne Antwort (noninteractive)
szene b-gdm
gdm3_installieren
installieren
erwarte "B1 GDM aktiv, ohne Wahl: GDM bleibt" "$G" "$GL"
grep -q 'gdm3 bleibt Standard-Anmeldedienst' "$LOG" && ok "B2 Hinweis auf dpkg-reconfigure" || nein "B2 Hinweis auf dpkg-reconfigure"
if grep -q 'Owners: gdm3, querencia-anmeldung' "$W/var/cache/debconf/config.dat"; then ok "B3 Frage hat beide Eigentümer"; else nein "B3 Frage hat beide Eigentümer"; fi
aktualisieren
erwarte "B4 Aktualisierung: GDM bleibt" "$G" "$GL"
entfernen
erwarte "B5 Entfernen: GDM unverändert" "$G" "$GL"

# C: GDM aktiv, Querencia Anmeldung in der Frage gewählt (Editor-Oberfläche)
szene c-gdm-wahl
gdm3_installieren
antwort querencia-anmeldung
installieren DEBIAN_FRONTEND=editor EDITOR="$AUS/editor.sh"
erwarte "C1 in der Frage gewählt: Querencia Anmeldung" "$Q" "$QL"
installieren
erwarte "C2 zweiter config-Lauf (apt: preconfigure + postinst) behält die Wahl" "$Q" "$QL"
entfernen
erwarte "C3 Entfernen: GDM wieder Standard" "$G" "$GL"

# D: GDM aktiv, QUERENCIA_ANMELDUNG=ja; Wechsel hin und zurück
szene d-gdm-umschalten
gdm3_installieren
installieren QUERENCIA_ANMELDUNG=ja
erwarte "D1 QUERENCIA_ANMELDUNG=ja: Querencia Anmeldung" "$Q" "$QL"
rekonfigurieren QUERENCIA_ANMELDUNG=nein
erwarte "D2 dpkg-reconfigure mit =nein: zurück zu GDM" "$G" "$GL"
antwort querencia-anmeldung
rekonfigurieren DEBIAN_FRONTEND=editor EDITOR="$AUS/editor.sh"
erwarte "D3 dpkg-reconfigure, Frage beantwortet: Querencia Anmeldung" "$Q" "$QL"
antwort gdm3
rekonfigurieren DEBIAN_FRONTEND=editor EDITOR="$AUS/editor.sh"
erwarte "D4 dpkg-reconfigure, gdm3 gewählt: GDM" "$G" "$GL"
rekonfigurieren
erwarte "D5 dpkg-reconfigure ohne Antwort: bleibt GDM" "$G" "$GL"
rekonfigurieren QUERENCIA_ANMELDUNG=ja
entfernen
erwarte "D6 Entfernen nach erneutem Wechsel: GDM wieder Standard" "$G" "$GL"
purgen
erwarte "D7 purge: GDM bleibt" "$G" "$GL"

# E: von Hand eingerichteter greetd (wie entwicklungs-vm)
szene e-handgreetd
handgreetd
installieren
erwarte "E1 fremder greetd ohne debconf: bleibt" "" /usr/lib/systemd/system/greetd.service
rekonfigurieren
erwarte "E2 dpkg-reconfigure: Querencia Anmeldung" "$Q" "$QL"
rekonfigurieren QUERENCIA_ANMELDUNG=nein
erwarte "E3 =nein: von Hand eingerichteter greetd wieder aktiv (Rückfall entwicklungs-vm)" "" /usr/lib/systemd/system/greetd.service
rekonfigurieren QUERENCIA_ANMELDUNG=ja
erwarte "E4 =ja: wieder Querencia Anmeldung" "$Q" "$QL"
entfernen
erwarte "E5 Entfernen: von Hand eingerichteter greetd wieder aktiv" "" /usr/lib/systemd/system/greetd.service

# F: display-manager.service maskiert
szene f-maskiert
ln -sf /dev/null "$W/etc/systemd/system/display-manager.service"
installieren QUERENCIA_ANMELDUNG=ja
erwarte "F1 maskiert: nichts geändert" "" /dev/null

# G: zurück auf die Textkonsole bleibt über Aktualisierungen
szene g-konsole
installieren
rekonfigurieren QUERENCIA_ANMELDUNG=nein
erwarte "G1 =nein ohne anderen Display-Manager: Textkonsole" "" ""
aktualisieren
erwarte "G2 Aktualisierung schaltet nicht wieder ein" "" ""

# H: GDM wird nach der Querencia Anmeldung entfernt (gdm3-prerm-Muster)
szene h-ohne-vorher
installieren
gdm3_installieren
rekonfigurieren
erwarte "H1 GDM nachinstalliert (setzt sich selbst): GDM" "$G" "$GL"
antwort querencia-anmeldung
rekonfigurieren DEBIAN_FRONTEND=editor EDITOR="$AUS/editor.sh"
entfernen
erwarte "H2 Entfernen: GDM als verbleibender Display-Manager" "$G" "$GL"

echo "ERGEBNIS: $pass PASS, $fail FAIL (Log: $LOG)"
[ "$fail" -eq 0 ]
