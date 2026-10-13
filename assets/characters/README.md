# 角色素材目录约定

每个角色使用一个独立子目录，目录名即角色 id，例如 `assets/characters/lxq`。

```text
assets/characters/<角色名>/
├── portrait.png   # 立绘
├── left.png       # 左视图
├── right.png      # 右视图
├── front.png      # 正视图
├── back.png       # 后视图（可选）
└── animation/
    ├── idle/      # 待机动画精灵图
    └── walk/      # 行走动画精灵图
```

替换角色外观时，用同名文件覆盖即可。若素材是视频或带背景的图片，需要先
导出成透明背景精灵图或 SpriteFrames 资源，再放入对应动画目录。

行走动画目前以 `sprites.png`（精灵图集）加同目录 `animation.tres`
（SpriteFrames）存放。`animation.tres` 中按相对路径引用 `sprites.png`，
因此两个文件必须保持在同一个子目录内。

待机动画使用同一套 `sprites.png` + `animation.tres` 约定。lxq 当前提供
`idle_01`（站立转入，45 帧不循环）与 `idle_02`（截取 01 最后 0.5 秒，
按 x → 末帧 → 回到 x 对称往返循环；时长可在查看器中调节）。

具体角色视觉子类放在 `scripts/ui/`，继承 `BattleCharacter2D`。新增角色后
可在角色查看器脚本中预载对应子类，或按同一套素材约定复用父类。
