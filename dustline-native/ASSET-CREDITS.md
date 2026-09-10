# Dustline 素材来源与许可

此工程是独立制作的离线 FPS demo。未使用 Valve / Counter-Strike 的游戏文件、商标图形或游戏内录音。

## 下载并实际接入的素材

| 素材 | 作者 / 来源 | 许可 | 工程中的用途 |
| --- | --- | --- | --- |
| Beige Wall 001 | Dimitrios Savva、Rico Cilliers · https://polyhaven.com/a/beige_wall_001 | CC0 | 2K 墙面颜色、法线、粗糙度贴图 |
| Sandy Gravel 02 | Dario Barresi · https://polyhaven.com/a/sandy_gravel_02 | CC0 | 2K 沙土地面颜色、法线、粗糙度贴图 |
| Wooden Crate 02 | James Ray Cock、Jurita Burger · https://polyhaven.com/a/wooden_crate_02 | CC0 | glTF 木箱模型及 2K PBR 贴图 |
| The Free Firearm Sound Library | Ben Jaszczak、Brian Nelson、Kevin Heras、Matthew Nanney · https://opengameart.org/node/21826 | CC0 | AK-47 / C_28P.wav、C_31P.wav；1911 / A_42P.wav、A_34P.wav；AR-15 / D_32P.wav、D_24P.wav；Tikka / W_29P.wav、W_24P.wav。从各麦克风分离截取单发，保留起音和尾音，制作近处、远处、遮挡变体。AR-15 用作 M4 音色，Tikka 用作狙击枪音色。 |
| FPS arms (rigged only) | para；原始网格与贴图来自 MakeHuman 团队 · https://opengameart.org/content/fps-arms-rigged-only | CC0 | 第一人称手部网格和手指骨架；截取手部、重新摆握姿、调整指节、制作手套材质和袖口。原始骨架随源码提供。 |
| Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi，qubodup 切片 · https://opengameart.org/content/fantozzis-footsteps-grasssand-stone | CC0 | 六段沙地脚步，重采样为 48 kHz，统一峰值。 |
| Gun Reload Sounds | SpringySpringo · https://opengameart.org/content/gun-reload-sounds | CC0 | 步枪与手枪换弹实录，来源为空气软弹枪录音 |

CC0 说明：https://creativecommons.org/publicdomain/zero/1.0/
Poly Haven 下载元数据和文件摘要保存在 `asset-downloads.json`。素材服务原始元数据保存在本次工作区的 `work/downloads/`。

## 沿用与原创内容

- 步枪、手枪、袖口：此前为此 demo 制作的原创 Blender 模型。v3 手部网格采用上表 CC0 素材，重新制作握姿和材质。
- 战术制服、头盔、装备：此前为此 demo 制作的原创 Blender 网格，沿用 `operator.glb`。
- 人物骨架和 Idle / Walk / Run 动画：改编自 Three.js 官方示例分发的 Mixamo Soldier 动画资产；这部分不标注为 CC0。Godot 中使用 SkeletonModifier3D 求解持枪手臂 IK，保留腿部动作；v3 调整衣物关节权重。
  - https://github.com/mrdoob/three.js/blob/dev/examples/models/gltf/Soldier.glb
  - https://threejs.org/examples/webgl_animation_skinning_blending.html
  - https://github.com/mrdoob/three.js/blob/dev/LICENSE
- 地图结构、建筑细节、导航、游戏代码和 HUD：为本项目编写 / 生成。
- Noto Sans CJK：SIL Open Font License；许可证位于 `assets/fonts/LICENSE.txt`。
- Godot 4.7.2：MIT License；随运行包提供 `GODOT-LICENSE.txt`、`GODOT-COPYRIGHT.txt`。

本 demo 的风格与操作参考沙漠战术射击游戏；并非 CS2 地图、动作或成品品质的逐项复制。

## 爆破版新增

- M4A1、AWP：原创几何建模，经 Blender 5.2 处理倒角、加权法线并合并网格。源码内附 `.blend` 与实际使用的 GLB。
- 炸弹、投掷物和提示声音：本项目生成。
- 地图结构参考 Valve 官方 Dust II 展示：https://www.counter-strike.net/dust2/ 。只参考通路和双包点关系，没有下载其地图或游戏素材。
