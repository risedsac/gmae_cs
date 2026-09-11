# Dustline 素材来源与许可

此工程是独立制作的离线 FPS demo。未使用 Valve / Counter-Strike 的游戏文件、商标图形或游戏内录音。

## 下载并实际接入的素材

| 素材 | 作者 / 来源 | 许可 | 工程中的用途 |
| --- | --- | --- | --- |
| Beige Wall 001 | Dimitrios Savva、Rico Cilliers · https://polyhaven.com/a/beige_wall_001 | CC0 | 2K 墙面颜色、法线、粗糙度贴图 |
| Sandy Gravel 02 | Dario Barresi · https://polyhaven.com/a/sandy_gravel_02 | CC0 | 2K 沙土地面颜色、法线、粗糙度贴图 |
| Wooden Crate 02 | James Ray Cock、Jurita Burger · https://polyhaven.com/a/wooden_crate_02 | CC0 | glTF 木箱模型及 2K PBR 贴图 |
| Steel Tide Reloadable AK-47 | taradavies 原始 AK-47（OpenGameArt）+ Operation Steel Tide PBR 处理 | 原几何 CC0；新增确定性 PBR 贴图/处理部分按来源仓库 MIT | 世界模型 / fallback AK-47 高细节枪体 |
| FPS AK-74m animations | Cransh · https://sketchfab.com/3d-models/fps-ak-74m-animations-94be8385c402474cacd39bc096c6ca14 | CC-BY-4.0 | 玩家 AK 第一人称整套 rig：双臂、AK-74M、Draw / Idle / Walk / Run / Shot / Reload 骨骼动画。通过 `install-fps-arms.sh` 安装 |
| Steel Tide M4A1 | nisu 的 M4A1 Assault Rifle + CC0 附件处理 | CC0 1.0 | M4A1 PBR 枪体及 `PrimaryGrip`、`ForegripContact`、`MagazineGripSocket`、`ChargingHandle` 等明确运行时连接点 |
| Steel Tide reloadable P226 / AWM | Quaternius Ultimate Guns Pack 派生的 reloadable exports，来源与构建记录保存在随模型下载的 `LICENSE.md` | CC0 / 派生记录见随附许可 | P9 与 AWP 运行时枪体。包含真实 `Magazine`、`SpareMagazine`、`ChargingHandle` 及握把、弹匣、机构 socket |
| fps animated smg - arm derivatives | DJMaesen · https://sketchfab.com/3d-models/fps-animated-smg-ea3dad7478624495a5a46f40127b0579 | CC-BY-4.0 | P226/M4/AWM 的静态校准持枪手臂与 `animated_reload_arms.glb`。后者保留骨骼、手指权重、腕/肘运动，并提供平台专用 tactical / empty reload clips |
| The Free Firearm Sound Library | Ben Jaszczak、Brian Nelson、Kevin Heras、Matthew Nanney · https://opengameart.org/content/the-free-firearm-sound-library | CC0 | 实枪现场录音。运行时从原始多枪录音中提取四个独立单发瞬态；近场、世界声、远场和环境尾音保持为独立层 |
| Gun Reload Sounds | SpringySpringo · https://opengameart.org/content/gun-reload-sounds | CC0 | 手枪、步枪完整换弹实录。安装时拆成 `mag_out`、`mag_in`、`action` 事件，用于动画时间点同步，不再从换弹起点播放整段录音 |
| FPS arms (rigged only) | para；原始网格与贴图来自 MakeHuman 团队 · https://opengameart.org/content/fps-arms-rigged-only | CC0 | 仅作为新第一人称资源缺失时的 legacy fallback，不再是 P226/M4/AWM 正常路径 |
| Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi，qubodup 切片 · https://opengameart.org/content/fantozzis-footsteps-grasssand-stone | CC0 | 六段沙地脚步 |

CC0 说明：https://creativecommons.org/publicdomain/zero/1.0/

## CC-BY 强制署名

### Cransh AK 第一人称模型

`FPS AK-74m animations` **不是 MIT / CC0**。必须保留：

> This work is based on "FPS AK-74m animations" (https://sketchfab.com/3d-models/fps-ak-74m-animations-94be8385c402474cacd39bc096c6ca14) by Cransh (https://sketchfab.com/ccransh) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

`install-fps-arms.sh` 会同时保存原始 license 与 `ATTRIBUTION.txt`。

### DJMaesen 第一人称手臂

P226/M4/AWM 使用的静态/换弹手臂是 `fps animated smg` 的派生资源。必须保留：

> "fps animated smg" by DJMaesen, licensed under CC BY 4.0.

来源：https://sketchfab.com/3d-models/fps-animated-smg-ea3dad7478624495a5a46f40127b0579

安装脚本会把上游 `assets/models/djmaesen_smg45/LICENSE.md` 一并保存到 `assets/third_party/djmaesen_arms/LICENSE.md`。

## 写实武器、手臂与音频安装

仓库不直接重复提交大体积第三方模型、PBR 贴图和 WAV。运行：

```bash
cd dustline-native
bash tools/install-realistic-assets.sh
bash tools/install-fps-arms.sh
```

`install-realistic-assets.sh` 会安装：

- M4A1、P226、AWM 等带明确 socket / mechanism contract 的运行时枪体；
- DJMaesen CC-BY 静态持枪手臂和平台专用骨骼换弹手臂；
- 手雷 / 烟雾弹模型；
- 四把武器各 4 个真实枪声瞬态，并将 dry/world/distant/tail 分离；
- 被拆成机构事件的 recorded reload Foley。

`install-fps-arms.sh` 单独安装 Cransh 的 AK-74M 完整第一人称骨骼资源。

Stein Games Classic Weapons Pack 仍可由安装脚本转换用于模型检查，但目前 **不会覆盖** P226/AWM 的正式运行时模型，因为运行时绑定依赖明确的握把、弹匣和拉机柄 socket。

> 开发时必须从源码工程运行。旧 `Dustline.pck` 不会自动包含后来下载的新模型、手臂和音频。

## 第一人称 rig / 机构策略

- AK：使用 Cransh 配套的枪 + 双臂骨骼资源，已有 Draw / Idle / Walk / Run / Shot / Reload。
- P226/M4/AWM：枪体与手臂不再靠 AABB 长度/中心匹配。`weapons.gd` 只接受明确命名的 grip/support/magazine/action socket。
- M4：右手对 `PrimaryGrip`，左手支撑对 `ForegripContact`；换弹使用真实 `Magazine` / `MagazineGripSocket`，机构动作使用真实 `ChargingHandle`。
- P226/AWM：使用 reloadable weapon contract 的 `PrimaryGripSocket`、`SupportGripSocket`、`MagazineGripSocket`、`ChargingHandleSocket` 等节点。
- 非 AK 换弹：静态支撑臂在换弹阶段隐藏，`animated_reload_arms.glb` 的平台专用骨骼 clip 接管左臂；弹匣在“枪上 → 左手 → 新弹匣 → 枪上”四阶段切换所有权，真实机构节点按动作进度运动。
- 不再创建空 `Bolt` 或空 `Magazine` 节点来掩盖绑定失败；关键 contract 缺失会直接输出 `[DUSTLINE RIG]` 错误。

### 当前仍需实机 / DCC 验收的部分

P226/M4/AWM 的 reload 已切到平台专用骨骼动画，但它们的待机、移动、开火、拔枪目前仍主要使用保持双手接触关系的 viewmodel 根运动，并非每把枪都已有一套完整商业 FPS 级专用骨骼动作。必须按验收录像继续检查手指接触、袖口、穿模和动作风格，不能把“资源加载成功”视为完成。

## 枪声音频策略

`tools/prepare_multisample_gunshots.py` 从 The Free Firearm Sound Library 的原始 multi-shot field recordings 中检测不同瞬态，为每个平台准备：

- `near_0..3.wav`：近场 dry report；
- `world_0..3.wav`：场景中距离报告；
- `distant_0..3.wav`：独立远场麦克风报告；
- `tail_0..3.wav`：独立环境尾音层。

运行时同一角色不会立即重复刚播放的变体。近场 dry、很低电平的机械层、环境 tail 分开播放和调节；墙体遮挡只在运行时对 3D 声音做滤波/衰减。安装流程不再调用 `build_field_gunshot_mix.py` 将固定延迟反射写死进 player-near WAV。

`tools/render_gunshot_review.py` 用统一 RMS 目标导出单发和连发 A/B 文件，供人工试听 dry / layered / legacy。它只生成 review 文件，不会修改 runtime WAV。最终素材选择仍必须通过同响度人工监听完成。

## 换弹 Foley 策略

`tools/prepare_reload_events.py` 将完整 recorded reload take 拆成短事件，运行时按每把枪的 reload 进度触发 `mag_out`、`mag_in`、`action`。切枪、死亡或取消换弹会清空未触发事件并停止正在播放的 reload event player。不同平台拥有独立事件文件名，之后可以替换为更准确的 M4/P226/AWM/AK 机械录音而不改游戏逻辑。

## 沿用与原创内容

- 原 Dustline 武器仍作为资源缺失时的 fallback。
- 战术制服、头盔、装备：此前为此 demo 制作的原创 Blender 网格，沿用 `operator.glb`。
- 人物骨架和 Idle / Walk / Run 动画：改编自 Three.js 官方示例分发的 Mixamo Soldier 动画资产；这部分不标注为 CC0。
  - https://github.com/mrdoob/three.js/blob/dev/examples/models/gltf/Soldier.glb
  - https://threejs.org/examples/webgl_animation_skinning_blending.html
  - https://github.com/mrdoob/three.js/blob/dev/LICENSE
- 地图结构、建筑细节、导航、游戏代码和 HUD：为本项目编写 / 生成。
- Noto Sans CJK：SIL Open Font License；许可证位于 `assets/fonts/LICENSE.txt`。
- Godot 4.7.2：MIT License；随运行包提供 `GODOT-LICENSE.txt`、`GODOT-COPYRIGHT.txt`。

本 demo 的风格与操作参考沙漠战术射击游戏；并非 CS2 地图、动作或成品品质的逐项复制。
