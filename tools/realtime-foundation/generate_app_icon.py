from __future__ import annotations

from pathlib import Path
from typing import Iterable, Tuple

from PIL import Image, ImageDraw, ImageFilter


SIZE = 2048
OUT = Path("Resources/AppIcon.png")

Color = Tuple[int, int, int, int]


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def mix(c1: Color, c2: Color, t: float) -> Color:
    return tuple(lerp(c1[i], c2[i], t) for i in range(4))  # type: ignore[return-value]


def add_gradient(canvas: Image.Image) -> None:
    top_left = (248, 241, 219, 255)
    top_right = (245, 240, 214, 255)
    bottom_left = (44, 145, 132, 255)
    bottom_right = (10, 82, 78, 255)
    px = canvas.load()
    for y in range(SIZE):
        v = y / (SIZE - 1)
        left = mix(top_left, bottom_left, v)
        right = mix(top_right, bottom_right, v)
        for x in range(SIZE):
            u = x / (SIZE - 1)
            px[x, y] = mix(left, right, u)


def rounded_mask(size: int, radius: int, inset: int = 0) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [inset, inset, size - inset, size - inset],
        radius=radius,
        fill=255,
    )
    return mask


def layer_shadow(base: Image.Image, shape: Image.Image, offset: tuple[int, int], radius: int) -> None:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow.alpha_composite(shape, offset)
    alpha = shadow.getchannel("A").filter(ImageFilter.GaussianBlur(radius))
    shadow.putalpha(alpha)
    base.alpha_composite(shadow)


def draw_panel(base: Image.Image) -> None:
    panel = Image.new("RGBA", (1280, 1280), (0, 0, 0, 0))
    panel_draw = ImageDraw.Draw(panel)
    panel_draw.rounded_rectangle(
        [0, 0, 1280, 1280],
        radius=285,
        fill=(8, 58, 64, 250),
    )
    panel_draw.rounded_rectangle(
        [58, 58, 1222, 1222],
        radius=235,
        outline=(231, 251, 238, 46),
        width=8,
    )
    shadow_shape = Image.new("RGBA", (1280, 1280), (0, 0, 0, 0))
    ImageDraw.Draw(shadow_shape).rounded_rectangle(
        [0, 0, 1280, 1280],
        radius=285,
        fill=(0, 0, 0, 76),
    )
    layer_shadow(base, shadow_shape, (386, 430), 44)
    base.alpha_composite(panel, (384, 360))


def draw_waveform(draw: ImageDraw.ImageDraw) -> None:
    center_x = SIZE // 2
    half_width = 38
    cream = (236, 253, 235, 255)
    mint = (110, 232, 205, 255)
    bars: Iterable[tuple[int, int, Color]] = [
        (-288, 980, 1150, cream),
        (-144, 790, 1340, mint),
        (0, 640, 1490, cream),
        (144, 790, 1340, mint),
        (288, 980, 1150, cream),
    ]
    for dx, y0, y1, color in bars:
        x0 = center_x + dx - half_width
        x1 = center_x + dx + half_width
        draw.rounded_rectangle([x0, y0, x1, y1], radius=36, fill=color)


def draw_translation_badge(base: Image.Image) -> None:
    origin = (1248, 1140)
    badge = Image.new("RGBA", (500, 410), (0, 0, 0, 0))
    d = ImageDraw.Draw(badge)
    d.rounded_rectangle([24, 28, 460, 318], radius=104, fill=(244, 111, 83, 255))
    d.polygon([(340, 284), (438, 376), (312, 332)], fill=(244, 111, 83, 255))
    d.rounded_rectangle([110, 112, 374, 142], radius=15, fill=(255, 245, 220, 240))
    d.rounded_rectangle([110, 184, 320, 214], radius=15, fill=(255, 245, 220, 230))
    d.rounded_rectangle([110, 256, 260, 286], radius=15, fill=(255, 245, 220, 216))
    shadow_shape = Image.new("RGBA", badge.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow_shape).rounded_rectangle([24, 28, 460, 318], radius=104, fill=(0, 0, 0, 86))
    layer_shadow(base, shadow_shape, (origin[0] + 24, origin[1] + 60), 30)
    base.alpha_composite(badge, origin)


def draw_source_bubble(base: Image.Image) -> None:
    origin = (300, 1140)
    bubble = Image.new("RGBA", (500, 380), (0, 0, 0, 0))
    d = ImageDraw.Draw(bubble)
    d.rounded_rectangle([36, 36, 438, 296], radius=98, fill=(244, 241, 216, 255))
    d.polygon([(136, 264), (58, 344), (178, 296)], fill=(244, 241, 216, 255))
    d.rounded_rectangle([132, 126, 342, 154], radius=14, fill=(12, 104, 102, 210))
    d.rounded_rectangle([132, 198, 286, 226], radius=14, fill=(12, 104, 102, 170))
    shadow_shape = Image.new("RGBA", bubble.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow_shape).rounded_rectangle([36, 36, 438, 296], radius=98, fill=(0, 0, 0, 52))
    layer_shadow(base, shadow_shape, (origin[0] + 34, origin[1] + 50), 26)
    base.alpha_composite(bubble, origin)


def main() -> None:
    square = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gradient = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    add_gradient(gradient)
    mask = rounded_mask(SIZE, 420, 70)
    square.alpha_composite(gradient)
    square.putalpha(mask)

    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([1090, 310, 1990, 1160], fill=(248, 177, 89, 56))
    gd.ellipse([120, 1050, 980, 1920], fill=(15, 188, 169, 70))
    square.alpha_composite(glow.filter(ImageFilter.GaussianBlur(58)))

    draw_panel(square)
    draw_waveform(ImageDraw.Draw(square))
    draw_source_bubble(square)
    draw_translation_badge(square)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    square.save(OUT)
    print(f"wrote {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
