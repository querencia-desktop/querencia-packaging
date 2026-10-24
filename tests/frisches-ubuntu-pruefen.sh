#!/bin/bash
# Prüfskript für die Test-VM (NICHT für den Entwicklungsrechner). Ändert nichts
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
    # 19. Paket (G2-F3): Archiv
    if dpkg -s querencia-archiv >/dev/null 2>&1; then
        ok "installiert: querencia-archiv $(dpkg-query -W -f='${Version}' querencia-archiv)"
        desktop-file-validate /usr/share/applications/org.querencia.Archiv.desktop >/dev/null 2>&1 &&
            ok "D org.querencia.Archiv.desktop" || nok "D org.querencia.Archiv.desktop"
    else
        echo "HINW querencia-archiv nicht im Paketsatz"
    fi
    grep -q '^Categories=.*Graphics' /usr/share/applications/org.querencia.Bilder.desktop &&
        ok "B3 Bilder im Menü Grafik" || echo "HINW B3 Bilder ohne Categories Graphics (unter Zubehör)"
    # QD-074: Sitzungswerkzeuge nur in X-Querencia, keine nackte labwc-Sitzung
    for d in org.querencia.Screenshot org.querencia.Einstellungen org.querencia.Kuerzel org.querencia.Lautstaerke org.querencia.Sitzung org.querencia.Benachrichtigungen; do
        grep -qx 'OnlyShowIn=X-Querencia;' /usr/share/applications/$d.desktop && ok "K3 $d nur in Querencia" || nok "K3 $d ohne OnlyShowIn"
    done
    [ ! -e /usr/share/wayland-sessions/labwc.desktop ] && ok "K6 keine labwc.desktop" || nok "K6 labwc.desktop vorhanden"
    grep -qx 'GSK_DEBUG=full-redraw' /etc/querencia/labwc/environment && ok "QD-070 GSK_DEBUG in der Vorgabe" || nok "QD-070 GSK_DEBUG fehlt"
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
    # Alpha 2: dunkle Fassung des Themas, Symbole 0.7, Files ohne Update-Prüfer, Terminal mit Reitern
    [ -f /usr/share/themes/Querencia-Klassisch/gtk-3.0/gtk-dark.css ] && [ -f /usr/share/themes/Querencia-Klassisch/gtk-4.0/gtk-dark.css ] &&
        ok "A2 Thema mit gtk-dark.css (GTK 3, 4)" || nok "A2 gtk-dark.css fehlt"
    n=$(find /usr/share/icons/Querencia -type f 2>/dev/null | wc -l)
    [ "$n" -eq 715 ] && [ -f /usr/share/icons/Querencia/scalable/places/user-desktop.svg ] &&
        ok "A2 Symbolthema 0.7: $n Dateien, user-desktop" || nok "A2 Symbolthema: $n Dateien statt 715"
    ! grep -a -q 'api\.github\.com' /usr/bin/querencia-files && ok "A2 Files ohne GitHub-Update-Abfrage" || nok "A2 Files nennt api.github.com"
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' querencia-terminal)" ge 0.3.0 && ok "A2 Terminal mit Reitern (>= 0.3.0)" || nok "A2 Terminal < 0.3.0"
    # 17 aus querencia-shell, dazu 32 aus querencia-hintergruende (Alpha 2)
    soll=17; dpkg -s querencia-hintergruende >/dev/null 2>&1 && soll=49
    n=$(ls /usr/share/querencia/hintergruende/*.png 2>/dev/null | wc -l)
    [ "$n" -eq "$soll" ] && [ -f /usr/share/querencia/hintergruende/querencia-blau.png ] &&
        ok "Hintergründe: $n" || nok "Hintergründe: $n statt $soll"
    [ "$soll" = 17 ] || { [ -f /usr/share/querencia/hintergruende/querencia-tiefblau.png ] &&
        ok "A2 Standardbild querencia-tiefblau.png" || nok "A2 querencia-tiefblau.png fehlt"; }
    pc=/usr/share/xdg-desktop-portal/x-querencia-portals.conf
    grep -qx 'default=gtk' "$pc" 2>/dev/null && grep -qx 'org.freedesktop.impl.portal.Secret=gnome-keyring' "$pc" &&
        ! grep -q '\*' <(grep -v '^#' "$pc") &&
        ok "B6/QD-077 Portal-Konfiguration X-Querencia (default=gtk, Secret, ohne *)" || nok "B6/QD-077 x-querencia-portals.conf: $(grep -v '^#' "$pc" 2>/dev/null | tr '\n' ' ')"
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
    # Startprotokoll vor dem Prüfpunkt „zweiter Start verweigert“ sichern: der
    # verweigerte Zweitstart rotiert sitzung-start.log (F3-9).
    START_LOG=$OUT/sitzung-start.vor-zweitstart.log
    cp "$HOME/.local/state/querencia/sitzung-start.log" "$START_LOG" 2>/dev/null
    # Ab querencia-session 0.1.0~alpha7-3 läuft das Panel unter seiner
    # Überwachung: ein Wachhund "querencia-panel --ueberwacht" und genau ein
    # Panel ohne Argumente; ältere Sitzungen haben nur das Panel.
    panels=$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?querencia-panel\$")
    wachhund=$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?querencia-panel --ueberwacht\$")
    if [ "$panels" = 1 ] && [ "$wachhund" -le 1 ]; then
        ok "H genau ein Panel$([ "$wachhund" = 1 ] && echo " (unter Überwachung)")"
    else
        nok "H Panel-Anzahl ($panels Panel, $wachhund Wachhund)"
    fi
    [ "$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?querencia-desktop( |\$)")" = 1 ] && ok "I genau ein Desktop" || nok "I Desktop-Anzahl"
    # Ausgabe erst sammeln: unter pipefail zählte sonst der Exit 1 der Verweigerung.
    zweit=$(querencia-session 2>&1)
    grep -q 'läuft bereits' <<<"$zweit" && ok "H zweiter Start verweigert" || nok "zweiter Start"
    echo "$XDG_CURRENT_DESKTOP" | grep -q X-Querencia && ok "XDG_CURRENT_DESKTOP=X-Querencia" || nok "XDG_CURRENT_DESKTOP"
    [ "$(xdg-mime query default inode/directory)" = io.github.lgse.Strata.desktop ] && ok "Ordnerprogramm in der Sitzung" || nok "Ordnerprogramm"
    [ "$(xdg-mime query default text/plain)" = org.querencia.Editor.desktop ] && ok "Textprogramm in der Sitzung" || nok "Textprogramm"
    [ "$(xdg-mime query default image/png)" = org.querencia.Bilder.desktop ] && ok "Bildprogramm in der Sitzung" || nok "Bildprogramm"
    [ "$(xdg-mime query default application/zip)" = org.querencia.Archiv.desktop ] && ok "K5 Archivprogramm in der Sitzung" || nok "K5 Archivprogramm: $(xdg-mime query default application/zip)"
    [ "$(xdg-mime query default image/svg+xml)" = org.querencia.Bilder.desktop ] && ok "K5 SVG mit Bilder" || nok "K5 SVG: $(xdg-mime query default image/svg+xml)"
    for x in querencia-polkit-agent querencia-benachrichtigungen; do
        [ "$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?$x( |\$)")" = 1 ] && ok "$x läuft" || nok "$x läuft nicht"
    done
    pgrep -u "$(id -u)" -f "^(/usr/bin/)?querencia-sitzung --leerlauf" >/dev/null && ok "Leerlaufsperre läuft" || nok "Leerlaufsperre"
    for x in panel desktop labwc; do
        grep -q -E '/home/[^/]+/(projects|opt)/' "$HOME/.local/state/querencia/$x.log" 2>/dev/null &&
            nok "Entwicklerpfad in $x.log" || ok "kein Entwicklerpfad in $x.log"
    done
    # G2-F3: Sitzungsstarter 0.1.0~alpha4 (QD-062, QD-064, G2-AG)
    S=$HOME/.local/state/querencia
    labwc_pid=$(pgrep -u "$(id -u)" -x labwc | head -1)
    tr '\000' ' ' <"/proc/$labwc_pid/cmdline" | grep -q -- "-C $HOME/.config/querencia/labwc" &&
        ok "labwc liest die Benutzerkopie" || nok "labwc liest nicht die Benutzerkopie: $(tr '\000' ' ' <"/proc/$labwc_pid/cmdline")"
    [ -f "$HOME/.config/querencia/labwc/.vorgabe/stand" ] && ok "Benutzerkopie mit .vorgabe/stand" || nok "Benutzerkopie ohne .vorgabe"
    grep -q 'Aktivierungsumgebung gesetzt' "$START_LOG" && ok "Starter: Aktivierungsumgebung gesetzt" || nok "Starter: keine Aktivierungsumgebung"
    grep -q 'Portale .*(vor dem Start' "$START_LOG" && ok "Starter: Portale vor dem Start zurückgesetzt" || nok "Starter: kein Portal-Reset"
    portal=$(grep -o 'Settings-Portal antwortet nach [0-9]* ms' "$START_LOG" | tail -1)
    [ -n "$portal" ] && ok "autostart: $portal" || nok "autostart: Portal antwortet nicht ($(grep 'Settings-Portal' "$START_LOG" | tail -1))"
    akt=$(systemctl --user show-environment)
    want_lang=$(tr '\000' '\n' <"/proc/$labwc_pid/environ" | sed -n 's/^LANG=//p')
    grep -qx "LANG=$want_lang" <<<"$akt" && ok "QD-064 Aktivierungsumgebung LANG=$want_lang" || nok "QD-064 LANG: $(grep '^LANG=' <<<"$akt") statt $want_lang"
    grep -qx 'XDG_CURRENT_DESKTOP=X-Querencia' <<<"$akt" && ok "QD-064 Aktivierungsumgebung X-Querencia" || nok "QD-064 XDG_CURRENT_DESKTOP"
    xdp=$(pgrep -u "$(id -u)" -f '^(/usr/libexec/)?xdg-desktop-portal( |$)' | head -1)
    [ -n "$xdp" ] && tr '\000' '\n' <"/proc/$xdp/environ" | grep -qx "LANG=$want_lang" &&
        ok "Portal läuft mit LANG=$want_lang" || nok "Portal-Locale: $(tr '\000' '\n' <"/proc/$xdp/environ" 2>/dev/null | grep '^LANG=')"
    # QD-077: Settings-Portal antwortet in unter 1 s (gemessen nach der Anmeldung)
    t0=$(date +%s%N)
    busctl --user --timeout=10 call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
        org.freedesktop.portal.Settings ReadOne ss org.gnome.desktop.interface gtk-theme >/dev/null 2>&1; rc=$?
    ms=$((($(date +%s%N) - t0) / 1000000))
    [ "$rc" = 0 ] && [ "$ms" -lt 1000 ] && ok "QD-077 Settings.ReadOne antwortet in $ms ms" || nok "QD-077 Settings.ReadOne rc=$rc nach $ms ms"
    # Alpha 2: Dunkelmodus über das Settings-Portal umschaltbar (wie Einstellungen → dunkle Darstellung)
    vorher_cs=$(gsettings get org.gnome.desktop.interface color-scheme)
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark; sleep 1
    d=$(busctl --user --timeout=10 call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
        org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance color-scheme 2>/dev/null)
    gsettings set org.gnome.desktop.interface color-scheme default; sleep 1
    h=$(busctl --user --timeout=10 call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
        org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance color-scheme 2>/dev/null)
    gsettings set org.gnome.desktop.interface color-scheme "$vorher_cs"
    [ "$d" = "v u 1" ] && [ "$h" = "v u 0" ] && ok "A2 Dunkelmodus umschaltbar (Portal: dunkel 1, Standard 0)" || nok "A2 Dunkelmodus: dunkel='$d' standard='$h'"
    seit=$(sed -n '1s/^# Querencia-Sitzung \([0-9-]* [0-9:]*\).*/\1/p' "$START_LOG")
    fb=$(journalctl --user -u xdg-desktop-portal.service --since "$seit" 2>/dev/null | grep -c 'last-resort fallback')
    [ "$fb" = 0 ] && ok "B6 xdg-desktop-portal ohne last-resort fallback seit $seit" || nok "B6 $fb× last-resort fallback"
    panel_pid=$(pgrep -u "$(id -u)" -f "^(/usr/bin/)?querencia-panel( |\$)" | head -1)
    tr '\000' '\n' <"/proc/$panel_pid/environ" | grep -qx 'GSK_DEBUG=full-redraw' && ok "QD-070 Panel mit GSK_DEBUG=full-redraw" || nok "QD-070 GSK_DEBUG fehlt im Panel"
    tr '\000' '\n' <"/proc/$panel_pid/environ" | grep -q '^GDK_DEBUG=.*no-portals' && echo "HINW Panel ohne Portal gestartet (no-portals)" || ok "Panel mit Portal gestartet"
    # Zeiten: Start der Prozesse in Takten seit Boot, relativ zu labwc
    tick=$(getconf CLK_TCK)
    st() { set -- $(sed 's/^.*) //' "/proc/$1/stat"); echo "${20}"; }
    l=$(st "$labwc_pid")
    for x in panel desktop; do
        q=$(pgrep -u "$(id -u)" -f "^(/usr/bin/)?querencia-$x( |\$)" | head -1)
        [ -n "$q" ] && echo "ZEIT querencia-$x startet $(( ($(st "$q") - l) * 1000 / tick )) ms nach labwc"
    done
    grep -h 'Settings-Portal antwortet\|no-portals\|Ersatz' "$S/panel.log" "$S/desktop.log" 2>/dev/null | tail -4 | sed 's/^/LOG /'
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
