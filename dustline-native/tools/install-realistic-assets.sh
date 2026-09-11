#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_ROOT="$ROOT_DIR/assets/third_party/realistic_weapons"
AUDIO_ROOT="$ROOT_DIR/assets/audio/realistic_weapons"
SFX_ROOT="$ROOT_DIR/assets/audio/realistic_sfx"
UTILITY_ROOT="$ROOT_DIR/assets/third_party/realistic_utility"
ARMS_ROOT="$ROOT_DIR/assets/third_party/djmaesen_arms"
STEIN_ROOT="$REAL_ROOT/stein_classic_weapons"
STEIN_RUNTIME="$REAL_ROOT/stein_runtime"
GODOT="$ROOT_DIR/engine/Godot.x86_64"
mkdir -p "$REAL_ROOT/ak47" "$REAL_ROOT/m4a1" "$REAL_ROOT/fallback" \
  "$AUDIO_ROOT" "$SFX_ROOT" "$UTILITY_ROOT" "$ARMS_ROOT" "$STEIN_RUNTIME"

command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }
command -v unzip >/dev/null || { echo "error: unzip is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 is required for recorded-audio preparation" >&2; exit 1; }

fetch() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  echo "Downloading $(basename "$dest") ..."
  curl -fL --retry 3 --connect-timeout 20 "$url" -o "$dest"
}

STEEL="https://raw.githubusercontent.com/AetherRadar/operation-steel-tide/main"
OGA="https://opengameart.org/sites/default/files"

# Godot-ready PBR firearm contracts. These exports contain real mechanism and
# contact nodes; player code now binds exact sockets instead of matching bounds.
fetch "$STEEL/assets/models/steel_tide_ak74/ak47_reloadable_fp.glb" \
  "$REAL_ROOT/ak47/ak47_reloadable_fp.glb"
fetch "$STEEL/assets/models/steel_tide_ak74/LICENSE.md" \
  "$REAL_ROOT/ak47/LICENSE.md"
fetch "$STEEL/assets/models/steel_tide_m4a1/steel_tide_m4a1.glb" \
  "$REAL_ROOT/m4a1/steel_tide_m4a1.glb"
fetch "$STEEL/assets/models/steel_tide_m4a1/LICENSE.md" \
  "$REAL_ROOT/m4a1/LICENSE.md"
fetch "$STEEL/assets/models/steel_tide_reloadable_weapons/p226_reloadable.glb" \
  "$REAL_ROOT/fallback/p226_reloadable.glb"
fetch "$STEEL/assets/models/steel_tide_reloadable_weapons/awm_reloadable.glb" \
  "$REAL_ROOT/fallback/awm_reloadable.glb"
fetch "$STEEL/assets/models/steel_tide_reloadable_weapons/LICENSE.md" \
  "$REAL_ROOT/fallback/LICENSE.md"
fetch "$STEEL/LICENSE" "$REAL_ROOT/OPERATION-STEEL-TIDE-MIT.txt"

# DJMaesen CC-BY first-person arm derivatives authored around the same socket
# contracts. Static variants provide calibrated ready poses; the animated rig
# supplies platform-specific tactical/empty reload clips with articulated wrist,
# elbow and finger motion for M4A1, P226 and AWM.
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
  animated_reload_arms_Image_2.png \
  LICENSE.md; do
  fetch "$STEEL/assets/models/djmaesen_smg45/$file" "$ARMS_ROOT/$file"
done

# Keep the previous one-shot prepared recordings as compatibility fallback.
for profile in ak74 p226 m4a1 awm; do
  mkdir -p "$AUDIO_ROOT/$profile"
  for role in player_near world enemy_distant; do
    fetch "$STEEL/assets/audio/weapons/$profile/${profile}_${role}.wav" \
      "$AUDIO_ROOT/$profile/${profile}_${role}.wav"
  done
done

# Primary runtime audio: extract four genuinely separate transients from the
# original field-recording takes. Dry report, world/distant report and room tail
# remain separate files. No fixed reflection/reverb is baked into near samples.
python3 "$ROOT_DIR/tools/prepare_multisample_gunshots.py" \
  --cache "$ROOT_DIR/.realistic_audio_sources" \
  --output "$AUDIO_ROOT"

# Recorded mechanical sources. They are split into short events below so the
# runtime can trigger magazine/action sounds at animation beats rather than
# playing one complete reload file at t=0.
fetch "$OGA/reload.wav" "$SFX_ROOT/pistol_reload.wav"
fetch "$OGA/assaultriflereload1.wav" "$SFX_ROOT/rifle_reload.wav"
fetch "$OGA/equipmentclick.wav" "$SFX_ROOT/equipment_click.wav"
fetch "$OGA/Dynamite%20with%20sensor.wav" "$SFX_ROOT/explosion.wav"
python3 "$ROOT_DIR/tools/prepare_reload_events.py" \
  --input "$SFX_ROOT" --output "$SFX_ROOT/reload_events"

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

# CC0 frag/smoke projectile models.
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
PISTOL_PATH="res://assets/third_party/realistic_weapons/fallback/p226_reloadable.glb"
SNIPER_PATH="res://assets/third_party/realistic_weapons/fallback/awm_reloadable.glb"

# Stein files remain preview-only. They never override the validated runtime
# P226/AWM contracts because those contracts expose the required sockets.
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
    echo "Converting Stein 1911 + M700 into preview GLBs ..."
    "$BLENDER" -b --python "$ROOT_DIR/tools/convert_stein_weapon.py" -- \
      "$PISTOL" "$STEIN_RUNTIME/1911.glb" "$STEIN_ROOT" pistol || true
    "$BLENDER" -b --python "$ROOT_DIR/tools/convert_stein_weapon.py" -- \
      "$SNIPER" "$STEIN_RUNTIME/m700.glb" "$STEIN_ROOT" sniper || true
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
  echo "Use your local engine to run: Godot.x86_64 --headless --path '$ROOT_DIR' --import"
fi

echo
echo "Installed socket-aware weapons, authored FPS arms and recorded audio."
echo "Gunshots: four transient variants per profile; dry/tail layers stay separate."
echo "Reload Foley: event clips prepared for animation-synchronised playback."
echo "Run the SOURCE project only; do not use the old Dustline.pck."
