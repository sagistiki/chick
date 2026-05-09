#!/usr/bin/env python3
"""
Process the AI-generated chick reference image (chickchick-new.png) into a
clean spritesheet for the engine.

Input:  chickchick-new.png — 4 chicks on a white background, varying spacing.
Output: chick_realistic.png — 256 × 64 px, 4 horizontal frames of 64 × 64,
        each chick centred horizontally, bottom-aligned, soft transparent
        background.
"""
import os
import sys
import wave  # noqa  (kept for parity with project tooling, unused)
from PIL import Image

try:
    import numpy as np
except ImportError:
    print("numpy is required: pip3 install numpy pillow")
    sys.exit(1)

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "chickchick-new.png")
DST = os.path.join(ROOT, "chick_realistic.png")

TARGET_FRAME = 64
SHEET_W = TARGET_FRAME * 4
SHEET_H = TARGET_FRAME
INNER_PADDING = 3       # px of empty space around the chick inside the frame
BOTTOM_OFFSET = 2       # px from the bottom of the frame to the chick's feet

# Anything with min(R,G,B) above this is treated as background (white).
# Lower threshold → ignores faint anti-aliasing / compression noise around chicks
# so the bbox detection finds tight crops on real chick pixels only.
WHITE_THRESHOLD = 225
# Pixels below this many non-white pixels in a row/column are treated as noise.
ROW_MIN_PIXELS = 6
# Soft alpha falloff for the final composited image (more permissive than the
# detection threshold so we keep the chick's natural aliased silhouette).
ALPHA_THRESHOLD = 245
ALPHA_FALLOFF = 18


def load_source() -> Image.Image:
    img = Image.open(SRC).convert("RGBA")
    print(f"source: {img.size[0]}×{img.size[1]}")
    return img


def build_chick_mask(arr: np.ndarray) -> np.ndarray:
    """True where the pixel is *not* near-white background."""
    rgb_min = np.minimum(np.minimum(arr[..., 0], arr[..., 1]), arr[..., 2])
    return rgb_min < WHITE_THRESHOLD


def crop_chicks(img: Image.Image) -> list:
    """Split into 4 equal vertical strips and tight-crop each chick within."""
    arr = np.array(img)
    mask = build_chick_mask(arr)
    W = img.size[0]
    crops = []
    for i in range(4):
        x0 = int(round(i * W / 4))
        x1 = int(round((i + 1) * W / 4))
        strip_mask = mask[:, x0:x1]
        # Per-row / per-column counts so we can ignore rows/cols that only have
        # a handful of stray non-white pixels (compression noise).
        row_counts = strip_mask.sum(axis=1)
        col_counts = strip_mask.sum(axis=0)
        rows = np.where(row_counts >= ROW_MIN_PIXELS)[0]
        cols = np.where(col_counts >= ROW_MIN_PIXELS)[0]
        if len(rows) == 0 or len(cols) == 0:
            print(f"  strip {i}: appears empty — skipping")
            continue
        bbox = (x0 + int(cols[0]), int(rows[0]),
                x0 + int(cols[-1]) + 1, int(rows[-1]) + 1)
        crop = img.crop(bbox)
        print(f"  strip {i}: bbox {bbox} → {crop.size[0]}×{crop.size[1]}")
        crops.append(crop)
    return crops


def soften_white_to_alpha(rgba: np.ndarray) -> np.ndarray:
    """White pixels become transparent; near-white pixels fade out smoothly to
    avoid a hard ring around the chick."""
    rgb_min = np.minimum(np.minimum(rgba[..., 0], rgba[..., 1]), rgba[..., 2]).astype(np.float32)
    edge_lo = ALPHA_THRESHOLD - ALPHA_FALLOFF
    edge_hi = ALPHA_THRESHOLD
    alpha_f = np.clip((edge_hi - rgb_min) / (edge_hi - edge_lo), 0.0, 1.0)
    rgba = rgba.astype(np.float32)
    rgba[..., 3] = rgba[..., 3] * alpha_f
    return rgba.astype(np.uint8)


def main() -> None:
    img = load_source()
    crops = crop_chicks(img)
    if not crops:
        print("ERROR: no chicks detected")
        sys.exit(1)

    # Use a single uniform scale for all 4 chicks so they appear the same size.
    max_w = max(c.size[0] for c in crops)
    max_h = max(c.size[1] for c in crops)
    inner = TARGET_FRAME - 2 * INNER_PADDING
    scale = inner / max(max_w, max_h)
    print(f"uniform scale: {scale:.4f}  (inner box {inner}×{inner})")

    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))

    for i, chick in enumerate(crops):
        cw, ch = chick.size
        new_w = max(1, int(round(cw * scale)))
        new_h = max(1, int(round(ch * scale)))
        resized = chick.resize((new_w, new_h), Image.LANCZOS)
        rc = np.array(resized)
        rc = soften_white_to_alpha(rc)
        chick_a = Image.fromarray(rc, "RGBA")

        cell_x = i * TARGET_FRAME + (TARGET_FRAME - new_w) // 2
        cell_y = TARGET_FRAME - new_h - BOTTOM_OFFSET
        if cell_y < INNER_PADDING:
            cell_y = INNER_PADDING

        sheet.paste(chick_a, (cell_x, cell_y), chick_a)
        print(f"  frame {i}: placed at ({cell_x}, {cell_y}), size {new_w}×{new_h}")

    sheet.save(DST)
    print(f"\nwrote {DST} ({SHEET_W}×{SHEET_H})")


if __name__ == "__main__":
    main()
