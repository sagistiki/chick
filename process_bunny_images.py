#!/usr/bin/env python3
"""
Process the AI-generated bunny reference images (bunny-shots/*.png) into clean
4-frame spritesheets for the engine.

Mirrors process_chick_image.py but for transparent-background sources:

Input:  bunny-shots/<style>-bunny.png — large RGBA strip with 4 bunnies at
        roughly even spacing, alpha already separated from the background.
        Source size is typically 1584 × 672 (each frame ~396 × 672).
Output: bunny_<style>.png — 256 × 64 px, 4 horizontal frames of 64 × 64,
        each bunny tight-cropped, scaled uniformly so all 4 frames share the
        same pixel scale, centred horizontally, bottom-aligned to the cell.

Style key mapping handles the source filename quirks (e.g. "embroided" →
"embroidered") so the output names line up with the BunnyStyle catalogue.

Resampling: LANCZOS (highest-quality reduction in Pillow).
PNG output: optimize=True for size; lossless.
"""
import os
import sys

from PIL import Image

try:
    import numpy as np
except ImportError:
    print("numpy is required: pip3 install numpy pillow")
    sys.exit(1)

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(ROOT, "bunny-shots")

NAME_MAP = {
    "anime-bunny.png":      "bunny_anime.png",
    "realistic-bunny.png":  "bunny_realistic.png",
    "memoji-bunny.png":     "bunny_memoji.png",
    "lego-bunny.png":       "bunny_lego.png",
    "embroided-bunny.png":  "bunny_embroidered.png",
    "oil-bunny.png":        "bunny_oil.png",
    "psx-bunny.png":        "bunny_psx.png",
}

TARGET_FRAME = 64
SHEET_W = TARGET_FRAME * 4
SHEET_H = TARGET_FRAME
INNER_PADDING = 3       # min empty space around the bunny inside its cell
BOTTOM_OFFSET = 2       # px from cell bottom to bunny's feet (anchors hops)

# Alpha values below this are treated as transparent background. Slightly
# permissive so semi-transparent fur/fluff edges still count as bunny pixels
# during bbox detection.
ALPHA_BBOX_THRESHOLD = 12
# Rows / cols with fewer than this many bunny pixels are ignored in bbox
# detection — kills isolated stray dots from generator noise.
LINE_MIN_PIXELS = 6


def crop_bunnies(img: Image.Image) -> list:
    """Detect 4 bunnies by finding transparency valleys between them.

    Naïve fixed-quartile splits assume the AI-generated source places its
    subjects exactly at the quarter marks — but the bunny shots have uneven
    horizontal spacing (e.g. the airborne pose drifts to one side) and a
    fixed split clips the bodies that straddle the boundary. Instead we walk
    the image's column-density profile, treating runs of low-density columns
    as gaps and runs of high-density columns as subjects. Each subject's
    bounding box is then tight-cropped vertically inside its column range.

    Detection is alpha-based — any pixel with alpha >= ALPHA_BBOX_THRESHOLD
    counts as bunny. Per-column counting suppresses isolated noise dots so
    the gap detection stays stable.
    """
    arr = np.array(img)
    if arr.shape[2] < 4:
        raise ValueError("source image must be RGBA")
    alpha = arr[..., 3]
    mask = alpha >= ALPHA_BBOX_THRESHOLD
    W = img.size[0]

    # 1. Column density profile, ignoring columns with only stray pixels.
    col_counts = mask.sum(axis=0)
    is_subject_col = col_counts >= LINE_MIN_PIXELS

    # 2. Walk left-to-right collecting runs of subject columns.
    runs: list[tuple[int, int]] = []
    i = 0
    while i < W:
        if is_subject_col[i]:
            j = i
            while j < W and is_subject_col[j]:
                j += 1
            runs.append((i, j))   # half-open [i, j)
            i = j
        else:
            i += 1

    # 3. Bridge tiny gaps inside a single bunny — fluff like long ears or a
    #    raised paw can produce momentary low-density columns *within* one
    #    silhouette. We merge two runs if their gap is smaller than this many
    #    pixels relative to image width (~1% — a bunny is wider than 1% of
    #    the image, a gap between bunnies is ≫ that).
    intra_gap = max(8, W // 100)
    merged: list[tuple[int, int]] = []
    for r in runs:
        if merged and r[0] - merged[-1][1] <= intra_gap:
            merged[-1] = (merged[-1][0], r[1])
        else:
            merged.append(r)
    runs = merged

    # 4. If we somehow got more than 4 (extra speck of noise), keep the 4
    #    widest. If fewer than 4, two bunnies got merged — split the longest
    #    run at its narrowest interior column.
    if len(runs) > 4:
        runs = sorted(runs, key=lambda r: -(r[1] - r[0]))[:4]
        runs.sort(key=lambda r: r[0])
    while len(runs) < 4:
        widest_idx = max(range(len(runs)), key=lambda k: runs[k][1] - runs[k][0])
        a, b = runs[widest_idx]
        if b - a < 40:
            print(f"    WARNING: only detected {len(runs)} subjects, can't split further")
            break
        # Find narrowest interior column — keep a small inset so we don't pick
        # an edge column that's almost-empty just because the silhouette ends.
        inset = (b - a) // 5
        inner_counts = col_counts[a + inset:b - inset]
        split_offset = int(np.argmin(inner_counts))
        split_col = a + inset + split_offset
        runs[widest_idx] = (a, split_col)
        runs.insert(widest_idx + 1, (split_col, b))

    # 5. Vertical tight-crop each detected run.
    crops = []
    for k, (x0, x1) in enumerate(runs):
        strip = mask[:, x0:x1]
        row_counts = strip.sum(axis=1)
        rows = np.where(row_counts >= LINE_MIN_PIXELS)[0]
        if len(rows) == 0:
            print(f"    subject {k}: empty — skipping")
            crops.append(None)
            continue
        bbox = (x0, int(rows[0]), x1, int(rows[-1]) + 1)
        crop = img.crop(bbox)
        print(f"    subject {k}: bbox {bbox} → {crop.size[0]}×{crop.size[1]}")
        crops.append(crop)
    return crops


def process_one(src_path: str, dst_path: str) -> bool:
    print(f"  source: {src_path}")
    img = Image.open(src_path).convert("RGBA")
    print(f"    size:  {img.size[0]}×{img.size[1]}")
    raw_crops = crop_bunnies(img)
    crops = [c for c in raw_crops if c is not None]
    if len(crops) < 4:
        print(f"    WARNING: detected {len(crops)} / 4 bunnies — output may be partial")
    if not crops:
        return False

    # Single uniform scale across all 4 frames so every bunny renders at the
    # same pixel size in the output sheet — preserves animation continuity.
    max_w = max(c.size[0] for c in crops)
    max_h = max(c.size[1] for c in crops)
    inner = TARGET_FRAME - 2 * INNER_PADDING
    scale = inner / max(max_w, max_h)
    print(f"    uniform scale: {scale:.4f}  (largest bbox {max_w}×{max_h} → "
          f"target inner {inner}×{inner})")

    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))

    for i, bunny in enumerate(raw_crops):
        if bunny is None:
            continue
        cw, ch = bunny.size
        new_w = max(1, int(round(cw * scale)))
        new_h = max(1, int(round(ch * scale)))
        resized = bunny.resize((new_w, new_h), Image.LANCZOS)

        cell_x = i * TARGET_FRAME + (TARGET_FRAME - new_w) // 2
        cell_y = TARGET_FRAME - new_h - BOTTOM_OFFSET
        if cell_y < INNER_PADDING:
            cell_y = INNER_PADDING

        sheet.paste(resized, (cell_x, cell_y), resized)
        print(f"    frame {i}: placed at ({cell_x}, {cell_y}), size {new_w}×{new_h}")

    sheet.save(dst_path, optimize=True)
    print(f"    wrote {dst_path}  ({SHEET_W}×{SHEET_H}, {os.path.getsize(dst_path)} bytes)")
    return True


def main() -> None:
    if not os.path.isdir(SRC_DIR):
        print(f"ERROR: source dir not found: {SRC_DIR}")
        sys.exit(1)

    print(f"processing bunny shots from {SRC_DIR}\n")
    n_done = 0
    for src_name, dst_name in sorted(NAME_MAP.items()):
        src_path = os.path.join(SRC_DIR, src_name)
        dst_path = os.path.join(ROOT, dst_name)
        if not os.path.exists(src_path):
            print(f"{src_name}: missing — skipping")
            continue
        print(f"{src_name} → {dst_name}")
        if process_one(src_path, dst_path):
            n_done += 1
        print()

    print(f"done: wrote {n_done} bunny spritesheet(s)")


if __name__ == "__main__":
    main()
