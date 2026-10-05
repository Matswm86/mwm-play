#!/usr/bin/env python3
"""Fail when merged games would clash inside app/ (MERGE_PLAN section 4a).

Checks:
1. duplicate class_name anywhere in app/ (shell and games)
2. duplicate autoload names, or an autoload name equal to a class_name
3. a res:// literal inside games/<slug>/ that points outside games/<slug>/
4. the same user:// file name used by two games
5. the same uid:// defined by two files
Exit 0 and print PASS when clean.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

APP = Path(__file__).resolve().parent.parent / "app"
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".import", ".cfg", ".json"}


def files(root: Path, suffixes: set[str]) -> list[Path]:
    return [
        p
        for p in root.rglob("*")
        if p.is_file() and p.suffix in suffixes and ".godot" not in p.parts
    ]


def main() -> int:
    problems: list[str] = []

    classes: dict[str, list[str]] = defaultdict(list)
    for gd in files(APP, {".gd"}):
        for m in re.finditer(r"^class_name\s+(\w+)", gd.read_text(), re.M):
            classes[m.group(1)].append(str(gd.relative_to(APP)))
    for name, where in classes.items():
        if len(where) > 1:
            problems.append(f"class_name {name} defined {len(where)}x: {', '.join(where)}")

    proj = (APP / "project.godot").read_text()
    section = re.search(r"^\[autoload\]\n(.*?)(?=^\[|\Z)", proj, re.M | re.S)
    autoloads = re.findall(r"^(\w+)=", section.group(1), re.M) if section else []
    for name in {a for a in autoloads if autoloads.count(a) > 1}:
        problems.append(f"autoload {name} registered more than once")
    for name in set(autoloads) & set(classes):
        problems.append(f"autoload {name} has the same name as a class_name")

    user_files: dict[str, set[str]] = defaultdict(set)
    games = APP / "games"
    for game in sorted(p for p in games.iterdir() if p.is_dir()) if games.exists() else []:
        own = f"res://games/{game.name}/"
        for f in files(game, TEXT_SUFFIXES):
            text = f.read_text()
            for m in re.finditer(r"res://[^\"'\s)\]]*", text):
                path = m.group(0)
                if not (path.startswith(own) or path.startswith("res://.godot/")):
                    problems.append(f"{f.relative_to(APP)}: {path} points outside {own}")
            if f.suffix == ".gd":
                for m in re.finditer(r"user://([^\"'\s]+)", text):
                    user_files[m.group(1)].add(game.name)
    for name, owners in user_files.items():
        if len(owners) > 1:
            problems.append(f"user://{name} used by {', '.join(sorted(owners))}")

    uids: dict[str, list[str]] = defaultdict(list)
    for f in files(APP, {".uid"}):
        uids[f.read_text().strip()].append(str(f.relative_to(APP)))
    for f in files(APP, {".tscn", ".tres", ".import"}):
        head = f.read_text().split("\n", 40)
        for line in head[:40]:
            m = re.match(r"^\[gd_(?:scene|resource)[^\]]*uid=\"(uid://\w+)\"", line) or re.match(
                r"^uid=\"(uid://\w+)\"", line
            )
            if m:
                uids[m.group(1)].append(str(f.relative_to(APP)))
                break
    for uid, where in uids.items():
        if len(where) > 1:
            problems.append(f"{uid} defined {len(where)}x: {', '.join(where)}")

    for p in problems:
        print(f"COLLISION {p}")
    if problems:
        print(f"{len(problems)} collision(s)")
        return 1
    print(f"PASS collisions ({len(classes)} classes, {len(autoloads)} autoloads, {len(uids)} uids)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
