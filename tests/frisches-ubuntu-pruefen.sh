#!/bin/bash
# Prüfskript für die Test-VM (NICHT für den Entwicklungsrechner). Ändert nichts
# außer der Ablage seiner Ergebnisse in ./querencia-test/.
#   vorher | nachher | sitzung | anmeldung | entfernt
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
        querencia-benachrichtigungen querencia-einstellungen querencia-dateien querencia-terminal \
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
    for d in org.querencia.Dateien org.querencia.Terminal org.querencia.Screenshot org.querencia.Editor \
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
    # Alpha 2.2: dunkler labwc-Rahmen, Files unter neuer ID mit Brücke, Kataloge
    # von Panel und Arbeitsfläche, Versionsdatei
    n=$(ls /usr/share/themes/Querencia-Klassisch-Dunkel/labwc 2>/dev/null | wc -l)
    [ "$n" = 17 ] && grep -q '^window.active.title.bg.color:' /usr/share/themes/Querencia-Klassisch-Dunkel/labwc/themerc &&
        ok "A22 labwc-Thema Querencia-Klassisch-Dunkel (themerc und 16 Knöpfe)" || nok "A22 Querencia-Klassisch-Dunkel: $n Dateien"
    # Alpha 3: Querencia Dateien statt Files. Eine Neuinstallation bringt
    # querencia-files nicht mit; nach einem Upgrade ist es das Übergangspaket
    # mit zwei unsichtbaren Brücken auf Dateien (ohne Strata-Programm).
    grep -qx 'MimeType=inode/directory;' /usr/share/applications/org.querencia.Dateien.desktop 2>/dev/null &&
        grep -qx 'StartupWMClass=org.querencia.Dateien' /usr/share/applications/org.querencia.Dateien.desktop &&
        ok "A3 Starter org.querencia.Dateien (Ordner)" || nok "A3 Starter org.querencia.Dateien"
    [ -f /usr/share/metainfo/org.querencia.Dateien.metainfo.xml ] && [ ! -e /usr/share/metainfo/org.querencia.Files.metainfo.xml ] &&
        [ ! -e /usr/share/metainfo/io.github.lgse.Strata.metainfo.xml ] && ok "A3 MetaInfo org.querencia.Dateien, keine von Files" || nok "A3 MetaInfo Dateien/Files"
    [ ! -e /usr/bin/querencia-files ] && [ ! -e /usr/share/querencia-files ] && ok "A3 Files ausgemustert (kein Programm, keine Paketmarke)" || nok "A3 Reste von Files"
    if dpkg -s querencia-files >/dev/null 2>&1; then
        for b in org.querencia.Files io.github.lgse.Strata; do
            b=/usr/share/applications/$b.desktop
            [ -f "$b" ] && grep -qx 'NoDisplay=true' "$b" && ! grep -q '^MimeType=' "$b" && grep -qx 'Exec=querencia-dateien %U' "$b" &&
                desktop-file-validate "$b" >/dev/null 2>&1 && ok "A3 Brücke $(basename "$b") auf Dateien" || nok "A3 Brücke $(basename "$b")"
        done
    else
        echo "HINW querencia-files nicht installiert (Neuinstallation: richtig)"
    fi
    for k in querencia-panel querencia-lautstaerke querencia-netzwerk querencia-desktop querencia-oberflaeche querencia-dateiarbeit querencia-dateien; do
        [ -s /usr/share/locale/de/LC_MESSAGES/$k.mo ] && ok "A3 Katalog $k.mo" || nok "A3 Katalog $k.mo fehlt"
    done
    grep -A2 '<keybind key="W-d">' /etc/querencia/labwc/rc.xml | grep -q -- '--dest org.querencia.Panel ' &&
        ok "A22 Super+D an org.querencia.Panel" || nok "A22 Super+D"
    echo "HINW Ausgabe: $(cat /usr/share/querencia/version 2>/dev/null || echo fehlt)"
    # Alpha 3.2: Schnatter ist optional (nicht im Metapaket); nach einem
    # Upgrade mit Webhülle 0.2.0 kommt es mit dem Übergangspaket querencia-webhuelle.
    if grep -q -x -E 'Alpha 3\.[2345]' /usr/share/querencia/version 2>/dev/null; then
        if dpkg -s querencia-schnatter 2>/dev/null | grep -qx 'Status: install ok installed'; then
            s=/usr/share/applications/org.querencia.Schnatter.desktop
            [ -x /usr/bin/querencia-schnatter ] && [ -f "$s" ] && desktop-file-validate "$s" >/dev/null 2>&1 &&
                ok "A32 Schnatter installiert (Programm, Starter)" || nok "A32 Schnatter: Programm oder Starter"
        else
            echo "HINW A32 querencia-schnatter nicht installiert (optional; Neuinstallation ohne Webhülle: richtig)"
        fi
        if dpkg -s querencia-webhuelle >/dev/null 2>&1; then
            b=/usr/share/applications/org.querencia.Webhuelle.desktop
            [ ! -e /usr/bin/querencia-webhuelle ] && grep -qx 'NoDisplay=true' "$b" && grep -qx 'Exec=querencia-schnatter' "$b" &&
                ok "A32 querencia-webhuelle ist das Übergangspaket (Brücke auf Schnatter)" || nok "A32 querencia-webhuelle"
        fi
    fi
    # Alpha 3.3: it/es/fr in allen Programmen (Kataloge, Starter), locales-all
    # als Recommends des Metapakets (bei --no-install-recommends nur Hinweis).
    if grep -q -x -E 'Alpha 3\.[345]' /usr/share/querencia/version 2>/dev/null; then
        for d in querencia-panel querencia-desktop querencia-oberflaeche querencia-dateiarbeit querencia-dateien \
            querencia-terminal querencia-screenshot querencia-editor querencia-bilder querencia-rechner \
            querencia-systemmonitor querencia-dateisuche querencia-einstellungen querencia-software querencia-sitzung \
            querencia-benachrichtigungen querencia-dokumente querencia-archiv; do
            fehlt=; for l in it es fr; do [ -s /usr/share/locale/$l/LC_MESSAGES/$d.mo ] || fehlt="$fehlt $l"; done
            [ -z "$fehlt" ] && ok "A33 Katalog $d it/es/fr" || nok "A33 Katalog $d fehlt:$fehlt"
        done
        for d in org.querencia.Dateien org.querencia.Terminal org.querencia.Editor org.querencia.Bilder \
            org.querencia.Rechner org.querencia.Software org.querencia.Einstellungen; do
            s=/usr/share/applications/$d.desktop
            # Name, GenericName oder Comment je Sprache (Software heißt in it/es „Software“)
            grep -q -E '^(Name|GenericName|Comment)\[it\]=' "$s" && grep -q -E '^(Name|GenericName|Comment)\[es\]=' "$s" &&
                grep -q -E '^(Name|GenericName|Comment)\[fr\]=' "$s" &&
                ok "A33 Starter $d it/es/fr" || nok "A33 Starter $d ohne it/es/fr"
        done
        if dpkg -s locales-all 2>/dev/null | grep -qx 'Status: install ok installed'; then
            n=$(locale -a 2>/dev/null | grep -c -i -E '^(it_IT|es_ES|fr_FR)\.utf-?8$')
            [ "$n" = 3 ] && ok "A33 locales-all: it_IT, es_ES, fr_FR vorhanden" || nok "A33 locales-all installiert, aber $n von 3 Locales"
        else
            echo "HINW A33 locales-all nicht installiert (Recommends; ohne Empfehlungen installiert?)"
        fi
        if dpkg -s querencia-schnatter 2>/dev/null | grep -qx 'Status: install ok installed'; then
            [ -s /usr/share/locale/it/LC_MESSAGES/querencia-schnatter.mo ] && ok "A33 Schnatter it" || nok "A33 Schnatter ohne it"
        fi
    fi
    # Alpha 3.4: Einstellungen 0.2.0 mit Seite und Menüeintrag „Treiber“
    # (ubuntu-drivers-common nur empfohlen), Sitzung 0.1.10 (Sperrbildschirm
    # in fünf Sprachen), Tastenkürzel-Hilfe mit it/es/fr.
    if grep -q -x -E 'Alpha 3\.[45]' /usr/share/querencia/version 2>/dev/null; then
        dpkg --compare-versions "$(dpkg-query -W -f='${Version}' querencia-einstellungen)" ge 0.2.0-1 &&
            ok "A34 Einstellungen >= 0.2.0-1" || nok "A34 Einstellungen < 0.2.0-1"
        t=/usr/share/applications/org.querencia.Einstellungen.Treiber.desktop
        [ -f "$t" ] && desktop-file-validate "$t" >/dev/null 2>&1 && grep -qx 'Exec=querencia-einstellungen --seite treiber' "$t" &&
            grep -qx 'Name\[de\]=Treiber' "$t" && [ -f /usr/share/icons/hicolor/scalable/apps/org.querencia.Einstellungen.Treiber.svg ] &&
            ok "A34 Menüeintrag „Treiber“ mit Symbol" || nok "A34 Menüeintrag „Treiber“ oder Symbol"
        if dpkg -s ubuntu-drivers-common 2>/dev/null | grep -qx 'Status: install ok installed'; then
            ok "A34 ubuntu-drivers-common installiert (Recommends)"
        else
            echo "HINW A34 ubuntu-drivers-common nicht installiert (Recommends; die Seite „Treiber“ sagt das und bietet es an)"
        fi
        dpkg --compare-versions "$(dpkg-query -W -f='${Version}' querencia-sitzung)" ge 0.1.10-1 &&
            grep -a -q 'Password errata' /usr/share/locale/it/LC_MESSAGES/querencia-sitzung.mo 2>/dev/null &&
            ok "A34 Sitzung >= 0.1.10-1, Sperrbildschirm it" || nok "A34 Sitzung < 0.1.10-1 oder Sperrbildschirm ohne it"
        fehlt=; for l in de it es fr; do [ -s /usr/share/locale/$l/LC_MESSAGES/querencia-kuerzel.mo ] || fehlt="$fehlt $l"; done
        [ -z "$fehlt" ] && ok "A34 Katalog querencia-kuerzel de/it/es/fr" || nok "A34 Katalog querencia-kuerzel fehlt:$fehlt"
        s=/usr/share/applications/org.querencia.Kuerzel.desktop
        grep -q -E '^(Name|GenericName|Comment)\[it\]=' "$s" && grep -q -E '^(Name|GenericName|Comment)\[fr\]=' "$s" &&
            ok "A34 Starter Tastenkürzel it/es/fr" || nok "A34 Starter Tastenkürzel ohne it/fr"
    fi
    # Alpha 3.5: Einstellungen 0.2.1 (Treiber-Seite: Zeile „OpenGL der Karte“,
    # Software-Darstellung mit Grund), Anmeldung 0.1.5 (Kataloge it/es/fr,
    # geprüft im Schritt anmeldung).
    if grep -q -x 'Alpha 3\.5' /usr/share/querencia/version 2>/dev/null; then
        dpkg --compare-versions "$(dpkg-query -W -f='${Version}' querencia-einstellungen)" ge 0.2.1-1 &&
            grep -a -q 'OpenGL der Karte' /usr/share/locale/de/LC_MESSAGES/querencia-einstellungen.mo 2>/dev/null &&
            ok "A35 Einstellungen >= 0.2.1-1 mit „OpenGL der Karte“" || nok "A35 Einstellungen < 0.2.1-1 oder Katalog ohne „OpenGL der Karte“"
    fi
    # Alpha 2: dunkle Fassung des Themas, Terminal mit Reitern; Symbole seit Alpha 3: 0.8
    [ -f /usr/share/themes/Querencia-Klassisch/gtk-3.0/gtk-dark.css ] && [ -f /usr/share/themes/Querencia-Klassisch/gtk-4.0/gtk-dark.css ] &&
        ok "A2 Thema mit gtk-dark.css (GTK 3, 4)" || nok "A2 gtk-dark.css fehlt"
    n=$(find /usr/share/icons/Querencia -type f 2>/dev/null | wc -l)
    [ "$n" -eq 723 ] && [ -f /usr/share/icons/Querencia/scalable/places/user-desktop.svg ] &&
        [ -f /usr/share/icons/Querencia/scalable/apps/org.querencia.Dateien.svg ] &&
        ok "A3 Symbolthema 0.8: $n Dateien, user-desktop, Dateien" || nok "A3 Symbolthema: $n Dateien statt 723"
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
    # N: nur das Zeitfenster des letzten apt-Laufs (history.log), sonst
    # zählen Sitzungslogs späterer Anmeldungen mit (QD-131, Upgrade-Läufe).
    hist=/var/log/apt/history.log
    a_start=$(awk '/^Start-Date:/ {s = $2 " " $3} END {print s}' "$hist" 2>/dev/null)
    a_ende=$(awk '/^End-Date:/ {e = $2 " " $3} END {print e}' "$hist" 2>/dev/null)
    if s_ep=$(date -d "$a_start" +%s 2>/dev/null) && e_ep=$(date -d "$a_ende" +%s 2>/dev/null) && [ "$e_ep" -ge "$s_ep" ]; then
        treffer=$(find /home -newermt "@$s_ep" ! -newermt "@$((e_ep + 1))" -path '*querencia*' 2>/dev/null | grep -v "$OUT")
        [ -z "$treffer" ] && ok "N nichts in /home angelegt (apt $a_start – $a_ende)" ||
            { nok "N Paket hat in /home geschrieben (apt $a_start – $a_ende)"; printf '%s\n' "$treffer" | head -5 | sed 's/^/     /'; }
    else
        echo "HINW N: $hist ohne lesbaren Lauf, Fenster seit vorher"
        find /home -newer "$OUT/dpkg-vorher.txt" -path '*querencia*' 2>/dev/null | grep -v "$OUT" | grep -q . &&
            nok "N Paket hat in /home geschrieben" || ok "N nichts in /home angelegt"
    fi
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
    # QD-172 T-1: Wer seine Ordnerwahl aus Files behält, hat dort eine Brücke
    # (Übergangspaket querencia-files); sie startet Dateien und gilt als PASS.
    ordner=$(xdg-mime query default inode/directory)
    case $ordner in
    org.querencia.Dateien.desktop) ok "Ordnerprogramm in der Sitzung (org.querencia.Dateien)" ;;
    io.github.lgse.Strata.desktop | org.querencia.Files.desktop)
        if grep -qx 'Exec=querencia-dateien %U' "/usr/share/applications/$ordner" 2>/dev/null; then
            ok "Ordnerprogramm in der Sitzung: Brücke $ordner startet querencia-dateien"
            echo "HINW Benutzerwahl Brücke: $ordner (aus Files behalten)"
        else
            nok "Ordnerprogramm: $ordner ohne Brücke auf querencia-dateien"
        fi ;;
    *) nok "Ordnerprogramm: $ordner" ;;
    esac
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
anmeldung)
    # Anmeldebildschirm (querencia-anmeldung, wahlweise): statische Punkte;
    # die Bildschirmtexte prüft Weg B von Hand (HAND-Zeilen, Fotos).
    if ! dpkg -s querencia-anmeldung 2>/dev/null | grep -qx 'Status: install ok installed'; then
        echo "HINW querencia-anmeldung nicht installiert (wahlweise); Punkte entfallen"
    else
        v=$(dpkg-query -W -f='${Version}' querencia-anmeldung)
        dpkg --compare-versions "$v" ge 0.1.4-1 && ok "ANM querencia-anmeldung $v (>= 0.1.4-1, de/en, Meldung bei abgelaufenem Passwort)" || nok "ANM querencia-anmeldung $v < 0.1.4-1"
        m=/usr/share/locale/de/LC_MESSAGES/querencia-anmeldung.mo
        [ -s "$m" ] && grep -a -q 'Falsches Passwort' "$m" && grep -a -q 'Ihr Passwort ist abgelaufen' "$m" &&
            ok "ANM Katalog de mit „Falsches Passwort“ und „Ihr Passwort ist abgelaufen“" || nok "ANM Katalog de fehlt oder ohne Meldungen"
        [ "$(systemctl is-enabled querencia-anmeldung.service 2>/dev/null)" = enabled ] &&
            ok "ANM Dienst querencia-anmeldung aktiv als Display-Manager" ||
            echo "HINW ANM Dienst nicht eingeschaltet (debconf-Wahl: GDM behalten); Bildschirmprüfung entfällt"
        echo "INFO ANM Systemsprache: $(grep -h -E '^(LANG|LANGUAGE)=' /etc/default/locale 2>/dev/null | tr '\n' ' ')"
        if dpkg --compare-versions "$v" ge 0.1.5-1; then
            fehlt=; for l in it es fr; do [ -s /usr/share/locale/$l/LC_MESSAGES/querencia-anmeldung.mo ] || fehlt="$fehlt $l"; done
            grep -a -q 'Password errata' /usr/share/locale/it/LC_MESSAGES/querencia-anmeldung.mo 2>/dev/null || fehlt="$fehlt it-Text"
            [ -z "$fehlt" ] && ok "ANM 0.1.5 Kataloge it/es/fr („Password errata. Riprovare.“)" || nok "ANM 0.1.5 Kataloge fehlen:$fehlt"
        fi
        for l in de en it es fr; do
            dpkg -s language-pack-gnome-$l >/dev/null 2>&1 && echo "INFO ANM language-pack-gnome-$l installiert" ||
                echo "HINW ANM language-pack-gnome-$l fehlt (GTK-eigene Texte wie „Show Text“ bleiben englisch, Grenze)"
        done
    fi
    cat <<'HAND'
HAND Ü de (LANG=de_DE.UTF-8): „Benutzer:“, „Sitzung:“, „Anmelden“, „Neu starten“, „Ausschalten“, „Passwort:“, „Abbrechen“; Uhr TT.MM.JJJJ hh:mm
HAND Ü de falsches Passwort: „Falsches Passwort. Bitte erneut versuchen.“
HAND Ü en (sudo localectl set-locale LANG=en_US.UTF-8, Anmeldebildschirm neu): „User:“, „Session:“, „Login“, „Reboot“, „Power Off“, „Password:“, „Wrong password. Please try again.“; Uhr MM/TT/JJJJ
HAND Ü7 Sitzungsname: /usr/local/share/wayland-sessions/probe.desktop mit Name=Test session und Name[de]=Testsitzung, freigeben = probe → de „Testsitzung“, en „Test session“
HAND Ü8 abgelaufenes Passwort: sudo passwd -e probe, mit dem alten Passwort anmelden → de „Ihr Passwort ist abgelaufen. Bitte wählen Sie ein neues.“ und „Dazu an der Textkonsole anmelden (Strg+Alt+F1); Strg+Alt+F7 führt hierher zurück.“, nach 10 s noch sichtbar, kein „NEW_AUTHTOK_REQD“; Strg+Alt+F1, login als probe (altes, zweimal neues Passwort), abmelden, Strg+Alt+F7, mit dem neuen Passwort anmelden → Sitzung startet
HAND Ü8 en: „Your password has expired. Please choose a new one.“ und „To do so, log in on the text console (Ctrl+Alt+F1); Ctrl+Alt+F7 brings you back here.“
HAND Ü10 it (ab 0.1.5; sudo localectl set-locale LANG=it_IT.UTF-8, Neustart): „Utente:“, „Sessione:“, „Accedi“, „Riavvia“, „Spegni“; Uhr TT/MM/JJJJ hh:mm; falsches Passwort „Password errata. Riprovare.“; Ü8 it: „La password è scaduta. Sceglierne una nuova.“ und „Per farlo, accedere alla console testuale (Ctrl+Alt+F1); Ctrl+Alt+F7 riporta qui.“
HAND Ü9 keine englischen Reste bei de außer Namen und GTK-Texten ohne language-pack-gnome-de; bei en kein deutsches Wort
HAND
    ;;
entfernt)
    [ -d "$HOME/.config/querencia" ] || [ -d "$HOME/.local/state/querencia" ] && ok "N Benutzerdaten erhalten" || echo "HINW keine Benutzerdaten angelegt"
    dpkg -l | grep -q '^ii  querencia' && nok "Pakete noch installiert" || ok "Pakete entfernt"
    ;;
*) echo "Aufruf: $0 vorher|nachher|sitzung|anmeldung|entfernt" >&2; exit 2 ;;
esac
echo "Ergebnis: $p PASS, $f FAIL"
[ $f -eq 0 ]
