#!/usr/bin/env python3
"""
Shrinks the AI-generated reference PNGs in new-chicks/ to half their original
dimensions and re-saves with PNG optimisation. Plenty of detail remains for
re-processing if we ever tweak the spritesheet pipeline, but the on-disk
footprint drops by ~70-80%.
"""

import os
import sys

try:
    from PIL import Image
except ImportError:
    print("requires: pip3 install pillow")
    sys.exit(1)

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(ROOT, "new-chicks")

# Halve the dimensions; well above what process_all_chicks.py needs (it reduces
# to 256×64 anyway). 1584×672 → 792×336 keeps every fine detail visible.
SCALE = 0.5


def shrink_one(path: str) -> tuple:
    img = Image.open(path)
    before = os.path.getsize(path)
    new_w = max(1, int(round(img.size[0] * SCALE)))
    new_h = max(1, int(round(img.size[1] * SCALE)))
    img.thumbnail((new_w, new_h), Image.LANCZOS)
    img.save(path, format="PNG", optimize=True, compress_level=9)
    after = os.path.getsize(path)
    return before, after, img.size


def main() -> None:
    if not os.path.isdir(SRC_DIR):
        print(f"missing dir: {SRC_DIR}")
        sys.exit(1)

    total_before = 0
    total_after = 0
    for name in sorted(os.listdir(SRC_DIR)):
        if not name.lower().endswith(".png"):
            continue
        path = os.path.join(SRC_DIR, name)
        before, after, dims = shrink_one(path)
        total_before += before
        total_after += after
        kb_before = before / 1024
        kb_after = after / 1024
        saved_pct = (1 - after / before) * 100 if before else 0
        print(f"{name:24s}  {dims[0]:>4}×{dims[1]:<4}  "
              f"{kb_before:6.1f} KB → {kb_after:6.1f} KB  (-{saved_pct:.0f}%)")

    if total_before:
        total_pct = (1 - total_after / total_before) * 100
        print(f"\ntotal: {total_before/1024/1024:.2f} MB → "
              f"{total_after/1024/1024:.2f} MB  (-{total_pct:.0f}%)")


if __name__ == "__main__":
    main()
