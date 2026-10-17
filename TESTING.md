# Pakete prüfen

```bash
bash werkzeuge/pakete-pruefen.sh ../../pakete/bau/*/*.deb          # statisch + apt-get --simulate
bash werkzeuge/apt-quelle-testen.sh ../../nachweis/apt ../../pakete/bau/*/*.deb
python3 werkzeuge/veroeffentlichung-pruefen.py ../querencia-shell bericht.md
```

- `pakete-pruefen.sh`: Inhalt nur `/usr` und `/etc`, Conffiles, keine
  Entwicklerpfade, Desktop- und Sitzungsdateien gültig, Programme und Symbole
  vorhanden, Abhängigkeiten auflösbar (Simulation gegen das System).
- `apt-quelle-testen.sh`: erzeugt eine Quelle mit Wegwerf-Testschlüssel und
  prüft sie mit apt in einer abgeschotteten Umgebung (`-o Dir=…`): gültig,
  manipuliert, falscher Schlüssel, unsigniert.
- `veroeffentlichung-pruefen.py`: durchsucht die gesamte Git-Historie nach
  Geheimnissen, persönlichen Daten, Maschinenpfaden, Logs, großen Dateien.

Nichts davon installiert etwas oder braucht root. Der Installationstest auf
einem frischen Ubuntu: [tests/frisches-ubuntu.md](tests/frisches-ubuntu.md).
