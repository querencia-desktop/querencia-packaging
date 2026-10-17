#!/bin/bash
# Prüfskript für die Test-VM (NICHT für die Entwicklungs-VM). Ändert nichts
# außer der Ablage seiner Ergebnisse in ./querencia-test/.
#   vorher | nachher | sitzung | entfernt
set -uo pipefail
OUT=./querencia-test; mkdir -p "$OUT"
p=0 f=0
ok() { p=$((p + 1)); echo "PASS $*"; }
nok() { f=$((f + 1)); echo "FAIL $*"; }
case ${1-} in
vorher)
    dpkg -l >"$OUT/dpkg-vorher.txt"
    systemctl get-default >"$OUT/target-vorher.txt"
    (systemctl is-enabled display-manager 2>&1; ls -la /etc/greetd /etc/gdm3 2>&1) >"$OUT/dm-vorher.txt"
    ls /dev/dri/card* >/dev/null 2>&1 && ok "lokale Grafik vorhanden" || echo "HINW keine /dev/dri/card* (Prüfung Q)"
    ;;
nachher)
    dpkg -l >"$OUT/dpkg-nachher.txt"
    for x in querencia-desktop querencia-session querencia-shell querencia-files querencia-terminal querencia-screenshot labwc; do
        dpkg -s "$x" >/dev/null 2>&1 && ok "installiert: $x $(dpkg-query -W -f='${Version}' $x)" || nok "fehlt: $x"
    done
    v=$(labwc --version | awk '{print $2}'); dpkg --compare-versions "$v" ge 0.9.4 && ok "labwc $v" || nok "labwc $v < 0.9.4"
    for d in io.github.lgse.Strata org.example.Querencia.Terminal org.querencia.Screenshot; do
        desktop-file-validate /usr/share/applications/$d.desktop >/dev/null 2>&1 && ok "D $d.desktop" || nok "D $d.desktop"
    done
    [ -f /usr/share/wayland-sessions/querencia.desktop ] && ok "F Sitzungsdatei" || nok "F Sitzungsdatei"
    querencia-session --check && ok "G querencia-session --check" || nok "G --check"
    diff <(grep -E 'gdm|sddm|lightdm|greetd' "$OUT/dpkg-vorher.txt" | awk '{print $2}') \
         <(grep -E 'gdm|sddm|lightdm|greetd' "$OUT/dpkg-nachher.txt" | awk '{print $2}') >/dev/null &&
        ok "P kein Anmeldebildschirm hinzugefügt/entfernt" || nok "P Anmeldebildschirm verändert"
    (systemctl is-enabled display-manager 2>&1; ls -la /etc/greetd /etc/gdm3 2>&1) | diff - "$OUT/dm-vorher.txt" >/dev/null &&
        ok "P Anmeldebildschirm-Konfiguration unverändert" || nok "P Anmeldebildschirm-Konfiguration verändert"
    find /home -newer "$OUT/dpkg-vorher.txt" -path '*querencia*' 2>/dev/null | grep -v "$OUT" | grep -q . &&
        nok "N Paket hat in /home geschrieben" || ok "N nichts in /home angelegt"
    ;;
sitzung)
    [ "$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?querencia-panel( |\$)")" = 1 ] && ok "H genau ein Panel" || nok "H Panel-Anzahl"
    [ "$(pgrep -c -u "$(id -u)" -f "^(/usr/bin/)?querencia-desktop( |\$)")" = 1 ] && ok "I genau ein Desktop" || nok "I Desktop-Anzahl"
    querencia-session 2>&1 | grep -q 'läuft bereits' && ok "H zweiter Start verweigert" || nok "zweiter Start"
    echo "$XDG_CURRENT_DESKTOP" | grep -q X-Querencia && ok "XDG_CURRENT_DESKTOP=X-Querencia" || nok "XDG_CURRENT_DESKTOP"
    [ "$(xdg-mime query default inode/directory)" = io.github.lgse.Strata.desktop ] && ok "Ordnerprogramm in der Sitzung" || nok "Ordnerprogramm"
    echo "J/K/L/M: Terminal, Files, Druck-Taste und Menü Zubehör von Hand prüfen, Bildschirmfotos ablegen"
    ;;
entfernt)
    [ -d "$HOME/.config/querencia" ] || [ -d "$HOME/.local/state/querencia" ] && ok "N Benutzerdaten erhalten" || echo "HINW keine Benutzerdaten angelegt"
    dpkg -l | grep -q '^ii  querencia' && nok "Pakete noch installiert" || ok "Pakete entfernt"
    ;;
*) echo "Aufruf: $0 vorher|nachher|sitzung|entfernt" >&2; exit 2 ;;
esac
echo "Ergebnis: $p PASS, $f FAIL"
[ $f -eq 0 ]
