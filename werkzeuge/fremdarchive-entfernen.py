#!/usr/bin/env python3
"""Entfernt gebündelte Fremdarchive aus vendorten Crates (QD-139).

    fremdarchive-entfernen.py <cargo-vendor-dir> [<fremdarchive.conf>]

Für jede Zeile mit der Aktion "entfernen" in common/fremdarchive.conf wird
jede passende Datei (fnmatch-Muster relativ zu cargo-vendor/) gelöscht und
ihr Eintrag aus "files" in der .cargo-checksum.json des Crates gestrichen.
Die Paketprüfsumme ("package", aus Cargo.lock) bleibt, damit cargo den Crate
offline weiter annimmt; cargo prüft nur die aufgeführten Dateien. Wird der
Crate so gebaut, dass er die Datei braucht (gettext-sys ohne das Feature
gettext-system), schlägt der Bau fehl statt still etwas anderes zu tun.

Ausgabe: eine Zeile je entfernter Datei; trifft kein Muster, ist nichts zu
tun. Exit 1, wenn die .cargo-checksum.json des Crates fehlt oder die Datei
dort nicht aufgeführt ist (dann bleibt sie liegen).
"""
import fnmatch
import json
import os
import sys

vendor = sys.argv[1]
conf = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "common", "fremdarchive.conf")

regeln = []
for line in open(conf, encoding="utf-8"):
    if not line.strip() or line.startswith("#"):
        continue
    spalten = line.rstrip("\n").split("\t")
    if spalten[1] == "entfernen":
        regeln.append(spalten[0])

fehler = 0
for crate in sorted(os.listdir(vendor)):
    d = os.path.join(vendor, crate)
    if not os.path.isdir(d):
        continue
    for root, _dirs, names in os.walk(d):
        for f in sorted(names):
            full = os.path.join(root, f)
            rel = os.path.relpath(full, vendor)
            if not any(fnmatch.fnmatch(rel, m) for m in regeln):
                continue
            summen = os.path.join(d, ".cargo-checksum.json")
            if not os.path.isfile(summen):
                print(f"fremdarchive-entfernen: {crate}: .cargo-checksum.json fehlt", file=sys.stderr)
                fehler = 1
                continue
            with open(summen, encoding="utf-8") as fh:
                daten = json.load(fh)
            innen = os.path.relpath(full, d)
            if innen not in daten.get("files", {}):
                print(f"fremdarchive-entfernen: {rel} steht nicht in .cargo-checksum.json", file=sys.stderr)
                fehler = 1
                continue
            del daten["files"][innen]
            os.remove(full)
            with open(summen, "w", encoding="utf-8") as fh:
                json.dump(daten, fh, separators=(",", ":"))
            print(f"entfernt: {rel} (Paketprüfsumme {daten['package'][:16]} bleibt)")
sys.exit(fehler)
