#!/usr/bin/env python3
"""Prüft ein Git-Repository vor einer Veröffentlichung (nur lesend).

    veroeffentlichung-pruefen.py <repo> [<bericht.md>]

Durchsucht jede Datei-Version der GESAMTEN Historie (alle Blobs aller Refs),
nicht nur den aktuellen Stand – ein Push veröffentlicht die Historie mit.
Kategorien:
  GEHEIM     private Schlüssel, Token-Muster (GitHub, AWS, Slack), Passwortzuweisungen
  PERSON     E-Mail-Adressen, Home-Pfade, Rechnername, private IP-Adressen
  AGENT      Agenten-Anweisungsdateien (CLAUDE.md, AGENTS.md, .cursor/)
  LOG        Logdateien, Wayland-Mitschnitte
  GROSS      Dateien > 1 MiB
  BINAER     Bilder/Binärdateien (Anzahl, zur Sichtprüfung auf private Inhalte)
Ergebnis: Zusammenfassung auf stdout, Einzelheiten optional als Markdown.
Gibt nie den Inhalt eines Treffers aus, nur Pfad, Commit-Anzahl und Kategorie
(sonst würde der Bericht selbst ein Geheimnis verbreiten).
"""
import collections
import re
import subprocess
import sys

PATTERNS = {
    "GEHEIM": [
        (r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY", "privater Schlüssel"),
        (r"\bghp_[A-Za-z0-9]{36}\b|\bgithub_pat_[A-Za-z0-9_]{40,}", "GitHub-Token"),
        (r"\bAKIA[0-9A-Z]{16}\b", "AWS-Schlüssel"),
        (r"\bxox[baprs]-[A-Za-z0-9-]{10,}", "Slack-Token"),
        (r"(?i)\b(?:password|passwd|passwort|secret|api[_-]?key|access[_-]?token)\s*[:=]\s*['\"][^'\"\s]{6,}['\"]", "Zuweisung Geheimnis"),
    ],
    "PERSON": [
        (r"BESITZER_NAME_ODER_ADRESSE", "Name/E-Mail des Besitzers"),
        (r"~\b", "Home-Pfad"),
        (r"\bentwicklungs-vm\b|\bEntwicklungs-VM\b", "Rechnername der VM"),
        (r"\b(?:192\.168|10\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b", "private IP"),
    ],
}
AGENT = re.compile(r"(^|/)(CLAUDE\.md|AGENTS\.md|\.cursor/|skills-lock\.json)")
LOG = re.compile(r"\.log$|-wl\.log$|WAYLAND_DEBUG")
BIN = re.compile(r"\.(png|jpe?g|gif|webp|ico|xpm|ttf|otf|pdf|qcow2|gz|xz|zip|tar)$", re.I)


def git(repo, *args, **kw):
    return subprocess.run(["git", "-C", repo, *args], check=True, capture_output=True, **kw).stdout


def main():
    repo = sys.argv[1]
    report = sys.argv[2] if len(sys.argv) > 2 else None
    # blob -> paths (all refs), commit count per path
    objs = git(repo, "rev-list", "--objects", "--all").decode(errors="replace").splitlines()
    paths = collections.defaultdict(set)
    for line in objs:
        sha, _, path = line.partition(" ")
        if path:
            paths[sha].add(path)
    head_files = set(git(repo, "ls-files").decode().splitlines())
    checks = git(repo, "cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)",
                 "--batch-all-objects").decode().splitlines()
    blobs = [(s, int(z)) for s, t, z in (l.split() for l in checks) if t == "blob" and s in paths]
    compiled = {k: [(re.compile(p.encode()), d) for p, d in v] for k, v in PATTERNS.items()}
    hits = collections.defaultdict(set)   # (kat, desc) -> paths
    big, binary = set(), set()
    proc = subprocess.Popen(["git", "-C", repo, "cat-file", "--batch"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE)
    for sha, size in blobs:
        proc.stdin.write(sha.encode() + b"\n")
        proc.stdin.flush()
        header = proc.stdout.readline()
        data = proc.stdout.read(int(header.split()[2]))
        proc.stdout.read(1)
        ps = paths[sha]
        if size > 1 << 20:
            big.update(ps)
        if any(BIN.search(p) for p in ps) or b"\0" in data[:8000]:
            binary.update(ps)
            continue
        for kat, pats in compiled.items():
            for rx, desc in pats:
                if rx.search(data):
                    hits[(kat, desc)].update(ps)
    proc.stdin.close()
    proc.wait()
    allpaths = set().union(*paths.values()) if paths else set()
    agent = {p for p in allpaths if AGENT.search(p)}
    logs = {p for p in allpaths if LOG.search(p)}

    def fmt(ps):
        now = sorted(p for p in ps if p in head_files)
        old = sorted(p for p in ps if p not in head_files)
        return now, old

    lines = [f"# Veröffentlichungsprüfung: {repo}", "",
             f"Commits (alle Refs): {len(git(repo, 'rev-list', '--all').splitlines())}, "
             f"Dateien im aktuellen Stand: {len(head_files)}, Datei-Versionen geprüft: {len(blobs)}", ""]
    summary = []
    for (kat, desc), ps in sorted(hits.items()):
        now, old = fmt(ps)
        summary.append(f"{kat:7} {desc}: {len(now)} Dateien aktuell, {len(old)} nur in der Historie")
        lines += [f"## {kat}: {desc}", "", f"Aktuell ({len(now)}): " + (", ".join(f"`{p}`" for p in now[:40]) or "–")
                  + (" …" if len(now) > 40 else ""), "",
                  f"Nur Historie ({len(old)}): " + (", ".join(f"`{p}`" for p in old[:20]) or "–")
                  + (" …" if len(old) > 20 else ""), ""]
    for kat, ps in (("AGENT", agent), ("LOG", logs), ("GROSS", big), ("BINAER", binary)):
        now, old = fmt(ps)
        summary.append(f"{kat:7} {len(now)} Dateien aktuell, {len(old)} nur in der Historie")
        lines += [f"## {kat}", "", "Aktuell: " + (", ".join(f"`{p}`" for p in now[:60]) or "–")
                  + (" …" if len(now) > 60 else ""), "",
                  "Nur Historie: " + (", ".join(f"`{p}`" for p in old[:30]) or "–") + (" …" if len(old) > 30 else ""), ""]
    print(f"== {repo}")
    for s in summary:
        print("  " + s)
    if report:
        with open(report, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
    secret = any(k == "GEHEIM" for k, _ in hits)
    sys.exit(1 if secret else 0)


if __name__ == "__main__":
    main()
