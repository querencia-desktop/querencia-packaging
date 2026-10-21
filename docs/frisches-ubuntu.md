# Installationstest auf frischem Ubuntu 26.04

Ausführlicher Ablauf: [pflichtprobe-frische-vm.md](pflichtprobe-frische-vm.md). Hier die
Werkzeuge.

**Niemals auf dem Entwicklungsrechner ausführen** – nur auf einer neuen,
wegwerfbaren Test-VM (Snapshot vorher).

1. Test-VM: Ubuntu Server 26.04.1, virtio-gpu, 4 GiB RAM; zweite VM mit
   Ubuntu Desktop (GNOME) für Prüfung P; dritte ohne Grafikkarte für Q.
2. `.deb`-Dateien und die Testquelle (oder später die echte Quelle) auf die
   VM bringen.
3. Vor der Installation: `sudo bash frisches-ubuntu-pruefen.sh vorher`
4. Installation: `sudo apt install querencia-desktop` (bzw. lokale Quelle).
5. Nach der Installation: `bash frisches-ubuntu-pruefen.sh nachher`
6. An tty1 anmelden, `querencia-session`; im Querencia-Terminal:
   `bash frisches-ubuntu-pruefen.sh sitzung`
7. Abmelden, `sudo apt remove …`, dann `bash frisches-ubuntu-pruefen.sh entfernt`
