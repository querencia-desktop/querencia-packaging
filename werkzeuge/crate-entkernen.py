#!/usr/bin/env python3
"""Entkernt einen vendorten Crate: nur das Manifest bleibt, aller Code fehlt.

    crate-entkernen.py <cargo-vendor/crate-version> <grund>

Cargo löst auch abgeschaltete optionale Abhängigkeiten gegen Cargo.lock auf
und braucht dafür ihr Manifest im Vendor-Verzeichnis. Für Crates, deren
Inhalt nicht verteilt werden soll (UnRAR: nicht freie Lizenz), bleibt daher
ein Platzhalter: [package] (ohne Build-Skript), [lib] mit leerer src/lib.rs,
die Abhängigkeiten und Features (für die Auflösung nötig); Beispiele, Tests,
Benchmarks und Entwicklungsabhängigkeiten entfallen. .cargo-checksum.json
behält die Paketprüfsumme aus Cargo.lock und führt keine Dateien mehr.
Wird der Crate doch übersetzt (Feature eingeschaltet), schlägt der Bau fehl
statt still ohne die Bibliothek zu laufen.
"""
import json
import os
import re
import shutil
import sys

d, grund = sys.argv[1], sys.argv[2]
manifest = open(os.path.join(d, "Cargo.toml"), encoding="utf-8").read()
package = json.load(open(os.path.join(d, ".cargo-checksum.json")))["package"]

keep, out, section = True, [], None
for line in manifest.splitlines():
    m = re.match(r"^\s*(\[\[?)([^\]]+)\]\]?\s*$", line)
    if m:
        section = m.group(2).strip()
        is_array = m.group(1) == "[["
        dev = section.startswith("dev-dependencies") or (section.startswith("target.") and ".dev-dependencies" in section)
        keep = not is_array and not dev and section != "lib"
        if section == "lib":
            out += ["[lib]", 'path = "src/lib.rs"']
            continue
    if not keep:
        continue
    if section == "package" and re.match(r"^\s*(build|links|include|exclude)\s*=", line):
        continue
    out.append(line)
if not any(l.strip() == "[lib]" for l in out):
    out += ["", "[lib]", 'path = "src/lib.rs"']
out.insert(0, f"# ENTKERNT (Querencia-Paketierung): {grund}. Nur das Manifest für die\n"
              "# Abhängigkeitsauflösung; der Code des Crates ist nicht enthalten.")

for name in os.listdir(d):
    p = os.path.join(d, name)
    shutil.rmtree(p) if os.path.isdir(p) and not os.path.islink(p) else os.remove(p)
os.makedirs(os.path.join(d, "src"))
with open(os.path.join(d, "Cargo.toml"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(out) + "\n")
with open(os.path.join(d, "src", "lib.rs"), "w") as fh:
    fh.write(f'compile_error!("{os.path.basename(d)} ist im Querencia-Quellpaket entkernt ({grund})");\n')
with open(os.path.join(d, "ENTKERNT.txt"), "w") as fh:
    fh.write(f"{grund}\nOriginal: crates.io, Paketprüfsumme {package}\n")
with open(os.path.join(d, ".cargo-checksum.json"), "w") as fh:
    json.dump({"files": {}, "package": package}, fh)
print(f"entkernt: {os.path.basename(d)}")
