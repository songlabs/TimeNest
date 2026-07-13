#!/usr/bin/env python3
"""Compose Japanese App Store screenshots for TimeNest shared calendars."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT / "raw"
FINAL_DIR = ROOT / "final"
CANVAS_SIZE = (1284, 2778)
FONT_PATH = Path("/System/Library/Fonts/Hiragino Sans GB.ttc")

SCREENSHOTS = (
    ("01_manage_entry.png", "01_shared_calendar.png", "カレンダーを\n家族や仲間と共有"),
    ("02_share_content.png", "02_share_content.png", "共有する内容を\n自由に選択"),
    ("03_received_month.png", "03_received_schedule.png", "受け取った予定を\nいつでも確認"),
    ("04_read_only_detail.png", "04_read_only.png", "共有先では\n読み取り専用で安心"),
    ("05_calendar_switcher.png", "05_calendar_switcher.png", "自分のカレンダーと\nかんたんに切り替え"),
)


def lerp(a: int, b: int, amount: float) -> int:
    return round(a + (b - a) * amount)


def create_background() -> Image.Image:
    width, height = CANVAS_SIZE
    top = (4, 39, 55)
    bottom = (10, 102, 102)
    image = Image.new("RGB", CANVAS_SIZE)
    draw = ImageDraw.Draw(image)

    for y in range(height):
        amount = y / (height - 1)
        color = tuple(lerp(top[i], bottom[i], amount) for i in range(3))
        draw.line((0, y, width, y), fill=color)

    glow = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((-420, -350, 670, 740), fill=(37, 190, 172, 62))
    glow_draw.ellipse((820, 1580, 1710, 2470), fill=(0, 41, 74, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(125))
    return Image.alpha_composite(image.convert("RGBA"), glow)


def rounded_screen(source: Image.Image, size: tuple[int, int], radius: int) -> Image.Image:
    screen = source.convert("RGB").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    screen.putalpha(mask)
    return screen


def compose(raw_path: Path, title: str) -> Image.Image:
    canvas = create_background()
    draw = ImageDraw.Draw(canvas)
    title_font = ImageFont.truetype(str(FONT_PATH), 92, index=0)

    title_box = draw.multiline_textbbox((0, 0), title, font=title_font, spacing=16, align="center")
    title_width = title_box[2] - title_box[0]
    draw.multiline_text(
        ((CANVAS_SIZE[0] - title_width) / 2, 128),
        title,
        font=title_font,
        fill=(255, 255, 255, 255),
        spacing=16,
        align="center",
        stroke_width=1,
        stroke_fill=(255, 255, 255, 150),
    )

    raw = Image.open(raw_path)
    screen_size = (876, 1895)
    phone_size = (932, 1987)
    phone_x = (CANVAS_SIZE[0] - phone_size[0]) // 2
    phone_y = 590

    shadow = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (phone_x - 18, phone_y + 24, phone_x + phone_size[0] + 18, phone_y + phone_size[1] + 42),
        radius=105,
        fill=(0, 14, 20, 155),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas = Image.alpha_composite(canvas, shadow)
    draw = ImageDraw.Draw(canvas)

    draw.rounded_rectangle(
        (phone_x, phone_y, phone_x + phone_size[0], phone_y + phone_size[1]),
        radius=98,
        fill=(10, 16, 19, 255),
        outline=(123, 178, 178, 205),
        width=3,
    )

    screen = rounded_screen(raw, screen_size, radius=72)
    screen_x = phone_x + (phone_size[0] - screen_size[0]) // 2
    screen_y = phone_y + (phone_size[1] - screen_size[1]) // 2
    canvas.alpha_composite(screen, (screen_x, screen_y))

    # Subtle frame highlights retain an iPhone silhouette without obscuring UI.
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (phone_x + 9, phone_y + 9, phone_x + phone_size[0] - 9, phone_y + phone_size[1] - 9),
        radius=90,
        outline=(255, 255, 255, 42),
        width=2,
    )

    return canvas.convert("RGB")


def main() -> None:
    FINAL_DIR.mkdir(parents=True, exist_ok=True)
    manifest = []

    for raw_name, final_name, title in SCREENSHOTS:
        raw_path = RAW_DIR / raw_name
        if not raw_path.exists():
            raise FileNotFoundError(raw_path)

        final_path = FINAL_DIR / final_name
        compose(raw_path, title).save(final_path, format="PNG", optimize=True)
        manifest.append(
            {
                "file": final_name,
                "title": title.replace("\n", " / "),
                "width": CANVAS_SIZE[0],
                "height": CANVAS_SIZE[1],
                "source": f"raw/{raw_name}",
            }
        )

    (ROOT / "manifest.json").write_text(
        json.dumps({"locale": "ja", "screenshots": manifest}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
