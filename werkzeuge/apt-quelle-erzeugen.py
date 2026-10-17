#!/usr/bin/env python3
"""Erzeugt eine signierte APT-Paketquelle (Deb822-tauglich, Signed-By) aus .deb-Dateien.

    apt-quelle-erzeugen.py --ziel DIR [--suite resolute] [--komponente alpha]
        [--arch amd64] [--gnupghome DIR --schluessel FINGERABDRUCK]
        [--gueltig-tage 14] paket.deb …

Ergebnis (bestehender Inhalt von DIR/dists/<suite> wird ersetzt, pool/ ergänzt):
    pool/<komponente>/<anfang>/<quellpaket>/<datei>.deb
    dists/<suite>/<komponente>/binary-<arch>/Packages{,.gz,.xz}
    dists/<suite>/<komponente>/binary-<arch>/by-hash/SHA256/<hash>
    dists/<suite>/Release  (SHA256 + SHA512, Date, Valid-Until, Acquire-By-Hash)
    dists/<suite>/InRelease, Release.gpg   (nur mit --schluessel)
    querencia-archive-keyring.gpg / .asc   (öffentlicher Schlüssel, nur mit --schluessel)

Ohne Schlüssel bleibt die Quelle unsigniert; apt lehnt sie dann ab (gewollt).
Deterministisch bei gleichem SOURCE_DATE_EPOCH. Ersetzt reprepro/apt-ftparchive,
die auf dem Baurechner fehlen; signiert wird mit gpg in einem eigenen GNUPGHOME.
"""
import argparse
import gzip
import hashlib
import lzma
import os
import shutil
import subprocess
import sys
import time

FIELD_ORDER = ["Package", "Source", "Version", "Architecture", "Maintainer", "Installed-Size",
               "Depends", "Pre-Depends", "Recommends", "Suggests", "Conflicts", "Breaks",
               "Replaces", "Provides", "Section", "Priority", "Homepage", "Description"]


def control(deb):
    out = subprocess.run(["dpkg-deb", "-f", deb], check=True, capture_output=True, text=True).stdout
    fields, key = {}, None
    for line in out.splitlines():
        if line[:1] in (" ", "\t") and key:
            fields[key] += "\n" + line
        elif ":" in line:
            key, val = line.split(":", 1)
            fields[key] = val.strip()
    return fields


def digests(path):
    h = {n: hashlib.new(n) for n in ("md5", "sha256", "sha512")}
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            for x in h.values():
                x.update(chunk)
    return {n: x.hexdigest() for n, x in h.items()}, os.path.getsize(path)


def gpg(home, *args):
    subprocess.run(["gpg", "--batch", "--quiet", "--homedir", home, *args], check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ziel", required=True)
    ap.add_argument("--suite", default="resolute")
    ap.add_argument("--komponente", default="alpha")
    ap.add_argument("--arch", default="amd64")
    ap.add_argument("--gnupghome")
    ap.add_argument("--schluessel")
    ap.add_argument("--gueltig-tage", type=int, default=14)
    ap.add_argument("debs", nargs="+")
    a = ap.parse_args()

    ziel = os.path.abspath(a.ziel)
    now = int(os.environ.get("SOURCE_DATE_EPOCH", time.time()))
    stanzas = []
    for deb in sorted(a.debs):
        f = control(deb)
        if f.get("Architecture") not in (a.arch, "all"):
            sys.exit(f"{deb}: Architektur {f.get('Architecture')} passt nicht zu {a.arch}")
        src = f.get("Source", f["Package"]).split()[0]
        prefix = src[:4] if src.startswith("lib") else src[0]
        rel = os.path.join("pool", a.komponente, prefix, src, os.path.basename(deb))
        os.makedirs(os.path.join(ziel, os.path.dirname(rel)), exist_ok=True)
        dst = os.path.join(ziel, rel)
        if os.path.exists(dst):
            if digests(dst)[0]["sha256"] != digests(deb)[0]["sha256"]:
                sys.exit(f"{rel} existiert mit anderem Inhalt: eine veröffentlichte Version wird nie ersetzt")
        else:
            shutil.copyfile(deb, dst)
        d, size = digests(dst)
        lines = [f"{k}: {f[k]}" for k in FIELD_ORDER if k in f]
        lines += [f"{k}: {v}" for k, v in sorted(f.items()) if k not in FIELD_ORDER]
        lines += [f"Filename: {rel}", f"Size: {size}", f"MD5sum: {d['md5']}", f"SHA256: {d['sha256']}"]
        stanzas.append((f["Package"], f["Version"], "\n".join(lines) + "\n"))
    stanzas.sort()
    packages = "\n".join(s for _, _, s in stanzas).encode()

    dist = os.path.join(ziel, "dists", a.suite)
    if os.path.isdir(dist):
        shutil.rmtree(dist)
    bindir = os.path.join(dist, a.komponente, f"binary-{a.arch}")
    os.makedirs(os.path.join(bindir, "by-hash", "SHA256"))
    files = {
        "Packages": packages,
        "Packages.gz": gzip.compress(packages, compresslevel=9, mtime=0),
        "Packages.xz": lzma.compress(packages, preset=9),
    }
    index = []
    for name, data in files.items():
        with open(os.path.join(bindir, name), "wb") as fh:
            fh.write(data)
        sha256 = hashlib.sha256(data).hexdigest()
        with open(os.path.join(bindir, "by-hash", "SHA256", sha256), "wb") as fh:
            fh.write(data)
        index.append((f"{a.komponente}/binary-{a.arch}/{name}", len(data), sha256, hashlib.sha512(data).hexdigest()))
    fmt = "%a, %d %b %Y %H:%M:%S UTC"
    release = [
        "Origin: Querencia", "Label: Querencia Desktop", f"Suite: {a.suite}", f"Codename: {a.suite}",
        f"Date: {time.strftime(fmt, time.gmtime(now))}",
        f"Valid-Until: {time.strftime(fmt, time.gmtime(now + a.gueltig_tage * 86400))}",
        f"Architectures: {a.arch}", f"Components: {a.komponente}", "Acquire-By-Hash: yes",
        f"Description: Querencia Desktop packages for Ubuntu {a.suite} ({a.komponente})",
        "SHA256:"] + [f" {s256} {size:>10} {p}" for p, size, s256, _ in index] + \
        ["SHA512:"] + [f" {s512} {size:>10} {p}" for p, size, _, s512 in index]
    with open(os.path.join(dist, "Release"), "w") as fh:
        fh.write("\n".join(release) + "\n")

    if a.schluessel:
        if not a.gnupghome:
            sys.exit("--schluessel braucht --gnupghome")
        rel_path = os.path.join(dist, "Release")
        gpg(a.gnupghome, "--local-user", a.schluessel, "--digest-algo", "SHA512",
            "--clearsign", "--output", os.path.join(dist, "InRelease"), rel_path)
        gpg(a.gnupghome, "--local-user", a.schluessel, "--digest-algo", "SHA512",
            "--armor", "--detach-sign", "--output", os.path.join(dist, "Release.gpg"), rel_path)
        for ext, extra in ((".gpg", []), (".asc", ["--armor"])):
            out = os.path.join(ziel, "querencia-archive-keyring" + ext)
            if os.path.exists(out):
                os.remove(out)
            gpg(a.gnupghome, *extra, "--output", out, "--export", a.schluessel)
        print(f"signiert mit {a.schluessel}")
    else:
        print("WARNUNG: unsigniert – apt verweigert diese Quelle (gewollt)", file=sys.stderr)
    print(f"{len(stanzas)} Pakete -> {ziel} ({a.suite}/{a.komponente}/{a.arch})")


if __name__ == "__main__":
    main()
