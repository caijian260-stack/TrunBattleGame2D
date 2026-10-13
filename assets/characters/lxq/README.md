# lxq 角色素材

本目录是 lxq 的标准角色素材位置，查看器与战斗视觉子类
`LxqBattleCharacter2D` 都从这里读取图片。

## 当前来源

- `portrait.png`：来自 `素材/lxq/lxq_h.png`，作为立绘。
- `left.png`：来自 `素材/lxq/lxq_l.png`，左视图。
- `right.png`：目前由 `left.png` 水平镜像生成，作为右视图占位；
  提供真正的右视图后直接覆盖同名文件即可。
- `front.png`：来自 `素材/lxq/lxq_f.png`，正视图。
- `back.png`：来自 `素材/lxq/lxq_b.png`，后视图。

## 动画

- `animation/walk/full/`：39 帧行走循环，24 fps。
- `animation/walk/light/`：16 帧精简行走循环，约 9.85 fps。
- `animation/idle/`：待机动画精灵图，12 fps，包含 `idle_01`（45 帧站立
  转入动画，不循环）与 `idle_02`（复用 `idle_01` 最后 6 帧的持续循环）；
  来自 `素材/lxq/Idle/animation_original01.mp4` 抠像后的精灵图集。
