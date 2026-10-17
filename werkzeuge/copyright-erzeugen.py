#!/usr/bin/env python3
"""Builds debian/copyright (DEP-5) for a Querencia source package.

    copyright-erzeugen.py <copyright.in> <cargo-vendor-dir|-> <ausgabe> [<inventar.tsv>]

<copyright.in> holds the header and the stanzas of the upstream source
(written by hand, reviewed). The line "@CARGO_VENDOR@" is replaced by one
"Files: cargo-vendor/<crate>-<version>/*" stanza per vendored crate, taken
from the crate's own Cargo.toml (license / license-file, authors). Every
license short name used anywhere gets one standalone "License:" paragraph:
a pointer to /usr/share/common-licenses where Debian ships the text, else
the text itself, taken from a vendored crate's license file.

The optional TSV inventory (crate, version, license, authors, license files)
goes to the evidence directory; it is what docs/LICENSING.md summarises.
Exits 1 if a crate has neither "license" nor "license-file", or if no text
can be found for a license that needs one.
"""
import os
import re
import sys
import tomllib

COMMON = {  # SPDX id -> file in /usr/share/common-licenses
    "Apache-2.0": "Apache-2.0", "GPL-2.0": "GPL-2", "GPL-2.0-only": "GPL-2",
    "GPL-2.0-or-later": "GPL-2", "GPL-3.0": "GPL-3", "GPL-3.0-only": "GPL-3",
    "GPL-3.0-or-later": "GPL-3", "LGPL-2.1": "LGPL-2.1", "LGPL-2.1-only": "LGPL-2.1",
    "LGPL-2.1-or-later": "LGPL-2.1", "LGPL-3.0": "LGPL-3", "LGPL-3.0-or-later": "LGPL-3",
    "MPL-2.0": "MPL-2.0", "CC0-1.0": "CC0-1.0", "GFDL-1.3": "GFDL-1.3",
}
# DEP-5 short names for SPDX ids whose Debian name differs.
DEP5 = {"GPL-3.0-or-later": "GPL-3+", "GPL-2.0-or-later": "GPL-2+",
        "LGPL-2.1-or-later": "LGPL-2.1+", "LGPL-3.0-or-later": "LGPL-3+",
        "GPL-3.0-only": "GPL-3", "GPL-2.0-only": "GPL-2", "LGPL-2.1-only": "LGPL-2.1",
        "Apache-2.0": "Apache-2.0", "MIT": "Expat", "BSD-2-Clause": "BSD-2-clause",
        "BSD-3-Clause": "BSD-3-clause"}
# File name patterns that hold the text of a license (lower case).
TEXT_FILES = {
    "MIT": ["license-mit", "license-mit.md", "license-mit.txt", "license", "license.md", "license.txt", "copying"],
    "ISC": ["license-isc", "license", "license.md", "license.txt"],
    "BSD-2-Clause": ["license-bsd", "license-bsd-2-clause", "license", "license.md", "license.txt"],
    "BSD-3-Clause": ["license-bsd-3-clause", "license-bsd", "license", "license.md", "license.txt"],
    "Zlib": ["license-zlib", "license-zlib.md", "license", "license.md", "license.txt"],
    "0BSD": ["license-0bsd", "license", "license.txt"],
    "BSL-1.0": ["license-boost", "license-bsl", "license_1_0.txt", "license", "license.txt"],
    "Unlicense": ["unlicense", "license-unlicense", "license"],
    "Unicode-3.0": ["license-unicode", "license", "license.txt", "license-unicode-3.0"],
    "Unicode-DFS-2016": ["license-unicode", "license", "license.txt"],
    "MIT-0": ["license-mit-0", "license-mit-0.md", "license-mit0", "license", "license.txt"],
    "CDLA-Permissive-2.0": ["license-cdla", "license", "license.txt"],
    "OFL-1.1": ["license-ofl", "ofl.txt", "license"],
    "bzip2-1.0.6": ["license", "license.txt", "copying"],
}


def spdx_ids(expr):
    parts = re.split(r"\s+(?:AND|OR)\s+|[()/]", expr)
    ids = []
    for p in parts:
        p = p.strip()
        if not p:
            continue
        # "Apache-2.0 WITH LLVM-exception" -> keep as one id
        ids.append(p)
    return ids


def dep5_expr(expr):
    expr = expr.replace("/", " OR ")
    def name(m):
        tok = m.group(0)
        return DEP5.get(tok, tok)
    return re.sub(r"[A-Za-z0-9.+-]+(?: WITH [A-Za-z0-9.+-]+)?", lambda m: dep5_name(m.group(0)), expr) \
        .replace(" AND ", " and ").replace(" OR ", " or ")


def dep5_name(tok):
    if tok in ("AND", "OR"):
        return tok
    if " WITH " in tok:
        base, exc = tok.split(" WITH ")
        return f"{DEP5.get(base, base)} with {exc} exception".replace("-exception exception", " exception")
    return DEP5.get(tok, tok)


def license_files(crate_dir):
    out = []
    for f in sorted(os.listdir(crate_dir)):
        lf = f.lower()
        if lf.startswith(("license", "licence", "copying", "unlicense", "notice", "copyright")):
            out.append(f)
    return out


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    header_path, vendor, output = sys.argv[1:4]
    inventory = sys.argv[4] if len(sys.argv) > 4 else None
    header = open(header_path, encoding="utf-8").read()
    # License names used in the header are DEP-5 names; map them back to SPDX.
    reverse = {v: k for k, v in DEP5.items() if k not in ("GPL-3.0-only", "GPL-2.0-only", "LGPL-2.1-only")}
    used = {reverse.get(n, n) for n in re.findall(r"^License: (\S+)$", header, re.M)}
    stanzas, rows, problems = [], [], []
    texts = {}  # license id -> (text, source)
    customs = {}
    if vendor != "-":
        for name in sorted(os.listdir(vendor)):
            d = os.path.join(vendor, name)
            manifest = os.path.join(d, "Cargo.toml")
            if not os.path.isfile(manifest):
                continue
            with open(manifest, "rb") as fh:
                pkg = tomllib.load(fh).get("package", {})
            crate, version = pkg.get("name", name), pkg.get("version", "?")
            authors = [a for a in pkg.get("authors", []) if isinstance(a, str)]
            lic = pkg.get("license")
            files = license_files(d)
            if lic:
                lic = lic.strip()
                for i in spdx_ids(lic):
                    used.add(i)
                    base = i.split(" WITH ")[0]
                    if base not in COMMON and base not in texts:
                        for cand in TEXT_FILES.get(base, []):
                            hit = [f for f in files if f.lower() == cand]
                            if hit:
                                texts[base] = (open(os.path.join(d, hit[0]), encoding="utf-8", errors="replace").read(), f"{name}/{hit[0]}")
                                break
                        # Fallback: a crate under this license alone with exactly one license file.
                        if base not in texts and lic == i and len(files) == 1:
                            texts[base] = (open(os.path.join(d, files[0]), encoding="utf-8", errors="replace").read(), f"{name}/{files[0]}")
                dep5 = dep5_expr(lic)
            elif pkg.get("license-file"):
                short = f"custom-{crate}"
                path = os.path.join(d, pkg["license-file"])
                customs[short] = (open(path, encoding="utf-8", errors="replace").read(), f"{name}/{pkg['license-file']}")
                lic = f"(license-file {pkg['license-file']})"
                dep5 = short
            else:
                problems.append(f"{name}: weder license noch license-file")
                lic, dep5 = "?", "UNKNOWN"
            copyright_line = "; ".join(authors) if authors else f"the {crate} authors (see crate metadata)"
            stanzas.append(
                f"Files: cargo-vendor/{name}/*\nCopyright: {copyright_line}\nLicense: {dep5}\n"
                f"Comment: Rust crate {crate} {version}, vendored from crates.io "
                f"(checksum in cargo-vendor/{name}/.cargo-checksum.json).\n")
            rows.append([crate, version, lic, copyright_line, ",".join(files) or "-"])
    body = header.replace("@CARGO_VENDOR@\n", "\n".join(stanzas))
    paras = []
    for i in sorted({dep5_name(x.split(" WITH ")[0]) + "\0" + x.split(" WITH ")[0] for x in used if x}):
        short, spdx = i.split("\0")
        if short in re.findall(r"^License: (\S+)\n ", header, re.M):
            continue  # paragraph with text already in the header
        if spdx in COMMON:
            paras.append(f"License: {short}\n On Debian systems the full text of this license is in\n"
                         f" /usr/share/common-licenses/{COMMON[spdx]}.\n")
        elif spdx in texts:
            text, src = texts[spdx]
            lines = [l.rstrip() for l in text.strip().splitlines()]
            lines = [(" " + l) if l.strip() else " ." for l in lines]
            paras.append(f"License: {short}\n Text taken from cargo-vendor/{src}.\n .\n" + "\n".join(lines) + "\n")
        elif spdx.startswith("custom-") or short == "UNKNOWN":
            continue
        else:
            problems.append(f"kein Lizenztext für {spdx}")
    for short, (text, src) in sorted(customs.items()):
        lines = [(" " + l.rstrip()) if l.strip() else " ." for l in text.strip().splitlines()]
        paras.append(f"License: {short}\n Text of cargo-vendor/{src}.\n .\n" + "\n".join(lines) + "\n")
    with open(output, "w", encoding="utf-8") as fh:
        fh.write(body.rstrip("\n") + "\n\n" + "\n".join(paras))
    if inventory:
        with open(inventory, "w", encoding="utf-8") as fh:
            fh.write("crate\tversion\tlicense\tauthors\tlicense_files\n")
            for r in rows:
                fh.write("\t".join(x.replace("\t", " ") for x in r) + "\n")
    for p in problems:
        print(f"copyright-erzeugen: {p}", file=sys.stderr)
    print(f"copyright-erzeugen: {len(rows)} Crates, {len(paras)} Lizenzabsätze -> {output}")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
