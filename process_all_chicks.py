#!/usr/bin/env python3
"""
Batch processor for all the AI-generated chick reference sheets in
`new-chicks/`. Each input is a 1584×672 (or similar) PNG with 4 chicks
arranged horizontally on a white background. Output: clean 256×64 px
spritesheets with transparent backgrounds, dropped into the project root
as `chick_<style>.png`.
"""

import os
import sys

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print("requires: pip3 install pillow numpy")
    sys.exit(1)

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(ROOT, "new-chicks")

# Mapping: source filename → destination filename (style id)
STYLE_MAP = {
    "realistic-chick.png": "chick_realistic.png",
    "anime-chick.png":     "chick_anime.png",
    "pxs-chick.png":       "chick_psx.png",
    "oil-chick.png":       "chick_oil.png",
    "embroided-chick.png": "chick_embroidered.png",
    "memoji-chick.png":    "chick_memoji.png",
    "lego-chick.png":      "chick_lego.png",
}

TARGET_FRAME = 64
SHEET_W = TARGET_FRAME * 4   # 256
SHEET_H = TARGET_FRAME       # 64
INNER_PADDING = 3
BOTTOM_OFFSET = 2

# Detection: anything whose min(R,G,B) is BELOW this is treated as chick.
# Lower → ignores faint anti-aliasing / compression noise.
WHITE_THRESHOLD = 225
ROW_MIN_PIXELS = 6

# Final alpha softening: pixels with min(R,G,B) up to here are still kept
# fully opaque; pixels above fade smoothly to transparent over FALLOFF range.
ALPHA_THRESHOLD = 245
ALPHA_FALLOFF = 18


def build_chick_mask(arr: np.ndarray) -> np.ndarray:
    rgb_min = np.minimum(np.minimum(arr[..., 0], arr[..., 1]), arr[..., 2])
    return rgb_min < WHITE_THRESHOLD


def crop_chicks(img: Image.Image) -> list:
    arr = np.array(img)
    mask = build_chick_mask(arr)
    W = img.size[0]
    crops = []
    for i in range(4):
        x0 = int(round(i * W / 4))
        x1 = int(round((i + 1) * W / 4))
        strip_mask = mask[:, x0:x1]
        row_counts = strip_mask.sum(axis=1)
        col_counts = strip_mask.sum(axis=0)
        rows = np.where(row_counts >= ROW_MIN_PIXELS)[0]
        cols = np.where(col_counts >= ROW_MIN_PIXELS)[0]
        if len(rows) == 0 or len(cols) == 0:
            print(f"  strip {i}: appears empty")
            continue
        bbox = (x0 + int(cols[0]), int(rows[0]),
                x0 + int(cols[-1]) + 1, int(rows[-1]) + 1)
        crop = img.crop(bbox)
        crops.append(crop)
    return crops


def soften_white_to_alpha(rgba: np.ndarray) -> np.ndarray:
    rgb_min = np.minimum(np.minimum(rgba[..., 0], rgba[..., 1]), rgba[..., 2]).astype(np.float32)
    edge_lo = ALPHA_THRESHOLD - ALPHA_FALLOFF
    edge_hi = ALPHA_THRESHOLD
    alpha_f = np.clip((edge_hi - rgb_min) / (edge_hi - edge_lo), 0.0, 1.0)
    rgba = rgba.astype(np.float32)
    rgba[..., 3] = rgba[..., 3] * alpha_f
    return rgba.astype(np.uint8)


def process(src_path: str, dst_path: str) -> bool:
    img = Image.open(src_path).convert("RGBA")
    name = os.path.basename(src_path)
    print(f"\n{name} ({img.size[0]}×{img.size[1]})")

    crops = crop_chicks(img)
    if len(crops) < 4:
        print(f"  ERROR: detected {len(crops)} chicks (need 4) — skipping")
        return False

    print(f"  4 chicks detected:")
    for i, c in enumerate(crops):
        print(f"    [{i}] {c.size[0]}×{c.size[1]}")

    # Uniform scale across all 4 chicks so they appear the same size in-game.
    max_w = max(c.size[0] for c in crops)
    max_h = max(c.size[1] for c in crops)
    inner = TARGET_FRAME - 2 * INNER_PADDING
    scale = inner / max(max_w, max_h)

    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for i, chick in enumerate(crops):
        cw, ch = chick.size
        new_w = max(1, int(round(cw * scale)))
        new_h = max(1, int(round(ch * scale)))
        resized = chick.resize((new_w, new_h), Image.LANCZOS)
        rc = soften_white_to_alpha(np.array(resized))
        chick_a = Image.fromarray(rc, "RGBA")

        cell_x = i * TARGET_FRAME + (TARGET_FRAME - new_w) // 2
        cell_y = max(INNER_PADDING, TARGET_FRAME - new_h - BOTTOM_OFFSET)
        sheet.paste(chick_a, (cell_x, cell_y), chick_a)

    sheet.save(dst_path)
    print(f"  → {os.path.basename(dst_path)} (256×64)")
    return True


def main() -> None:
    if not os.path.isdir(SRC_DIR):
        print(f"missing dir: {SRC_DIR}")
        sys.exit(1)

    ok = 0
    for src_name, dst_name in STYLE_MAP.items():
        src = os.path.join(SRC_DIR, src_name)
        dst = os.path.join(ROOT, dst_name)
        if not os.path.exists(src):
            print(f"SKIP {src_name} (missing in new-chicks/)")
            continue
        if process(src, dst):
            ok += 1
    print(f"\n=== processed {ok} / {len(STYLE_MAP)} ===")


if __name__ == "__main__":
    main()
