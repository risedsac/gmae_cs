# Dustline 素材来源与许可

此工程是独立制作的离线 FPS demo。未使用 Valve / Counter-Strike 的游戏文件、商标图形或游戏内录音。

## 下载并实际接入的素材

| 素材 | 作者 / 来源 | 许可 | 工程中的用途 |
| --- | --- | --- | --- |
| Beige Wall 001 | Dimitrios Savva、Rico Cilliers · https://polyhaven.com/a/beige_wall_001 | CC0 | 2K 墙面颜色、法线、粗糙度贴图 |
| Sandy Gravel 02 | Dario Barresi · https://polyhaven.com/a/sandy_gravel_02 | CC0 | 2K 沙土地面颜色、法线、粗糙度贴图 |
| Wooden Crate 02 | James Ray Cock、Jurita Burger · https://polyhaven.com/a/wooden_crate_02 | CC0 | glTF 木箱模型及 2K PBR 贴图 |
| Steel Tide Reloadable AK-47 | taradavies 原始 AK-47（OpenGameArt）+ Operation Steel Tide PBR 处理 | 原几何 CC0；新增确定性 PBR 贴图/处理部分按来源仓库 MIT | 第一人称 AK-47 高细节枪体。约 9.7 万源三角面，包含嵌入式 PBR 材质；安装时同时保存来源许可文件和 MIT 许可 |
| Steel Tide M4A1 | nisu 的 M4A1 Assault Rifle + CC0 附件处理 | CC0 1.0 | M4A1 高细节 PBR 枪体，包含 2K base-color / metallic / roughness / normal 素材和可识别机构节点 |
| Stein Games Classic Weapons Pack | Stein Games · https://stein-indie.itch.io/classic-weapons-pack | CC0 1.0 | 可选高细节 P9/1911 与 M700 狙击枪外观。Pack 为高模、2048 px PBR 贴图；通过安装脚本从用户下载的 ZIP 导入 |
| The Free Firearm Sound Library | Ben Jaszczak、Brian Nelson、Kevin Heras、Matthew Nanney · https://opengameart.org/content/the-free-firearm-sound-library | CC0 | 真实枪械现场录音。新版运行时使用独立 player-near / world / enemy-distant 角色，并根据遮挡施加 3D 低通滤波；AK 使用 AK-47，M4 使用 AR-15，P9 使用 Walther PPQ，狙击使用 Tikka 录音 |
| FPS arms (rigged only) | para；原始网格与贴图来自 MakeHuman 团队 · https://opengameart.org/content/fps-arms-rigged-only | CC0 | 第一人称手部网格和手指骨架；当前仍作为高质量枪体的过渡手模，后续可单独替换完整第一人称手臂动画 |
| Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi，qubodup 切片 · https://opengameart.org/content/fantozzis-footsteps-grasssand-stone | CC0 | 六段沙地脚步，重采样为 48 kHz，统一峰值 |
| Gun Reload Sounds | SpringySpringo · https://opengameart.org/content/gun-reload-sounds | CC0 | 步枪与手枪换弹实录，来源为空气软弹枪录音 |

CC0 说明：https://creativecommons.org/publicdomain/zero/1.0/

## 写实武器与枪声音效安装

仓库不直接重复提交大体积第三方模型和 WAV。运行：

```bash
cd dustline-native
bash tools/install-realistic-assets.sh
```

这会自动安装高细节 AK-47、M4A1，以及 AK / 手枪 / M4 / 狙击四组 player-near、world、enemy-distant 枪声。`scripts/weapons.gd` 和 `scripts/audio.gd` 会自动检测新资源；缺失时继续使用旧 Dustline 资源。

为了同时替换手枪与狙击模型，从 Stein Games 页面下载 `Classic Weapons Pack v1.1.zip` 后运行：

```bash
bash tools/install-realistic-assets.sh ~/Downloads/'Classic Weapons Pack v1.1.zip'
```

脚本会完整解压素材包、自动定位 1911 与 M700/R700 的 FBX/GLB，并写入 `assets/third_party/realistic_weapons/manifest.cfg`。Godot 4.3+ 的 ufbx 导入器可直接读取 FBX。

> 开发时必须从源码工程运行，例如 `./engine/Godot.x86_64 --path .`。旧的 `Dustline.pck` 是先前导出的资源包，不会自动包含后来下载的新模型和音频。

## 枪声音频策略

原工程已经使用真实枪械录音，因此这次不是换成夸张的合成“电影枪声”。升级点是运行时空间呈现：

- 玩家自己的枪使用近场录音；
- 场景中的枪使用 world 录音；
- 远距离敌方枪声切换到独立 distant 麦克风录音；
- 墙体遮挡时在 `AudioStreamPlayer3D` 上使用低通滤波并衰减音量；
- 枪声加入极小的随机 pitch 差异，降低连续射击的机械重复感；
- 缺少新音频资源时仍回退到原来的四变体 near/far/occluded 系统。

新版运行时 WAV 的上游仍为 The Free Firearm Sound Library 的 CC0 实枪现场录音。处理脚本和具体裁切来源参考 `AetherRadar/operation-steel-tide/scripts/audio/prepare_free_firearm_sfx.py`。

## 沿用与原创内容

- 原 Dustline 步枪、手枪、M4A1、AWP 模型仍保留，仅作为新资源缺失时的 fallback。
- 第一人称手模当前仍采用 MakeHuman/para 的 CC0 FPS arms，以避免一次修改同时破坏既有换弹逻辑。高质量枪体的完整手指、弹匣、拉栓动画建议作为下一独立阶段处理。
- 战术制服、头盔、装备：此前为此 demo 制作的原创 Blender 网格，沿用 `operator.glb`。
- 人物骨架和 Idle / Walk / Run 动画：改编自 Three.js 官方示例分发的 Mixamo Soldier 动画资产；这部分不标注为 CC0。Godot 中使用 SkeletonModifier3D 求解持枪手臂 IK，保留腿部动作。
  - https://github.com/mrdoob/three.js/blob/dev/examples/models/gltf/Soldier.glb
  - https://threejs.org/examples/webgl_animation_skinning_blending.html
  - https://github.com/mrdoob/three.js/blob/dev/LICENSE
- 地图结构、建筑细节、导航、游戏代码和 HUD：为本项目编写 / 生成。
- Noto Sans CJK：SIL Open Font License；许可证位于 `assets/fonts/LICENSE.txt`。
- Godot 4.7.2：MIT License；随运行包提供 `GODOT-LICENSE.txt`、`GODOT-COPYRIGHT.txt`。

本 demo 的风格与操作参考沙漠战术射击游戏；并非 CS2 地图、动作或成品品质的逐项复制。

## 爆破版新增与限制

- 爆破规则、C4、烟雾、经济、AI 和武器数值没有因为视觉升级而改变。
- 新 AK/M4 枪体优先覆盖旧自制模型；手枪/狙击在安装 Stein 包后覆盖。
- 当前仍复用旧第一人称手模，因此“枪体质量”会先明显提高，完整商业 FPS 级持枪/换弹动画还需要后续专门重做。
- 炸弹、投掷物和提示声音：本项目生成。
- 地图结构参考 Valve 官方 Dust II 展示：https://www.counter-strike.net/dust2/ ，只参考通路和双包点关系，没有下载其地图或游戏素材。
