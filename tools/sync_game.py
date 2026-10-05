#!/usr/bin/env python3
"""Copy one game from its own repo into app/games/<slug>/ (MERGE_PLAN section 4a).

Usage: tools/sync_game.py <slug> [<sha>]

- Reads committed code only, with `git archive <sha>` from the sibling repo
  named in tools/games.json. Refuses a dirty work tree or an unpushed HEAD.
- Copies only the runtime folders: scenes, scripts, assets, data.
- Rewrites, all mechanical and repeatable:
  1. res://X -> res://games/<slug>/X in text files (res://.godot/ is kept).
  2. class_name X -> <Prefix>X, plus every use of X in that game's .gd files.
  3. Autoload names (games.json "autoloads": {"Old": {"name": "New", "path": "scripts/Old.gd"}})
     -> renamed in code and registered in app/project.godot.
  4. "user://name -> "user://<slug>_name, unless the name already starts with
     the slug (ball_connect_save.json stays as it is).
- Writes app/games/<slug>/SOURCE with the commit, then runs check_collisions.py.
Never edit app/games/<slug>/ by hand: fix upstream, then sync again.
"""

from __future__ import annotations

import io
import json
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
RUNTIME_DIRS = ("scenes", "scripts", "assets", "data")
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".import", ".cfg", ".json"}
RES_RE = re.compile(r"res://(?!\.godot/)")


class SyncError(Exception):
    pass


def git(repo: Path, *args: str, binary: bool = False) -> bytes | str:
    out = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, check=False)
    if out.returncode != 0:
        raise SyncError(f"git {' '.join(args)} failed in {repo}: {out.stderr.decode().strip()}")
    return out.stdout if binary else out.stdout.decode().strip()


def resolve_source(repo: Path, sha: str | None) -> str:
    if git(repo, "status", "--porcelain"):
        raise SyncError(f"{repo} has uncommitted changes; commit and push first")
    full = str(git(repo, "rev-parse", sha or "HEAD"))
    remote_branches = str(git(repo, "branch", "-r", "--contains", full))
    if not remote_branches:
        raise SyncError(f"{full[:7]} is not on any remote branch; push it first")
    return full


# ---------------------------------------------------------------- GDScript tokens


def rename_identifiers(src: str, mapping: dict[str, str]) -> str:
    """Rename whole identifiers outside strings and comments.

    Skips identifiers right after '.', '$' or '%' (member access and node
    paths such as $Hud), so only real class and autoload references change.
    """
    if not mapping:
        return src
    out: list[str] = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "#":
            j = src.find("\n", i)
            j = n if j == -1 else j
            out.append(src[i:j])
            i = j
        elif c in "\"'":
            quote = src[i : i + 3] if src[i : i + 3] in ('"""', "'''") else c
            j = i + len(quote)
            while j < n and not src.startswith(quote, j):
                j += 2 if src[j] == "\\" else 1
            j = min(n, j + len(quote))
            out.append(src[i:j])
            i = j
        elif c.isalpha() or c == "_":
            j = i
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            word = src[i:j]
            prev = src[i - 1] if i > 0 else ""
            if word in mapping and prev not in ".$%":
                word = mapping[word]
            out.append(word)
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def rewrite_user_paths(text: str, slug: str) -> str:
    own = slug.replace("-", "_")

    def fix(m: re.Match[str]) -> str:
        name = m.group(2)
        if name.startswith((slug, own)):
            return m.group(0)
        return f"{m.group(1)}user://{slug}_{name}"

    return re.sub(r"([\"'])user://([^\"'/]+)", fix, text)


# ---------------------------------------------------------------- project.godot


def register_autoloads(slug: str, autoloads: dict[str, dict[str, str]]) -> None:
    """Add renamed game autoloads to app/project.godot (Shell parks them)."""
    if not autoloads:
        return
    proj = APP / "project.godot"
    lines = proj.read_text().splitlines()
    start = lines.index("[autoload]") + 1
    end = start
    while end < len(lines) and not lines[end].startswith("["):
        end += 1
    existing = {ln.split("=", 1)[0] for ln in lines[start:end] if "=" in ln}
    new = [
        f'{a["name"]}="*res://games/{slug}/{a["path"]}"'
        for a in autoloads.values()
        if a["name"] not in existing
    ]
    insert_at = end - 1 if end > start and lines[end - 1] == "" else end
    lines[insert_at:insert_at] = new
    proj.write_text("\n".join(lines) + "\n")


# ---------------------------------------------------------------- main


def sync(slug: str, sha: str | None) -> None:
    games = json.loads((ROOT / "tools/games.json").read_text())
    if slug not in games:
        raise SyncError(f"unknown slug {slug}; add it to tools/games.json")
    cfg = games[slug]
    repo = (ROOT / cfg["repo"]).resolve()
    full = resolve_source(repo, sha)
    tracked = str(git(repo, "ls-tree", "--name-only", full)).splitlines()
    dirs = [d for d in RUNTIME_DIRS if d in tracked]
    archive = git(repo, "archive", "--format=tar", full, *dirs, binary=True)

    dest = APP / "games" / slug
    with tempfile.TemporaryDirectory() as tmp:
        stage = Path(tmp) / slug
        stage.mkdir()
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(stage, filter="data")

        classes: dict[str, str] = {}
        for gd in stage.rglob("*.gd"):
            for m in re.finditer(r"^class_name\s+(\w+)", gd.read_text(), re.M):
                classes[m.group(1)] = cfg["prefix"] + m.group(1)
        names = dict(classes)
        names.update({old: a["name"] for old, a in cfg.get("autoloads", {}).items()})

        for f in stage.rglob("*"):
            if not f.is_file() or f.suffix not in TEXT_SUFFIXES:
                continue
            text = f.read_text()
            new = RES_RE.sub(f"res://games/{slug}/", text)
            if f.suffix == ".gd":
                new = rename_identifiers(new, names)
                new = rewrite_user_paths(new, slug)
            if new != text:
                f.write_text(new)

        (stage / "SOURCE").write_text(f"{full}\n")
        if dest.exists():
            shutil.rmtree(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(stage, dest)

    register_autoloads(slug, cfg.get("autoloads", {}))
    print(f"synced {slug} @ {full[:7]} -> {dest.relative_to(ROOT)} ({', '.join(dirs)})")
    if classes:
        print("  class_name: " + ", ".join(f"{a}->{b}" for a, b in sorted(classes.items())))
    rc = subprocess.run([sys.executable, str(ROOT / "tools/check_collisions.py")], check=False)
    if rc.returncode != 0:
        raise SyncError("collision check failed; see above")


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(__doc__)
        return 2
    try:
        sync(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else None)
    except SyncError as e:
        print(f"SYNC FAIL: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
