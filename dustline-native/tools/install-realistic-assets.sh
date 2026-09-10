#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_ROOT="$ROOT_DIR/assets/third_party/realistic_weapons"
AUDIO_ROOT="$ROOT_DIR/assets/audio/realistic_weapons"
STEIN_ROOT="$REAL_ROOT/stein_classic_weapons"
mkdir -p "$REAL_ROOT/ak47" "$REAL_ROOT/m4a1" "$AUDIO_ROOT"

command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }

fetch() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  echo "Downloading $(basename "$dest") ..."
  curl -fL --retry 3 --connect-timeout 20 "$url" -o "$dest"
}

STEEL="https://raw.githubusercontent.com/AetherRadar/operation-steel-tide/main"

# Godot-ready, detailed PBR firearms. The source/license records are retained
# beside each downloaded model. AK geometry is CC0; its replacement texture
# pass is covered by Operation Steel Tide's MIT license. M4A1 sources are CC0.
fetch "$STEEL/assets/models/steel_tide_ak74/ak47_reloadable_fp.glb" \
  "$REAL_ROOT/ak47/ak47_reloadable_fp.glb"
fetch "$STEEL/assets/models/steel_tide_ak74/LICENSE.md" \
  "$REAL_ROOT/ak47/LICENSE.md"
fetch "$STEEL/assets/models/steel_tide_m4a1/steel_tide_m4a1.glb" \
  "$REAL_ROOT/m4a1/steel_tide_m4a1.glb"
fetch "$STEEL/assets/models/steel_tide_m4a1/LICENSE.md" \
  "$REAL_ROOT/m4a1/LICENSE.md"
fetch "$STEEL/LICENSE" "$REAL_ROOT/OPERATION-STEEL-TIDE-MIT.txt"

# Real firearm field recordings prepared into three runtime perspectives:
# player-near, positional world, and distant enemy. Upstream recordings are
# The Free Firearm Sound Library (CC0).
for profile in ak74 p226 m4a1 awm; do
  mkdir -p "$AUDIO_ROOT/$profile"
  for role in player_near world enemy_distant; do
    fetch "$STEEL/assets/audio/weapons/$profile/${profile}_${role}.wav" \
      "$AUDIO_ROOT/$profile/${profile}_${role}.wav"
  done
done

MANIFEST="$REAL_ROOT/manifest.cfg"
rm -f "$MANIFEST"

if [[ $# -ge 1 ]]; then
  ZIP="$1"
  [[ -f "$ZIP" ]] || { echo "error: Stein pack not found: $ZIP" >&2; exit 1; }
  command -v unzip >/dev/null || { echo "error: unzip is required for the Stein pack" >&2; exit 1; }
  rm -rf "$STEIN_ROOT"
  mkdir -p "$STEIN_ROOT"
  echo "Extracting Stein Games Classic Weapons Pack ..."
  unzip -q -o "$ZIP" -d "$STEIN_ROOT"

  find_weapon() {
    local regex="$1"
    find "$STEIN_ROOT" -type f \( -iname '*.fbx' -o -iname '*.glb' \) -print \
      | grep -Ei "$regex" | head -n 1 || true
  }

  PISTOL="$(find_weapon '(^|[/ _-])(m?1911|colt.?1911)([/ _.-]|$)')"
  SNIPER="$(find_weapon '(^|[/ _-])([mr]700|remington.?700)([/ _.-]|$)')"

  if [[ -z "$PISTOL" || -z "$SNIPER" ]]; then
    echo "error: could not locate both 1911 and M700/R700 models in the Stein archive." >&2
    echo "Found model files:" >&2
    find "$STEIN_ROOT" -type f \( -iname '*.fbx' -o -iname '*.glb' \) -print >&2
    exit 2
  fi

  PISTOL_REL="${PISTOL#"$ROOT_DIR/"}"
  SNIPER_REL="${SNIPER#"$ROOT_DIR/"}"
  cat > "$MANIFEST" <<EOF
[weapons]
pistol="res://$PISTOL_REL"
sniper="res://$SNIPER_REL"
EOF

  echo "Stein pistol: $PISTOL_REL"
  echo "Stein sniper: $SNIPER_REL"
else
  cat > "$MANIFEST" <<'EOF'
[weapons]
pistol=""
sniper=""
EOF
  echo
  echo "AK-47, M4A1 and realistic firearm audio are installed."
  echo "For the high-detail P9/1911 and M700 sniper visuals, download:"
  echo "  https://stein-indie.itch.io/classic-weapons-pack"
  echo "Then run this script again and pass the downloaded ZIP as its first argument, e.g.:"
  echo "  bash tools/install-realistic-assets.sh ~/Downloads/'Classic Weapons Pack v1.1.zip'"
fi

echo
echo "Installed realistic FPS assets."
echo "Run the SOURCE project (do not use the old Dustline.pck):"
echo "  ./engine/Godot.x86_64 --path ."
