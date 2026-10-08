#!/usr/bin/env python3
"""Write Reco's colour sets from the theme's token file.

Usage: scripts/apply-theme.py [theme/theme.tokens.json]

Each role in the file's `role` group becomes a colour set with four appearances: its `$value` for dark, and the
`light`, `darkHighContrast` and `lightHighContrast` values in `$extensions.com.reco.theme`. Values are hex colours
or aliases to another token (`{color.void}`). `accent` is the asset catalog's AccentColor; every other role is
`Assets.xcassets/Theme/<Role>.colorset`, which Swift reads as `Color(.<role>)`.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Reco" / "Assets.xcassets"
VARIANTS = ("light", "darkHighContrast", "lightHighContrast")
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
ALIAS = re.compile(r"^\{([^}]+)\}$")


def resolve(tokens, value, seen=()):
    match = ALIAS.match(value)
    if not match:
        if not HEX.match(value):
            sys.exit(f"✗ {value!r} is neither #rrggbb nor an alias like {{color.void}}")
        return value.lower()
    path = match.group(1)
    if path in seen:
        sys.exit(f"✗ alias loop through {path}")
    node = tokens
    for key in path.split("."):
        if not isinstance(node, dict) or key not in node:
            sys.exit(f"✗ {value} points at nothing")
        node = node[key]
    return resolve(tokens, node["$value"], (*seen, path))


def component(hex_value):
    return {
        "color-space": "srgb",
        "components": {
            "red": "0x" + hex_value[1:3].upper(),
            "green": "0x" + hex_value[3:5].upper(),
            "blue": "0x" + hex_value[5:7].upper(),
            "alpha": "1.000",
        },
    }


def colour_set(dark, light, dark_high_contrast, light_high_contrast):
    dark_appearance = [{"appearance": "luminosity", "value": "dark"}]
    high_contrast = [{"appearance": "contrast", "value": "high"}]
    return {
        "colors": [
            {"idiom": "universal", "color": component(light)},
            {"idiom": "universal", "appearances": dark_appearance, "color": component(dark)},
            {"idiom": "universal", "appearances": high_contrast, "color": component(light_high_contrast)},
            {"idiom": "universal", "appearances": dark_appearance + high_contrast, "color": component(dark_high_contrast)},
        ],
        "info": {"author": "xcode", "version": 1},
    }


def folder(role):
    if role == "accent":
        return CATALOG / "AccentColor.colorset"
    return CATALOG / "Theme" / f"{role[0].upper()}{role[1:]}.colorset"


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "theme" / "theme.tokens.json"
    tokens = json.loads(source.read_text())
    roles = tokens.get("role") or sys.exit("✗ the file has no `role` group")

    written = set()
    for role, token in roles.items():
        variants = token.get("$extensions", {}).get("com.reco.theme", {})
        missing = [name for name in VARIANTS if name not in variants]
        if missing:
            sys.exit(f"✗ role {role} has no {', '.join(missing)} in $extensions.com.reco.theme")
        dark = resolve(tokens, token["$value"])
        light, dark_high_contrast, light_high_contrast = (resolve(tokens, variants[name]) for name in VARIANTS)
        target = folder(role)
        target.mkdir(parents=True, exist_ok=True)
        contents = colour_set(dark, light, dark_high_contrast, light_high_contrast)
        (target / "Contents.json").write_text(json.dumps(contents, indent=2))
        written.add(target)
        print(f"  {role:14} {dark}  light {light}  ↑contrast {dark_high_contrast} / {light_high_contrast}")

    for orphan in sorted(set((CATALOG / "Theme").glob("*.colorset")) - written):
        print(f"! {orphan.name} has no role in {source.name}; Swift may still use it")
    print(f"✓ {len(written)} colour sets from {source.relative_to(ROOT) if source.is_relative_to(ROOT) else source}")


if __name__ == "__main__":
    main()
