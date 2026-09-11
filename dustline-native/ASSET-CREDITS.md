# Dustline 素材来源与许可

此工程是独立制作的离线 FPS demo。未使用 Valve / Counter-Strike 的游戏文件、商标图形或游戏内录音。

## 下载并实际接入的素材

| 素材 | 作者 / 来源 | 许可 | 工程中的用途 |
| --- | --- | --- | --- |
| Beige Wall 001 | Dimitrios Savva、Rico Cilliers · https://polyhaven.com/a/beige_wall_001 | CC0 | 2K 墙面颜色、法线、粗糙度贴图 |
| Sandy Gravel 02 | Dario Barresi · https://polyhaven.com/a/sandy_gravel_02 | CC0 | 2K 沙土地面颜色、法线、粗糙度贴图 |
| Wooden Crate 02 | James Ray Cock、Jurita Burger · https://polyhaven.com/a/wooden_crate_02 | CC0 | glTF 木箱模型及 2K PBR 贴图 |
| Steel Tide Reloadable AK-47 | taradavies 原始 AK-47（OpenGameArt）+ Operation Steel Tide PBR 处理 | 原几何 CC0；新增确定性 PBR 贴图/处理部分按来源仓库 MIT | 世界模型 / fallback AK-47 高细节枪体。约 9.7 万源三角面，包含嵌入式 PBR 材质 |
| FPS AK-74m animations | Cransh · https://sketchfab.com/3d-models/fps-ak-74m-animations-94be8385c402474cacd39bc096c6ca14 | CC-BY-4.0 | 玩家 AK 第一人称整套 rig：双臂、AK-74M、Draw / Idle / Walk / Run / Shot / Reload 骨骼动画。通过 `install-fps-arms.sh` 安装 |
| Steel Tide M4A1 | nisu 的 M4A1 Assault Rifle + CC0 附件处理 | CC0 1.0 | M4A1 高细节 PBR 枪体，包含 2K base-color / metallic / roughness / normal 素材和可识别机构节点 |
| Stein Games Classic Weapons Pack | Stein Games · https://stein-indie.itch.io/classic-weapons-pack | CC0 1.0 | 可选高细节 P9/1911 与 M700 狙击枪外观。Pack 为高模、2048 px PBR 贴图；通过安装脚本从用户下载的 ZIP 导入 |
| The Free Firearm Sound Library | Ben Jaszczak、Brian Nelson、Kevin Heras、Matthew Nanney · https://opengameart.org/content/the-free-firearm-sound-library | CC0 | 真实枪械现场录音。新版运行时使用独立 player-near / world / enemy-distant 角色，并根据遮挡施加 3D 低通滤波；AK 使用 AK-47，M4 使用 AR-15，P9 使用 Walther PPQ，狙击使用 Tikka 录音 |
| FPS arms (rigged only) | para；原始网格与贴图来自 MakeHuman 团队 · https://opengameart.org/content/fps-arms-rigged-only | CC0 | P9/M4/AWP 以及 AK 新素材缺失时的第一人称 fallback 手臂；不再作为安装了 authored AK rig 后的 AK 主手模 |
| Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi，qubodup 切片 · https://opengameart.org/content/fantozzis-footsteps-grasssand-stone | CC0 | 六段沙地脚步，重采样为 48 kHz，统一峰值 |
| Gun Reload Sounds | SpringySpringo · https://opengameart.org/content/gun-reload-sounds | CC0 | 步枪与手枪换弹实录，来源为空气软弹枪录音 |

CC0 说明：https://creativecommons.org/publicdomain/zero/1.0/

### Cransh AK 第一人称模型的强制署名

`FPS AK-74m animations` **不是 MIT / CC0**。素材自身的 `license.txt` 指定为 CC-BY-4.0，并要求保留作者署名。安装脚本会同时保存原始 license 和 `ATTRIBUTION.txt`。

必须保留以下署名：

> This work is based on "FPS AK-74m animations" (https://sketchfab.com/3d-models/fps-ak-74m-animations-94be8385c402474cacd39bc096c6ca14) by Cransh (https://sketchfab.com/ccransh) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## 写实武器、第一人称手臂与枪声音效安装

仓库不直接重复提交大体积第三方模型、PBR 贴图和 WAV。运行：

```bash
cd dustline-native
bash tools/install-realistic-assets.sh
bash tools/install-fps-arms.sh
```

第一条会自动安装高细节 AK/M4/P226/AWM fallback/世界枪体、投掷物，以及 AK / 手枪 / M4 / 狙击四组 player-near、world、enemy-distant 枪声。第二条会安装 Cransh 的 AK-74M 第一人称整套骨骼与动画资源。`scripts/weapons.gd` 会优先给玩家 AK 使用 authored viewmodel；资源缺失时自动回退，不影响游戏启动。

为了同时替换手枪与狙击模型，从 Stein Games 页面下载 `Classic Weapons Pack v1.1.zip` 后运行：

```bash
bash tools/install-realistic-assets.sh ~/Downloads/'Classic Weapons Pack v1.1.zip'
```

脚本会完整解压素材包、自动定位 1911 与 M700/R700 的 FBX/GLB，并写入 `assets/third_party/realistic_weapons/manifest.cfg`。

> 开发时必须从源码工程运行，例如 `./engine/Godot.x86_64 --path .`。旧的 `Dustline.pck` 是先前导出的资源包，不会自动包含后来下载的新模型、手臂和音频。

## 第一人称动画策略

安装 `install-fps-arms.sh` 后，AK 不再用代码移动“SupportArm / Magazine / Bolt”去模拟动作，而是由原始骨骼动画直接驱动：拔枪使用 `Rig|AK_Draw`，待机使用 `Rig|AK_Idle`，移动使用 `Rig|AK_Walk` / `Rig|AK_Run`，射击使用 `Rig|AK_Shot`，换弹使用 `Rig|AK_Reload_full`。

P9、M4A1、AWP 当前仍沿用兼容性更高的旧 viewmodel 与程序化动作，后续可以在找到许可证清楚、带完整动画的对应第一人称资产后逐把替换。这样不会为了“一次全换”把已经可玩的武器系统一起破坏。

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
- 安装 authored AK rig 后，AK 的第一人称双臂、枪体和主要动作来自 Cransh 的 CC-BY-4.0 素材；旧 MakeHuman/para 手模只作为 fallback 和其他枪的过渡方案。
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
- 玩家 AK 在 authored rig 安装后获得真实骨骼持枪、拔枪、移动、射击、换弹动画；BOT 仍使用第三人称世界枪械，不会显示第一人称双臂。
- M4/P9/AWP 的完整商业 FPS 级第一人称动画仍是后续工作；当前保留稳定 fallback。
- 炸弹、投掷物和提示声音：本项目生成。
- 地图结构参考 Valve 官方 Dust II 展示：https://www.counter-strike.net/dust2/ ，只参考通路和双包点关系，没有下载其地图或游戏素材。
