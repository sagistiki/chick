#!/bin/bash
# Build the app, zip it for distribution, and stage GitHub-Pages assets
# (sprite sheets + icon) under docs/.
#
#   ./package.sh           # full build + package
#   ./package.sh --pages   # only refresh docs/ assets (for Pages updates)

set -euo pipefail
cd "$(dirname "$0")"

PAGES_ONLY=0
[ "${1:-}" = "--pages" ] && PAGES_ONLY=1

if [ "$PAGES_ONLY" = "0" ]; then
  echo "==> Building Chick.app"
  ./build.sh
fi

# ----- Stage docs/ assets so GitHub Pages can show the live demo ----------
echo "==> Staging GitHub Pages assets in docs/"
mkdir -p docs/sprites

# Sprite sheets used by index.html for the live walk-cycle demos
for style in anime realistic memoji lego embroidered oil psx; do
  src="chick_${style}.png"
  if [ -f "$src" ]; then
    cp "$src" "docs/sprites/chicken_${style}.png"
  else
    echo "  warn: $src missing — that style will be blank on the page"
  fi
done

# App icon at 256×256 for the page hero / favicon
if [ -f .build/render_icon ] && [ -f icon.svg ]; then
  .build/render_icon icon.svg 256 docs/icon.png
fi

if [ "$PAGES_ONLY" = "1" ]; then
  echo "Pages assets refreshed. Commit & push docs/ to update the site."
  exit 0
fi

# ----- Zip the .app for the GitHub release --------------------------------
echo "==> Packaging Chick.zip for release"
mkdir -p dist
rm -f dist/Chick.zip

# `ditto` preserves macOS metadata + extended attributes; `zip` strips them.
/usr/bin/ditto -c -k --sequesterRsrc --keepParent Chick.app dist/Chick.zip

SIZE=$(du -h dist/Chick.zip | cut -f1)
echo
echo "✅ dist/Chick.zip ready ($SIZE)"
echo
echo "Next steps:"
echo "  1.  git add . && git commit -m 'release v1.0' && git push"
echo "  2.  Create a GitHub release and upload dist/Chick.zip as the asset."
echo "  3.  In repo settings → Pages: source = main branch, folder = /docs."
echo "  4.  Edit docs/index.html — replace YOUR-USERNAME with your handle."
