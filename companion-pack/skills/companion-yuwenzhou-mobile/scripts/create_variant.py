#!/usr/bin/env python3
"""Create an independent mobile Companion variant from the 喻文州 baseline."""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path


IGNORED_NAMES = {
    ".git",
    ".build",
    ".swiftpm",
    "DerivedData",
    "xcuserdata",
    ".DS_Store",
}


def ignored(_directory: str, names: list[str]) -> set[str]:
    return {name for name in names if name in IGNORED_NAMES or name.endswith(".xcuserstate")}


def rewrite_text(path: Path, replacements: list[tuple[str, str]], profile_id: str) -> None:
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return

    original = text
    for old, new in replacements:
        text = text.replace(old, new)

    if path.name == "CompanionProfile.swift":
        text = re.sub(r'id: "[^"]+"', f'id: "{profile_id}"', text, count=1)
    if path.name == "project.pbxproj":
        text = re.sub(r'DEVELOPMENT_TEAM = [^;]*;', 'DEVELOPMENT_TEAM = "";', text)

    if text != original:
        path.write_text(text, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Copy and re-identify a CharacterCompanionMobile project."
    )
    parser.add_argument("source", type=Path, help="CharacterCompanionMobile baseline directory")
    parser.add_argument("target", type=Path, help="new directory; must not already exist")
    parser.add_argument("character_name", help="visible character/product name")
    parser.add_argument("bundle_identifier", help="new main app bundle identifier")
    parser.add_argument("url_scheme", help="new URL scheme, for example character-companion")
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    target = args.target.expanduser().resolve()
    if not (source / "CharacterCompanionMobile.xcodeproj" / "project.pbxproj").is_file():
        parser.error(f"not a mobile Companion baseline: {source}")
    if target.exists():
        parser.error(f"target already exists; refusing to overwrite: {target}")
    if not re.fullmatch(r"[A-Za-z0-9.-]+", args.bundle_identifier):
        parser.error("bundle identifier must contain only letters, digits, dots, and hyphens")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9.-]*", args.url_scheme):
        parser.error("URL scheme must start with a letter and contain URL-safe identifier characters")

    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, target, ignore=ignored)

    old_bundle = "local.codex.yuwenzhou.companion.mobile"
    old_widget_bundle = f"{old_bundle}.widget"
    old_group = f"group.{old_bundle}"
    new_bundle = args.bundle_identifier
    new_widget_bundle = f"{new_bundle}.widget"
    new_group = f"group.{new_bundle}"
    profile_id = re.sub(r"[^a-z0-9]+", "-", args.url_scheme.lower()).strip("-")
    swift_stem = "".join(part.capitalize() for part in re.split(r"[^A-Za-z0-9]+", profile_id) if part)
    new_widget_kind = f"{swift_stem or 'Character'}CompanionWidget"

    replacements = [
        (old_widget_bundle, new_widget_bundle),
        (old_group, new_group),
        (old_bundle, new_bundle),
        ("yuwenzhou-companion", args.url_scheme),
        ("YuWenzhouCompanionWidget", new_widget_kind),
        ("YuWenzhouCompanionMobile-UnavailableAppGroup", f"{swift_stem or 'Character'}CompanionMobile-UnavailableAppGroup"),
        ("喻文州小组件", f"{args.character_name}小组件"),
        ("喻文州", args.character_name),
    ]

    text_suffixes = {".swift", ".plist", ".entitlements", ".pbxproj", ".md", ".json", ".yaml", ".yml"}
    for path in target.rglob("*"):
        if path.is_file() and (path.suffix in text_suffixes or path.name == "project.pbxproj"):
            rewrite_text(path, replacements, profile_id)

    print(f"created: {target}")
    print(f"character: {args.character_name}")
    print(f"bundle: {new_bundle}")
    print(f"widget bundle: {new_widget_bundle}")
    print(f"app group: {new_group}")
    print(f"URL scheme: {args.url_scheme}")
    print("next: replace CompanionProfile copy and every character asset, then select a signing Team")
    return 0


if __name__ == "__main__":
    sys.exit(main())
