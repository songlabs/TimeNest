#!/usr/bin/env python3
"""Compose TimeNest 1.3 Japanese App Store screenshots from Simulator captures."""

from __future__ import annotations

import argparse
import glob
import json
import os
from pathlib import Path
from typing import Iterable, Sequence

from PIL import Image, ImageChops, ImageCms, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "manifest.json"
RESAMPLING = getattr(Image, "Resampling", Image)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--platform",
        type=str.lower,
        choices=("iphone", "ipad", "all"),
        default="all",
        help="Platform to compose (default: all).",
    )
    return parser.parse_args()


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def find_font() -> str:
    override = os.environ.get("TIMENEST_SCREENSHOT_FONT")
    if override and Path(override).is_file():
        return override

    candidates = (
        glob.glob("/System/Library/Fonts/*W8.ttc")
        + [
            "/System/Library/Fonts/Hiragino Sans GB.ttc",
            "/System/Library/Fonts/Arial Unicode.ttf",
        ]
    )
    for candidate in candidates:
        if Path(candidate).is_file():
            return candidate
    raise FileNotFoundError(
        "No Japanese system font found. Set TIMENEST_SCREENSHOT_FONT to a font path."
    )


def hex_color(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def interpolate(left: int, right: int, progress: float) -> int:
    return round(left + (right - left) * progress)


def gradient_background(size: tuple[int, int], colors: Sequence[str], accent: str) -> Image.Image:
    width, height = size
    start = hex_color(colors[0])
    end = hex_color(colors[1])
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        p = y / max(height - 1, 1)
        eased = p * p * (3 - 2 * p)
        color = tuple(interpolate(start[i], end[i], eased) for i in range(3))
        draw.line((0, y, width, y), fill=color)

    decoration = Image.new("RGBA", size, (0, 0, 0, 0))
    deco_draw = ImageDraw.Draw(decoration)
    accent_rgb = hex_color(accent)
    radius = round(min(width, height) * 0.30)
    deco_draw.ellipse(
        (-radius, round(height * 0.52), radius, round(height * 0.52) + radius * 2),
        fill=(*accent_rgb, 38),
    )
    deco_draw.ellipse(
        (round(width * 0.68), -radius, round(width * 0.68) + radius * 2, radius),
        fill=(255, 255, 255, 22),
    )
    decoration = decoration.filter(ImageFilter.GaussianBlur(radius=max(20, radius // 5)))
    return Image.alpha_composite(image.convert("RGBA"), decoration)


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> float:
    return draw.textlength(text, font=font)


def wrap_japanese(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    max_width: int,
) -> list[str]:
    lines: list[str] = []
    for paragraph in text.splitlines() or [""]:
        current = ""
        for character in paragraph:
            candidate = current + character
            if current and text_width(draw, candidate, font) > max_width:
                lines.append(current)
                current = character
            else:
                current = candidate
        if current:
            lines.append(current)
    return lines


def line_height(font: ImageFont.FreeTypeFont, extra: int) -> int:
    box = font.getbbox("予定Ag")
    return box[3] - box[1] + extra


def draw_centered_text(
    image: Image.Image,
    text: str,
    font: ImageFont.FreeTypeFont,
    max_width: int,
    y: int,
    fill: tuple[int, int, int, int],
    spacing: int,
) -> int:
    draw = ImageDraw.Draw(image)
    lines = wrap_japanese(draw, text, font, max_width)
    height = line_height(font, spacing)
    for line in lines:
        width = text_width(draw, line, font)
        draw.text(((image.width - width) / 2, y), line, font=font, fill=fill)
        y += height
    return y


def draw_left_text(
    image: Image.Image,
    text: str,
    font: ImageFont.FreeTypeFont,
    x: int,
    max_width: int,
    y: int,
    fill: tuple[int, int, int, int],
    spacing: int,
) -> int:
    draw = ImageDraw.Draw(image)
    lines = wrap_japanese(draw, text, font, max_width)
    height = line_height(font, spacing)
    for line in lines:
        draw.text((x, y), line, font=font, fill=fill)
        y += height
    return y


def normalized_crop(image: Image.Image, values: Sequence[float]) -> Image.Image:
    left, top, right, bottom = values
    box = (
        round(left * image.width),
        round(top * image.height),
        round(right * image.width),
        round(bottom * image.height),
    )
    return image.crop(box)


def device_mockup(
    raw: Image.Image,
    crop: Sequence[float],
    screen_size: tuple[int, int],
    border: int,
    corner_radius: int,
    angle: float,
) -> Image.Image:
    screen = ImageOps.fit(
        normalized_crop(raw.convert("RGB"), crop),
        screen_size,
        method=RESAMPLING.LANCZOS,
        centering=(0.5, 0.5),
    ).convert("RGBA")

    mask = Image.new("L", screen_size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, screen_size[0] - 1, screen_size[1] - 1),
        radius=corner_radius,
        fill=255,
    )
    screen.putalpha(mask)

    outer_size = (screen_size[0] + border * 2, screen_size[1] + border * 2)
    frame = Image.new("RGBA", outer_size, (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle(
        (0, 0, outer_size[0] - 1, outer_size[1] - 1),
        radius=corner_radius + border,
        fill=(18, 21, 24, 255),
        outline=(72, 76, 82, 255),
        width=max(3, border // 6),
    )
    frame.alpha_composite(screen, (border, border))
    return frame.rotate(angle, resample=RESAMPLING.BICUBIC, expand=True)


def place_with_shadow(
    canvas: Image.Image,
    item: Image.Image,
    position: tuple[int, int],
    scale: float = 1.0,
) -> None:
    shadow = Image.new("RGBA", item.size, (0, 0, 0, 0))
    silhouette = item.getchannel("A")
    shadow.putalpha(silhouette.point(lambda value: round(value * 0.42)))
    black = Image.new("RGBA", item.size, (0, 0, 0, 255))
    black.putalpha(shadow.getchannel("A"))
    black = black.filter(ImageFilter.GaussianBlur(radius=max(1, round(34 * scale))))
    canvas.alpha_composite(
        black,
        (position[0] + round(22 * scale), position[1] + round(34 * scale)),
    )
    canvas.alpha_composite(item, position)


def compose_iphone(raw: Image.Image, screen: dict, font_path: str, config: dict) -> Image.Image:
    canvas_size = tuple(config.get("canvas_size", config["final_size"]))
    scale = min(canvas_size[0] / 1320, canvas_size[1] / 2868)
    frame = config["frame"]
    canvas = gradient_background(canvas_size, screen["colors"], screen["accent"])
    title_font = ImageFont.truetype(font_path, round(78 * scale), index=0)
    subtitle_font = ImageFont.truetype(font_path, round(40 * scale), index=0)

    y = draw_centered_text(
        canvas,
        screen.get("iphone_title", screen["title"]),
        title_font,
        round(1120 * scale),
        round(128 * scale),
        (255, 255, 255, 255),
        round(18 * scale),
    )
    y = draw_centered_text(
        canvas,
        screen.get("iphone_subtitle", screen["subtitle"]),
        subtitle_font,
        round(1050 * scale),
        y + round(28 * scale),
        (245, 250, 252, 235),
        round(16 * scale),
    )

    screen_width = int(frame["screen_width"])
    screen_height = round(screen_width * raw.height / raw.width)
    mockup = device_mockup(
        raw,
        screen["iphone_crop"],
        screen_size=(screen_width, screen_height),
        border=int(frame["border"]),
        corner_radius=int(frame["corner_radius"]),
        angle=-1.4 if int(screen["id"]) % 2 else 1.4,
    )
    x = (canvas.width - mockup.width) // 2
    device_y = max(int(frame["minimum_top"]), y + round(62 * scale))
    place_with_shadow(canvas, mockup, (x, device_y), scale=scale)
    return canvas


def compose_ipad(raw: Image.Image, screen: dict, font_path: str) -> Image.Image:
    canvas = gradient_background((2064, 2752), screen["colors"], screen["accent"])
    title_font = ImageFont.truetype(font_path, 78, index=0)
    subtitle_font = ImageFont.truetype(font_path, 36, index=0)

    y = draw_left_text(
        canvas,
        screen.get("ipad_title", screen["title"]),
        title_font,
        112,
        650,
        280,
        (255, 255, 255, 255),
        20,
    )
    draw_left_text(
        canvas,
        screen.get("ipad_subtitle", screen["subtitle"]),
        subtitle_font,
        112,
        630,
        y + 38,
        (245, 250, 252, 235),
        18,
    )

    mockup = device_mockup(
        raw,
        screen["ipad_crop"],
        screen_size=(1240, 1653),
        border=28,
        corner_radius=54,
        angle=1.2 if int(screen["id"]) % 2 else -1.2,
    )
    place_with_shadow(canvas, mockup, (720, 720))
    return canvas


def save_srgb(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    image.convert("RGB").save(path, format="PNG", optimize=True, icc_profile=profile)


def compose(platforms: Iterable[str]) -> None:
    manifest = load_manifest()
    font_path = find_font()
    for platform in platforms:
        config = manifest["platforms"][platform]
        raw_size = tuple(config.get("raw_size", (config["width"], config["height"])))
        for screen in manifest["screens"]:
            filename = f'{screen["id"]}_{screen["slug"]}.png'
            raw_path = ROOT / platform / "raw" / filename
            output_path = ROOT / platform / "final" / filename
            if not raw_path.is_file():
                raise FileNotFoundError(f"Missing raw screenshot: {raw_path}")
            with Image.open(raw_path) as raw:
                if raw.size != raw_size:
                    raise ValueError(f"{raw_path} has {raw.size}; expected {raw_size}")
                final = (
                    compose_iphone(raw, screen, font_path, config)
                    if platform == "iPhone"
                    else compose_ipad(raw, screen, font_path)
                )
                save_srgb(final, output_path)
            print(output_path.relative_to(ROOT))


def main() -> None:
    args = parse_args()
    platform_names = {"iphone": "iPhone", "ipad": "iPad"}
    platforms = (
        ("iPhone", "iPad")
        if args.platform == "all"
        else (platform_names[args.platform],)
    )
    compose(platforms)


if __name__ == "__main__":
    main()
