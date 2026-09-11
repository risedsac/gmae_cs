#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_ROOT="$ROOT_DIR/assets/third_party/realistic_weapons"
AUDIO_ROOT="$ROOT_DIR/assets/audio/realistic_weapons"
SFX_ROOT="$ROOT_DIR/assets/audio/realistic_sfx"
UTILITY_ROOT="$ROOT_DIR/assets/third_party/realistic_utility"
STEIN_ROOT="$REAL_ROOT/stein_classic_weapons"
STEIN_RUNTIME="$REAL_ROOT/stein_runtime"
GODOT="$ROOT_DIR/engine/Godot.x86_64"
mkdir -p "$REAL_ROOT/ak47" "$REAL_ROOT/m4a1" "$REAL_ROOT/fallback" "$AUDIO_ROOT" "$SFX_ROOT" "$UTILITY_ROOT" "$STEIN_RUNTIME"

command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }
command -v unzip >/dev/null || { echo "error: unzip is required" >&2; exit 1; }

fetch() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  echo "Downloading $(basename "$dest") ..."
  curl -fL --retry 3 --connect-timeout 20 "$url" -o "$dest"
}

STEEL="https://raw.githubusercontent.com/AetherRadar/operation-steel-tide/main"
OGA="https://opengameart.org/sites/default/files"

# High-detail Godot-ready PBR long guns.
fetch "$STEEL/assets/models/steel_tide_ak74/ak47_reloadable_fp.glb" \
  "$REAL_ROOT/ak47/ak47_reloadable_fp.glb"
fetch "$STEEL/assets/models/steel_tide_ak74/LICENSE.md" \
  "$REAL_ROOT/ak47/LICENSE.md"
fetch "$STEEL/assets/models/steel_tide_m4a1/steel_tide_m4a1.glb" \
  "$REAL_ROOT/m4a1/steel_tide_m4a1.glb"
fetch "$STEEL/assets/models/steel_tide_m4a1/LICENSE.md" \
  "$REAL_ROOT/m4a1/LICENSE.md"
fetch "$STEEL/LICENSE" "$REAL_ROOT/OPERATION-STEEL-TIDE-MIT.txt"

# Validated Godot-ready sidearm/sniper GLBs.  These are deliberately the
# runtime defaults even when a Stein pack is present: the previous Stein FBX
# conversion could load successfully yet land outside the first-person camera.
fetch "$STEEL/assets/models/steel_tide_reloadable_weapons/p226_reloadable.glb" \
  "$REAL_ROOT/fallback/p226_reloadable.glb"
fetch "$STEEL/assets/models/steel_tide_reloadable_weapons/awm_reloadable.glb" \
  "$REAL_ROOT/fallback/awm_reloadable.glb"
fetch "$STEEL/assets/models/steel_tide_reloadable_weapons/LICENSE.md" \
  "$REAL_ROOT/fallback/LICENSE.md"

# Real firearm field recordings: near player, positional world and distant.
for profile in ak74 p226 m4a1 awm; do
  mkdir -p "$AUDIO_ROOT/$profile"
  for role in player_near world enemy_distant; do
    fetch "$STEEL/assets/audio/weapons/$profile/${profile}_${role}.wav" \
      "$AUDIO_ROOT/$profile/${profile}_${role}.wav"
  done
done

# The close-mic recordings are intentionally very dry.  Preserve their real
# muzzle crack, but mix in low-level delayed reflection + a separate real
# distant-microphone tail so first-person fire does not sound like a synthetic
# one-shot sample.  The mixer contains no generated oscillator/noise layers.
if command -v python3 >/dev/null; then
  python3 "$ROOT_DIR/tools/build_field_gunshot_mix.py" "$AUDIO_ROOT"
else
  echo "warning: python3 not found; keeping the dry field-recorded gunshots." >&2
fi

# Replace the old generated/mechanical placeholders with CC0 recorded assets.
fetch "$OGA/reload.wav" "$SFX_ROOT/pistol_reload.wav"
fetch "$OGA/assaultriflereload1.wav" "$SFX_ROOT/rifle_reload.wav"
fetch "$OGA/equipmentclick.wav" "$SFX_ROOT/equipment_click.wav"
fetch "$OGA/Dynamite%20with%20sensor.wav" "$SFX_ROOT/explosion.wav"

TMP_AUDIO="$ROOT_DIR/.realistic_audio_tmp"
rm -rf "$TMP_AUDIO"; mkdir -p "$TMP_AUDIO"
fetch "$OGA/steam_hisses.zip" "$TMP_AUDIO/steam_hisses.zip"
unzip -q -o "$TMP_AUDIO/steam_hisses.zip" -d "$TMP_AUDIO/hiss"
HISS="$(find "$TMP_AUDIO/hiss" -type f \( -iname '*.wav' -o -iname '*.ogg' \) | head -n 1 || true)"
[[ -n "$HISS" ]] && cp -f "$HISS" "$SFX_ROOT/smoke_hiss.${HISS##*.}"

fetch "$OGA/kenney_interfaceSounds.zip" "$TMP_AUDIO/ui.zip"
unzip -q -o "$TMP_AUDIO/ui.zip" -d "$TMP_AUDIO/ui"
UI_CONFIRM="$(find "$TMP_AUDIO/ui" -type f \( -iname '*.wav' -o -iname '*.ogg' \) | grep -Ei 'confirm|confirmation|select|click' | head -n 1 || true)"
[[ -z "$UI_CONFIRM" ]] && UI_CONFIRM="$(find "$TMP_AUDIO/ui" -type f \( -iname '*.wav' -o -iname '*.ogg' \) | head -n 1 || true)"
[[ -n "$UI_CONFIRM" ]] && cp -f "$UI_CONFIRM" "$SFX_ROOT/ui_confirm.${UI_CONFIRM##*.}"
rm -rf "$TMP_AUDIO"

# CC0 frag/smoke projectile models. Copy to stable filenames so the runtime
# does not depend on the pack's internal directory naming.
TMP_GRENADE="$ROOT_DIR/.grenade_asset_tmp"
rm -rf "$TMP_GRENADE"; mkdir -p "$TMP_GRENADE"
fetch "$OGA/flat_grenades.zip" "$TMP_GRENADE/flat_grenades.zip"
unzip -q -o "$TMP_GRENADE/flat_grenades.zip" -d "$TMP_GRENADE/src"
SMOKE_MODEL="$(find "$TMP_GRENADE/src" -type f -iname '*.glb' | grep -Ei 'smoke' | head -n 1 || true)"
FRAG_MODEL="$(find "$TMP_GRENADE/src" -type f -iname '*.glb' | grep -Eiv 'smoke|flash|incend' | grep -Ei 'frag|grenade|he' | head -n 1 || true)"
if [[ -n "$FRAG_MODEL" ]]; then cp -f "$FRAG_MODEL" "$UTILITY_ROOT/he_grenade.glb"; fi
if [[ -n "$SMOKE_MODEL" ]]; then cp -f "$SMOKE_MODEL" "$UTILITY_ROOT/smoke_grenade.glb"; fi
rm -rf "$TMP_GRENADE"

MANIFEST="$REAL_ROOT/manifest.cfg"
# Keep these runtime paths pinned to GLBs already authored for the same Godot
# weapon contract.  Stein conversion is retained below as an experimental
# preview/export path, but no longer silently overrides a working first-person
# sidearm/sniper with an off-screen model.
PISTOL_PATH="res://assets/third_party/realistic_weapons/fallback/p226_reloadable.glb"
SNIPER_PATH="res://assets/third_party/realistic_weapons/fallback/awm_reloadable.glb"

# If the user supplied Stein's high-poly pack (or a previous extraction exists),
# convert the FBX + separate PBR textures into self-contained GLBs for inspection.
# They are not selected as runtime defaults until their first-person transform is
# validated independently.
if [[ $# -ge 1 ]]; then
  ZIP="$1"
  [[ -f "$ZIP" ]] || { echo "error: Stein pack not found: $ZIP" >&2; exit 1; }
  rm -rf "$STEIN_ROOT"; mkdir -p "$STEIN_ROOT"
  echo "Extracting Stein Games Classic Weapons Pack ..."
  unzip -q -o "$ZIP" -d "$STEIN_ROOT"
fi

if [[ -d "$STEIN_ROOT" ]]; then
  find_weapon() {
    local regex="$1"
    find "$STEIN_ROOT" -type f -iname '*.fbx' -print | grep -Ei "$regex" | head -n 1 || true
  }
  PISTOL="$(find_weapon '(^|[/ _-])(m?1911|colt.?1911)([/ _.-]|$)')"
  SNIPER="$(find_weapon '(^|[/ _-])([mr]700|remington.?700)([/ _.-]|$)')"
  BLENDER="$(command -v blender || true)"
  if [[ -n "$PISTOL" && -n "$SNIPER" && -n "$BLENDER" ]]; then
    echo "Converting Stein 1911 + M700 into packed PBR preview GLBs ..."
    if "$BLENDER" -b --python "$ROOT_DIR/tools/convert_stein_weapon.py" -- \
        "$PISTOL" "$STEIN_RUNTIME/1911.glb" "$STEIN_ROOT" pistol \
      && "$BLENDER" -b --python "$ROOT_DIR/tools/convert_stein_weapon.py" -- \
        "$SNIPER" "$STEIN_RUNTIME/m700.glb" "$STEIN_ROOT" sniper; then
      echo "Stein conversion succeeded (preview only; runtime keeps validated P226/AWM GLBs)."
    else
      echo "warning: Stein conversion failed; runtime is unaffected and keeps P226/AWM GLBs." >&2
    fi
  elif [[ -z "$BLENDER" ]]; then
    echo "warning: Blender not found; runtime keeps validated P226/AWM GLBs." >&2
  else
    echo "warning: Stein 1911/M700 FBX files were not found; runtime keeps P226/AWM GLBs." >&2
  fi
fi

cat > "$MANIFEST" <<EOF
[weapons]
pistol="$PISTOL_PATH"
sniper="$SNIPER_PATH"

[utility]
he="res://assets/third_party/realistic_utility/he_grenade.glb"
smoke="res://assets/third_party/realistic_utility/smoke_grenade.glb"
EOF

if [[ -x "$GODOT" ]]; then
  echo
  echo "Importing downloaded assets into Godot..."
  "$GODOT" --headless --path "$ROOT_DIR" --import
else
  echo
  echo "warning: bundled Godot editor not found at $GODOT"
  echo "Run: godot --headless --path '$ROOT_DIR' --import"
fi

echo
echo "Installed realistic weapons, utility models and field-recorded SFX."
echo "Runtime sidearm/sniper: validated P226/AWM GLBs."
echo "First-person gunshots: close mic + real recorded room/distant tail mix."
echo "Run the SOURCE project:"
echo "  ./engine/Godot.x86_64 --path ."
