#!/bin/bash
# Wiederholt den automatischen Teil der Pflichtprobe auf der Wegwerf-VM 115
# (querencia-probe) auf dem Proxmox-Host: Snapshot zurückrollen, starten,
# Paketsatz übertragen, Prüfsummen, vorher, Installation, nachher. Die
# Prüfliste mit Anmeldung (docs/pflichtprobe-frische-vm.md, Abschnitt 6)
# bleibt Handarbeit; das Skript nennt am Ende die Adresse der VM.
#
#   bash werkzeuge/probe-wiederholen.sh [--desktop] [<debs-ordner>]
#
#   --desktop     nach dem Zurückrollen ubuntu-desktop-minimal (GDM, GNOME)
#                 installieren und neu starten, wie das Desktop-Abbild der
#                 Anleitung; ohne: Server-Weg, Anmeldung an tty1
#   <debs-ordner> Standard build/debs (mindestens 17 .deb, alle in SHA256SUMS)
#
# Läuft auf entwicklungs-vm, braucht den SSH-Schlüssel für root@PROBE_HOST und
# probe@<vm>. Fasst auf dem Host nur die eine VM an (Standard 115, sonst
# PROBE_VMID/PROBE_NAME/PROBE_SNAP) und prüft vorher deren Namen.
# Ergebnisse: $PROBE_AUSGABE/probe-<zeit>/ (Standard ;
# nie unter build/, das gehört dem Bau).
# Rückfall: keiner nötig; der nächste Lauf rollt den Snapshot wieder zurück.
set -euo pipefail

HOST=${PROBE_HOST:-root@192.0.2.40}
# Zweite Probe-VM parallel (Alpha 2): PROBE_VMID=116 PROBE_NAME=ubuntu-probe
# PROBE_SNAP=gnome-frisch (Ubuntu Desktop mit GDM, ohne --desktop).
VMID=${PROBE_VMID:-115}
NAME=${PROBE_NAME:-querencia-probe}
# Einziger Snapshot: ZFS rollt nur auf den jüngsten zurück.
SNAP=${PROBE_SNAP:-frisch}
DESKTOP=0
if [ "${1-}" = --desktop ]; then DESKTOP=1; shift; fi
REPO=$(cd "$(dirname "$0")/.." && pwd)
DEBS=$(cd "${1:-$REPO/build/debs}" && pwd)
OUT=${PROBE_AUSGABE:-$HOME/review/pflichtprobe-nachweis}/probe-$(date +%Y%m%d-%H%M%S)
SSH_OPT=(-o BatchMode=yes -o ConnectTimeout=10)

meld() { echo "probe-wiederholen: $*"; }
host() { ssh "${SSH_OPT[@]}" "$HOST" "$@"; }

# 17 Pakete, mit querencia-dokumente 18, mit querencia-archiv 19; jede .deb muss in SHA256SUMS stehen.
n=$(ls "$DEBS"/*.deb | wc -l)
[ "$n" -ge 17 ] && [ "$n" -eq "$(grep -c '\.deb$' "$DEBS/SHA256SUMS")" ] ||
    { meld "erwartet mindestens 17 .deb in $DEBS, jede in SHA256SUMS (gefunden: $n)"; exit 1; }
(cd "$DEBS" && sha256sum -c --quiet SHA256SUMS) || { meld "SHA256SUMS stimmt nicht"; exit 1; }

name=$(host "qm config $VMID" | awk '/^name:/ {print $2}')
[ "$name" = "$NAME" ] || { meld "VM $VMID heißt '$name', nicht $NAME; Abbruch"; exit 1; }
host "qm listsnapshot $VMID" | grep -q -- "-> $SNAP " || { meld "Snapshot $SNAP fehlt"; exit 1; }
host "free -m | awk '/^Mem/ {print \"Host: \" \$7 \" MB verfügbar\"}'"

meld "Snapshot $SNAP zurückrollen und starten"
host "qm rollback $VMID $SNAP && qm start $VMID"

meld "warte auf den Gastagenten"
ip=
for _ in $(seq 60); do
    ip=$(host "qm guest cmd $VMID network-get-interfaces 2>/dev/null" |
        grep -o '"ip-address" : "192\.168\.[0-9.]*"' | grep -o '192[0-9.]*' | head -1) && [ -n "$ip" ] && break
    sleep 5
done
[ -n "$ip" ] || { meld "keine IP vom Gastagenten"; exit 1; }
meld "VM $VMID: $ip"
VM=probe@$ip
for _ in $(seq 30); do ssh "${SSH_OPT[@]}" -o StrictHostKeyChecking=accept-new "$VM" true 2>/dev/null && break; sleep 3; done
vm() { ssh "${SSH_OPT[@]}" "$VM" "$@"; }
warte_ssh() {
    for _ in $(seq 60); do vm true 2>/dev/null && return 0; sleep 5; done
    meld "VM per SSH nicht erreichbar"; exit 1
}

mkdir -p "$OUT"
if [ "$DESKTOP" = 1 ]; then
    meld "ubuntu-desktop-minimal installieren (einige Minuten)"
    vm 'sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal' >"$OUT/apt-desktop.log" 2>&1
    alt=$(vm 'cat /proc/sys/kernel/random/boot_id')
    vm 'sudo systemctl reboot' || true
    # NetworkManager übernimmt eth0 und holt eine neue DHCP-Adresse; gilt erst,
    # wenn die VM unter dieser Adresse mit neuer boot_id antwortet.
    neu=
    for _ in $(seq 60); do
        sleep 5
        ip=$(host "qm guest cmd $VMID network-get-interfaces 2>/dev/null" |
            grep -o '"ip-address" : "192\.168\.[0-9.]*"' | grep -o '192[0-9.]*' | head -1) || continue
        boot=$(ssh "${SSH_OPT[@]}" -o StrictHostKeyChecking=accept-new "probe@$ip" 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null) || continue
        [ "$boot" != "$alt" ] && { neu=1; break; }
    done
    [ -n "$neu" ] || { meld "VM nach dem Neustart nicht erreichbar"; exit 1; }
    VM=probe@$ip
    meld "Desktop-Weg: VM $VMID jetzt $ip, GDM $(vm 'systemctl is-active gdm3')"
fi
meld "Pakete übertragen"
vm 'rm -rf ~/querencia-debs ~/querencia-test'
scp -q -r "$DEBS" "$VM:querencia-debs"
scp -q "$REPO/tests/frisches-ubuntu-pruefen.sh" "$VM:"
vm 'cd ~/querencia-debs && sha256sum -c SHA256SUMS' >"$OUT/sha256sum.txt"

meld "vorher"
vm 'cd ~ && sudo bash ~/frisches-ubuntu-pruefen.sh vorher' | tee "$OUT/vorher.txt"
meld "Installation (Weg A, lokales Verzeichnis)"
vm 'cd ~/querencia-debs && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ./*.deb' >"$OUT/apt-install.log" 2>&1 ||
    { meld "apt-get install fehlgeschlagen, siehe $OUT/apt-install.log"; exit 1; }
meld "nachher"
rc=0
vm 'cd ~ && bash ~/frisches-ubuntu-pruefen.sh nachher' | tee "$OUT/nachher.txt" || rc=$?
scp -q -r "$VM:querencia-test" "$OUT/"

meld "Ergebnisse in $OUT"
meld "weiter von Hand: Anmeldung an tty1 (querencia-session) bzw. GDM, Prüfliste Abschnitt 6;"
meld "  ssh $VM; Bildschirmfoto: ssh $HOST \"qm monitor $VMID <<< 'screendump /tmp/q.png -f png'\""
meld "danach: ssh $HOST qm stop $VMID"
exit $rc
