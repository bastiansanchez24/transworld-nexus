"""Generate launcher icons from assets/images/icon-app at matching resolutions."""

from __future__ import annotations

import io
import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "images" / "icon-app"

SOURCES = {
    32: SRC / "logo-blanco-32.png",
    64: SRC / "logo-blanco-64.png",
    180: SRC / "logo-blanco-180.png",
    256: SRC / "logo-blanco-256.png",
    512: SRC / "logo-blanco-512.png",
    1024: SRC / "logo-blanco-1024.png",
}


def best_source(size: int) -> Path:
    for candidate in sorted(SOURCES):
        if candidate >= size:
            return SOURCES[candidate]
    return SOURCES[1024]


def render(size: int, *, flatten: bool = False) -> Image.Image:
    src = Image.open(best_source(size)).convert("RGBA")
    if src.size != (size, size):
        src = src.resize((size, size), Image.Resampling.LANCZOS)
    if not flatten:
        return src
    bg = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    bg.alpha_composite(src)
    return bg.convert("RGB")


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)
    print(f"  {path.relative_to(ROOT)}  {img.size[0]}x{img.size[1]} {img.mode}")


def save_ico(path: Path, sizes: list[int]) -> None:
    frames = [render(s) for s in sizes]
    payloads: list[tuple[int, int, bytes]] = []
    for im in frames:
        buf = io.BytesIO()
        im.convert("RGBA").save(buf, format="PNG")
        payloads.append((im.size[0], im.size[1], buf.getvalue()))

    count = len(payloads)
    offset = 6 + 16 * count
    entries = bytearray()
    data = bytearray()
    for width, height, png in payloads:
        entries += struct.pack(
            "<BBBBHHII",
            0 if width >= 256 else width,
            0 if height >= 256 else height,
            0,
            0,
            1,
            32,
            len(png),
            offset,
        )
        data += png
        offset += len(png)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(struct.pack("<HHH", 0, 1, count) + entries + data)
    print(f"  {path.relative_to(ROOT)}  sizes={sizes}")


def main() -> None:
    missing = [p for p in SOURCES.values() if not p.exists()]
    if missing:
        raise SystemExit(f"Missing sources: {missing}")

    print("Android")
    android = ROOT / "android" / "app" / "src" / "main" / "res"
    mipmaps = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in mipmaps.items():
        save_png(render(size, flatten=True), android / folder / "ic_launcher.png")

    foregrounds = {
        "drawable-mdpi": 108,
        "drawable-hdpi": 162,
        "drawable-xhdpi": 216,
        "drawable-xxhdpi": 324,
        "drawable-xxxhdpi": 432,
    }
    for folder, size in foregrounds.items():
        save_png(
            render(size, flatten=True),
            android / folder / "ic_launcher_foreground.png",
        )
    save_png(render(1024), android / "drawable-nodpi" / "splash_logo.png")

    print("iOS (no alpha)")
    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-50x50@1x.png": 50,
        "Icon-App-50x50@2x.png": 100,
        "Icon-App-57x57@1x.png": 57,
        "Icon-App-57x57@2x.png": 114,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-72x72@1x.png": 72,
        "Icon-App-72x72@2x.png": 144,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, size in ios_sizes.items():
        save_png(render(size, flatten=True), ios / name)

    print("macOS")
    mac = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_png(render(size), mac / f"app_icon_{size}.png")

    print("Windows")
    save_ico(
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        [16, 32, 48, 64, 256],
    )

    print("Web")
    web = ROOT / "web"
    save_png(render(64), web / "favicon.png")
    save_png(render(180, flatten=True), web / "icons" / "apple-touch-icon.png")
    save_png(render(192, flatten=True), web / "icons" / "Icon-192.png")
    save_png(render(512, flatten=True), web / "icons" / "Icon-512.png")
    save_png(render(192, flatten=True), web / "icons" / "Icon-maskable-192.png")
    save_png(render(512, flatten=True), web / "icons" / "Icon-maskable-512.png")
    save_png(render(1024, flatten=True), web / "icons" / "Icon-1024.png")


if __name__ == "__main__":
    main()
