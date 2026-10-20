#!/bin/bash
# Prüfskript für die Test-VM (NICHT für die Entwicklungs-VM). Ändert nichts
# außer der Ablage seiner Ergebnisse in ./querencia-test/.
#   vorher | nachher | sitzung | entfernt
set -uo pipefail
OUT=./querencia-test; mkdir -p "$OUT"
p=0 f=0
ok() { p=$((p + 1)); echo "PASS $*"; }
nok() { f=$((f + 1)); echo "FAIL $*"; }
# Anmeldebildschirm-Zustand: Dienst plus Prüfsummen der Konfigurationsdateien
# (kein ls -la: dessen Zeile ".." ändert sich mit jeder Installation in /etc).
dm_zustand() {
    systemctl is-enabled display-manager 2>&1 || true
    find /etc/greetd /etc/gdm3 -type f -exec sha256sum {} + 2>/dev/null | sort -k2 || true
}
case ${1-} in
vorher)
    dpkg -l >"$OUT/dpkg-vorher.txt"
    systemctl get-default >"$OUT/target-vorher.txt"
    dm_zustand >"$OUT/dm-vorher.txt"
    ls /dev/dri/card* >/dev/null 2>&1 && ok "lokale Grafik vorhanden" || echo "HINW keine /dev/dri/card* (Prüfung Q)"
    # vorher läuft mit sudo, die übrigen Schritte als Benutzer: Ablage zurückgeben.
    [ -n "${SUDO_UID-}" ] && chown -R "$SUDO_UID:$SUDO_GID" "$OUT"
    ;;
nachher)
    dpkg -l >"$OUT/dpkg-nachher.txt"
    for x in querencia-desktop querencia-session querencia-shell querencia-symbole querencia-sitzung \
        querencia-benachrichtigungen querencia-einstellungen querencia-files querencia-terminal \
        querencia-screenshot querencia-editor querencia-bilder querencia-rechner querencia-systemmonitor \
        querencia-dateisuche querencia-software labwc; do
        dpkg -s "$x" >/dev/null 2>&1 && ok "installiert: $x $(dpkg-query -W -f='${Version}' $x)" || nok "fehlt: $x"
    done
    # 18. Paket: Pflicht, sobald es im Paketsatz liegt (Recommends des Metapakets)
    if dpkg -s querencia-dokumente >/dev/null 2>&1; then
        ok "installiert: querencia-dokumente $(dpkg-query -W -f='${Version}' querencia-dokumente)"
        desktop-file-validate /usr/share/applications/org.querencia.Dokumente.desktop >/dev/null 2>&1 &&
            ok "D org.querencia.Dokumente.desktop" || nok "D org.querencia.Dokumente.desktop"
    else
        echo "HINW querencia-dokumente nicht im Paketsatz"
    fi
    v=$(labwc --version | awk '{print $2}'); dpkg --compare-versions "$v" ge 0.9.4 && ok "labwc $v" || nok "labwc $v < 0.9.4"
    for d in io.github.lgse.Strata org.querencia.Terminal org.querencia.Screenshot org.querencia.Editor \
        org.querencia.Bilder org.querencia.Rechner org.querencia.Systemmonitor org.querencia.Dateisuche \
        org.querencia.Einstellungen org.querencia.Software org.querencia.Sitzung org.querencia.Kuerzel \
        org.querencia.Lautstaerke; do
        desktop-file-validate /usr/share/applications/$d.desktop >/dev/null 2>&1 && ok "D $d.desktop" || nok "D $d.desktop"
    done
    n=$(ls /usr/share/metainfo/ 2>/dev/null | grep -c -E '^(org\.querencia|org\.example\.Querencia|io\.github\.lgse\.Strata)')
    [ "$n" -ge 14 ] && ok "MetaInfo: $n Querencia-Komponenten" || nok "MetaInfo: nur $n von 14"
    [ ! -e /usr/share/icons/hicolor/48x48/apps/org.querencia.Bilder.png ] && ok "Symbolregel: kein 48x48 neben SVG" || nok "Symbolregel"
    [ -s /usr/share/locale/de/LC_MESSAGES/querencia-editor.mo ] && ok "Editor: deutscher Katalog" || nok "Editor: de.mo fehlt"
    n=$(ls /usr/share/locale/de/LC_MESSAGES/ 2>/dev/null | grep -c '^querencia-.*\.mo$')
    [ "$n" -ge 10 ] && ok "deutsche Kataloge: $n" || nok "deutsche Kataloge: nur $n von 10"
    [ -f /usr/share/icons/Querencia/index.theme ] && ok "Symbolthema Querencia" || nok "Symbolthema Querencia fehlt"
    [ -f /usr/share/themes/Querencia-Klassisch/gtk-4.0/gtk.css ] && [ -f /usr/share/themes/Querencia-Klassisch/labwc/themerc ] &&
        ok "Thema Querencia-Klassisch (GTK 4, labwc)" || nok "Thema Querencia-Klassisch unvollständig"
    n=$(ls /usr/share/querencia/hintergruende/*.png 2>/dev/null | wc -l)
    [ "$n" -eq 17 ] && ok "Hintergründe: 17" || nok "Hintergründe: $n statt 17"
    grep -q '^default=gtk' /usr/share/xdg-desktop-portal/x-querencia-portals.conf 2>/dev/null &&
        ok "B6 Portal-Konfiguration X-Querencia" || nok "B6 x-querencia-portals.conf fehlt"
    [ "$(XDG_CURRENT_DESKTOP=X-Querencia GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface gtk-theme)" = "'Querencia-Klassisch'" ] &&
        ok "B7 Erscheinungsbild nur in X-Querencia" || nok "B7 gschema-Override wirkt nicht"
    [ "$(XDG_CURRENT_DESKTOP=GNOME GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface gtk-theme)" != "'Querencia-Klassisch'" ] &&
        ok "B7 andere Desktops unverändert" || nok "B7 Override wirkt auch außerhalb von X-Querencia"
    command -v notify-send >/dev/null && ok "B5 notify-send vorhanden" || echo "HINW notify-send fehlt (Recommends libnotify-bin nicht installiert)"
    [ -f /usr/share/wayland-sessions/querencia.desktop ] && ok "F Sitzungsdatei" || nok "F Sitzungsdatei"
    querencia-session --check && ok "G querencia-session --check" || nok "G --check"
    diff <(grep -E 'gdm|sddm|lightdm|greetd' "$OUT/dpkg-vorher.txt" | awk '{print $2}') \
         <(grep -E 'gdm|sddm|lightdm|greetd' "$OUT/dpkg-nachher.txt" | awk '{print $2}') >/dev/null &&
        ok "P kein Anmeldebildschirm hinzugefügt/entfernt" || nok "P Anmeldebildschirm verändert"
    dm_zustand | diff - "$OUT/dm-vorher.txt" >/dev/null &&
        ok "P Anmeldebildschirm-Konfiguration unverändert" || nok "P Anmeldebildschirm-Konfiguration verändert"
    find /home -newer "$OUT/dpkg-vorher.txt" -path '*querencia*' 2>/dev/null | grep -v "$OUT" | grep -q . &&
        nok "N Paket hat in /home geschrieben" || ok "N nichts in /home angelegt"
    ;;
sitzung)
    [ "$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?querencia-panel( |\$)")" = 1 ] && ok "H genau ein Panel" || nok "H Panel-Anzahl"
    [ "$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?querencia-desktop( |\$)")" = 1 ] && ok "I genau ein Desktop" || nok "I Desktop-Anzahl"
    # Ausgabe erst sammeln: unter pipefail zählte sonst der Exit 1 der Verweigerung.
    zweit=$(querencia-session 2>&1)
    grep -q 'läuft bereits' <<<"$zweit" && ok "H zweiter Start verweigert" || nok "zweiter Start"
    echo "$XDG_CURRENT_DESKTOP" | grep -q X-Querencia && ok "XDG_CURRENT_DESKTOP=X-Querencia" || nok "XDG_CURRENT_DESKTOP"
    [ "$(xdg-mime query default inode/directory)" = io.github.lgse.Strata.desktop ] && ok "Ordnerprogramm in der Sitzung" || nok "Ordnerprogramm"
    [ "$(xdg-mime query default text/plain)" = org.querencia.Editor.desktop ] && ok "Textprogramm in der Sitzung" || nok "Textprogramm"
    [ "$(xdg-mime query default image/png)" = org.querencia.Bilder.desktop ] && ok "Bildprogramm in der Sitzung" || nok "Bildprogramm"
    for x in querencia-polkit-agent querencia-benachrichtigungen; do
        [ "$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?$x( |\$)")" = 1 ] && ok "$x läuft" || nok "$x läuft nicht"
    done
    pgrep -u "$(id -u)" -f "^(/usr/bin/)?querencia-sitzung --leerlauf" >/dev/null && ok "Leerlaufsperre läuft" || nok "Leerlaufsperre"
    for x in panel desktop labwc; do
        grep -q -E '/home/[^/]+/(projects|opt)/' "$HOME/.local/state/querencia/$x.log" 2>/dev/null &&
            nok "Entwicklerpfad in $x.log" || ok "kein Entwicklerpfad in $x.log"
    done
    echo "Weiter von Hand nach docs/pflichtprobe-frische-vm.md, Abschnitt 6 (Prüfliste)"
    ;;
entfernt)
    [ -d "$HOME/.config/querencia" ] || [ -d "$HOME/.local/state/querencia" ] && ok "N Benutzerdaten erhalten" || echo "HINW keine Benutzerdaten angelegt"
    dpkg -l | grep -q '^ii  querencia' && nok "Pakete noch installiert" || ok "Pakete entfernt"
    ;;
*) echo "Aufruf: $0 vorher|nachher|sitzung|entfernt" >&2; exit 2 ;;
esac
echo "Ergebnis: $p PASS, $f FAIL"
[ $f -eq 0 ]
