from pathlib import Path

from PIL import Image


icon_path = Path("Resources/AppIcon.png")
img = Image.open(icon_path).convert("RGBA")

assert img.size == (2048, 2048), f"unexpected icon size: {img.size}"

pixel_source = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
pixels = list(pixel_source)
opaque = [p for p in pixels if p[3] > 240]
assert len(opaque) > 2048 * 2048 * 0.70, "icon should mostly fill the canvas"

teal_pixels = sum(1 for r, g, b, a in opaque if r < 70 and 105 < g < 205 and 105 < b < 215)
coral_pixels = sum(1 for r, g, b, a in opaque if r > 210 and 80 < g < 180 and b < 135)
warm_light_pixels = sum(1 for r, g, b, a in opaque if r > 220 and g > 220 and 175 < b < 230)

total = len(opaque)
assert teal_pixels / total > 0.08, "new icon needs a confident teal/ink realtime-audio identity"
assert coral_pixels / total > 0.01, "new icon needs a warm translation accent, not the old blue-only palette"
assert warm_light_pixels / total > 0.08, "new icon needs warmer contrast against the current cool app theme"

avg_r = sum(p[0] for p in opaque) / total
avg_g = sum(p[1] for p in opaque) / total
avg_b = sum(p[2] for p in opaque) / total

assert avg_b - avg_g < 35, f"icon still reads too blue-heavy: avg rgb=({avg_r:.1f}, {avg_g:.1f}, {avg_b:.1f})"

cream_wave_x = []
for index, (r, g, b, a) in enumerate(pixels):
    x = index % img.width
    y = index // img.width
    if 600 < x < 1450 and 580 < y < 1530 and r > 225 and g > 245 and b > 225 and a > 240:
        cream_wave_x.append(x)

assert cream_wave_x, "icon should have a bright central waveform"
wave_center_x = sum(cream_wave_x) / len(cream_wave_x)
assert abs(wave_center_x - (img.width / 2)) < 8, f"waveform center is misaligned: x={wave_center_x:.1f}"

print("app icon visual smoke ok")
