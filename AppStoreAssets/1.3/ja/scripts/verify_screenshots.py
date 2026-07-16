#!/usr/bin/env python3
"""Validate screenshot counts, pixel sizes, transparency, color profile, and manifest copy."""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageCms


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))


def expected_names() -> list[str]:
    return [f'{item["id"]}_{item["slug"]}.png' for item in MANIFEST["screens"]]


def validate_image(path: Path, expected_size: tuple[int, int], final: bool) -> list[str]:
    errors: list[str] = []
    try:
        with Image.open(path) as image:
            if image.format != "PNG":
                errors.append(f"{path}: expected PNG, got {image.format}")
            if image.size != expected_size:
                errors.append(f"{path}: expected {expected_size}, got {image.size}")
            if final and image.mode != "RGB":
                errors.append(f"{path}: final image must be RGB, got {image.mode}")
            if "A" in image.getbands():
                alpha = image.getchannel("A")
                if alpha.getextrema() != (255, 255):
                    errors.append(f"{path}: contains transparent pixels")
            if final:
                profile_data = image.info.get("icc_profile")
                if not profile_data:
                    errors.append(f"{path}: missing embedded color profile")
                else:
                    profile = ImageCms.ImageCmsProfile(io.BytesIO(profile_data))
                    description = ImageCms.getProfileDescription(profile)
                    if "srgb" not in description.lower():
                        errors.append(f"{path}: expected sRGB profile, got {description.strip()}")
    except Exception as error:  # noqa: BLE001
        errors.append(f"{path}: unreadable image ({error})")
    return errors


def main() -> int:
    errors: list[str] = []
    names = expected_names()
    if len(names) != 10 or len(set(names)) != 10:
        errors.append("manifest must define exactly 10 unique screens")

    for item in MANIFEST["screens"]:
        for field in ("title", "subtitle", "description"):
            if not str(item.get(field, "")).strip():
                errors.append(f'screen {item.get("id", "?")}: missing {field}')

    for platform in ("iPhone", "iPad"):
        config = MANIFEST["platforms"][platform]
        size = (config["width"], config["height"])
        raw_dir = ROOT / platform / "raw"
        final_dir = ROOT / platform / "final"
        for directory in (raw_dir, final_dir):
            actual = sorted(path.name for path in directory.glob("*.png"))
            if actual != names:
                missing = sorted(set(names) - set(actual))
                extra = sorted(set(actual) - set(names))
                errors.append(f"{directory}: missing={missing}, extra={extra}")

        for name in names:
            errors.extend(validate_image(raw_dir / name, size, final=False))
            errors.extend(validate_image(final_dir / name, size, final=True))

    if errors:
        print("Screenshot verification failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Verified 40 PNG files: 20 raw and 20 final.")
    print("Final files: exact target dimensions, RGB, opaque, embedded sRGB profile.")
    print("Manifest: 10 complete Japanese title/subtitle/description sets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
