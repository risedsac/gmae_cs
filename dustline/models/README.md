# DUSTLINE models

The rifle, sidearm, hands, tactical uniform and gear are original meshes built in Blender 5.2.1. `operator.glb` retains the attributed Mixamo animation rig and four clips from the original `soldier.glb`; see `public/assets/CREDITS.txt`.

Run from the project root:

```sh
blender -b --python models/build_assets.py
blender -b --python models/build_operator.py
```

The scripts export the runtime GLB files into `public/assets/`. Editable `.blend` files and studio renders go under `work/model-artifacts/outputs/` and `work/model-artifacts/work/`. Set `DUSTLINE_ARTIFACT_DIR` to choose a different parent directory. Neither command opens Blender's interface or a browser.

Weapon nodes `Magazine`, `SupportArm` and `Bolt` are retained as independent animation pivots. Texture images use sRGB encoding; meshes use a Y-up, forward-negative-Z convention after GLB export. The game normalizes the character only after evaluating its skin and animation pose, and applies the shooting pose after the walking animation.
