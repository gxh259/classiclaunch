#!/usr/bin/env python3
"""Keep the two newest locally built DMGs in the project folder."""

import argparse
import os
import re
import shutil
import tempfile
from pathlib import Path


NAME = re.compile(r"^ClassicLaunchpad-(\d+(?:\.\d+)*)-universal\.dmg$")
OLD_ZIP = re.compile(r"^ClassicLaunchpad-\d+(?:\.\d+)*-universal\.zip$")


def prune(releases: Path) -> list[str]:
    versions = {
        match.group(1)
        for path in releases.iterdir() if path.is_file()
        if (match := NAME.fullmatch(path.name))
    }
    keep = set(sorted(versions, key=lambda value: tuple(map(int, value.split("."))), reverse=True)[:2])
    for path in releases.iterdir():
        match = NAME.fullmatch(path.name)
        if path.is_file() and (OLD_ZIP.fullmatch(path.name) or
                               (match and match.group(1) not in keep)):
            path.unlink()
    return sorted(keep, key=lambda value: tuple(map(int, value.split("."))), reverse=True)


def archive(root: Path, version: str) -> list[str]:
    if not re.fullmatch(r"\d+(?:\.\d+)*", version):
        raise ValueError(f"Invalid version: {version}")
    dist = root / "dist"
    releases = root / "releases"
    releases.mkdir(exist_ok=True)
    source = dist / "启动台-通用版.dmg"
    if not source.is_file() or source.is_symlink():
        raise FileNotFoundError(f"Missing fresh build: {source}")
    destination = releases / f"ClassicLaunchpad-{version}-universal.dmg"
    with tempfile.NamedTemporaryFile(prefix=".release-", dir=releases, delete=False) as temp:
        temporary = Path(temp.name)
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    source.unlink()
    source.symlink_to(Path("..") / "releases" / destination.name)
    (dist / "启动台-通用版.zip").unlink(missing_ok=True)
    return prune(releases)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    kept = archive(args.root, args.version)
    print("本地保留的版本：" + ", ".join(kept))
