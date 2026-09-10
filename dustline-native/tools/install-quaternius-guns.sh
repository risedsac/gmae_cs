#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT_DIR/assets/third_party/quaternius/ultimate_guns"
mkdir -p "$DEST"

BASE="https://raw.githubusercontent.com/AetherRadar/operation-steel-tide/main/assets/models/quaternius_ultimate_guns"
FILES=(ak74.glb p226.glb scarl.glb awm.glb LICENSE.md)

for file in "${FILES[@]}"; do
  echo "Downloading $file ..."
  curl -fL --retry 3 --connect-timeout 15 \
    "$BASE/$file" \
    -o "$DEST/$file"
done

cat > "$DEST/README.md" <<'EOF'
# Quaternius Ultimate Guns Pack subset

Installed by `tools/install-quaternius-guns.sh`.

Runtime mapping in Dustline:

- `ak74.glb` -> AK-47 visual
- `p226.glb` -> P9 visual
- `scarl.glb` -> M4A1 visual
- `awm.glb` -> AWP visual

These names are gameplay mappings only; the source models are generic weapon models from Quaternius Ultimate Guns Pack.

License: CC0 1.0 Universal. See `LICENSE.md`.
EOF

echo
echo "Installed Quaternius weapon visuals to:"
echo "  $DEST"
echo
echo "Now open the Godot project; scripts/weapons.gd will pick these models automatically."
