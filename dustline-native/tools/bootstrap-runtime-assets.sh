#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# First build/download the complete audio + utility set using the normal installer.
if [[ $# -ge 1 && -n "${1:-}" ]]; then
  bash "$ROOT_DIR/tools/install-realistic-assets.sh" "$1"
else
  bash "$ROOT_DIR/tools/install-realistic-assets.sh"
fi

# Pin the first-person contract-critical files to the reviewed Steel Tide revision.
# This avoids upstream-main drift silently changing socket names/hierarchies.
STEEL_REV="92e6db61b4babe567c3f17779e64d8b62eaa6e50"
STEEL="https://raw.githubusercontent.com/AetherRadar/operation-steel-tide/$STEEL_REV"
REAL_ROOT="$ROOT_DIR/assets/third_party/realistic_weapons"
ARMS_ROOT="$ROOT_DIR/assets/third_party/djmaesen_arms"

fetch_exact() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  curl -fL --retry 3 --connect-timeout 20 "$url" -o "$dest"
}

check_sha256() {
  local expected="$1" path="$2"
  local actual
  actual="$(sha256sum "$path" | awk '{print toupper($1)}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "error: asset hash mismatch: $path" >&2
    echo " expected=$expected" >&2
    echo " actual=$actual" >&2
    exit 1
  fi
}

fetch_exact "$STEEL/assets/models/steel_tide_reloadable_weapons/p226_reloadable.glb" "$REAL_ROOT/fallback/p226_reloadable.glb"
fetch_exact "$STEEL/assets/models/steel_tide_reloadable_weapons/awm_reloadable.glb" "$REAL_ROOT/fallback/awm_reloadable.glb"
fetch_exact "$STEEL/assets/models/steel_tide_m4a1/steel_tide_m4a1.glb" "$REAL_ROOT/m4a1/steel_tide_m4a1.glb"
for file in \
  smg45_rifle_arms.glb \
  smg45_rifle_arms_Image_0.png \
  smg45_rifle_arms_Image_1.png \
  smg45_rifle_arms_Image_2.png \
  smg45_pistol_service_arms.glb \
  smg45_pistol_service_arms_Image_0.png \
  smg45_pistol_service_arms_Image_1.png \
  smg45_pistol_service_arms_Image_2.png \
  animated_reload_arms.glb \
  animated_reload_arms_Image_0.png \
  animated_reload_arms_Image_1.png \
  animated_reload_arms_Image_2.png; do
  fetch_exact "$STEEL/assets/models/djmaesen_smg45/$file" "$ARMS_ROOT/$file"
done

# Verify the immutable upstream assets before applying the local marker-only
# first-person adapter. The patch never changes visible mesh/mechanism data.
check_sha256 "579CB38E8F861ECAC5B7C7739946C4620046FFFAF94EE5E073CB69B913DB72FC" "$REAL_ROOT/fallback/p226_reloadable.glb"
check_sha256 "FFA2FE9DD07771650D55D60FAAC6715336ECD087D57373BA5C4139B3E0C73807" "$REAL_ROOT/fallback/awm_reloadable.glb"

# The upstream supplemental P226/AWM exports intentionally omit the two static
# first-person grip markers required by Dustline. Re-importing cannot create
# absent nodes, so inject calibrated root-local marker nodes before Godot sees
# the files. Real Magazine/ChargingHandle geometry and their sockets remain the
# original reviewed upstream nodes.
python3 "$ROOT_DIR/tools/patch_weapon_grip_sockets.py" \
  --profile p226 "$REAL_ROOT/fallback/p226_reloadable.glb"
python3 "$ROOT_DIR/tools/patch_weapon_grip_sockets.py" \
  --profile awm "$REAL_ROOT/fallback/awm_reloadable.glb"

find_godot() {
  local candidate=""
  for candidate in \
    "${DUSTLINE_GODOT:-}" \
    "$ROOT_DIR/engine/Godot.x86_64" \
    "$ROOT_DIR/../../outputs/Dustline-Linux/engine/Godot.x86_64"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if command -v godot4 >/dev/null 2>&1; then command -v godot4; return 0; fi
  if command -v godot >/dev/null 2>&1; then command -v godot; return 0; fi
  return 1
}

GODOT="$(find_godot || true)"
if [[ -z "$GODOT" ]]; then
  echo "error: no Godot executable was found; assets were downloaded but cannot be accepted before import." >&2
  echo "Set DUSTLINE_GODOT=/absolute/path/to/Godot.x86_64 and run this script again." >&2
  exit 1
fi

echo "[DUSTLINE BOOTSTRAP] Godot: $GODOT"
echo "[DUSTLINE BOOTSTRAP] importing generated/downloaded resources..."
"$GODOT" --headless --path "$ROOT_DIR" --import

echo "[DUSTLINE BOOTSTRAP] validating sockets, reload clips and multisample audio..."
"$GODOT" --headless --path "$ROOT_DIR" --script res://tools/verify_runtime_assets.gd

echo "[DUSTLINE BOOTSTRAP] running source feature acceptance checks..."
"$GODOT" --headless --path "$ROOT_DIR" --script res://tools/verify_features.gd

echo "[DUSTLINE BOOTSTRAP] running source-project smoke test..."
"$GODOT" --headless --path "$ROOT_DIR" -- --smoke

echo "[DUSTLINE BOOTSTRAP] OK — imported, contract-checked and source-tested."
