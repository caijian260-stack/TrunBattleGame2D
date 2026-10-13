# 界面字体

本目录存放游戏界面使用的古风字体。

## 当前字体

- 文件：`LXGWWenKai-Regular.ttf`（霞鹜文楷 Regular，v1.522）
- 来源：<https://github.com/lxgw/LxgwWenKai>
- 许可：SIL Open Font License 1.1，完整条款见同目录 `OFL.txt`

霞鹜文楷是基于 FONTWORKS 的 Klee One 改造的开源楷体，笔画带毛笔起收，
适合本项目的中式仙侠界面。字体在 `project.godot` 中通过
`gui/theme/custom_font` 设为全局默认字体，所有 Label、Button 与 RichTextLabel
默认使用它。

## 替换方式

把新的 `.ttf`/`.otf` 放进本目录，然后修改 `project.godot`：

```ini
[gui]

theme/custom_font="res://assets/fonts/<新字体文件名>"
```

其他字体若要随仓库分发，请一并放入对应的许可证文件。

## 显示设置

界面固定按 1600x900 设计分辨率排版，再由 `project.godot` 的
`display/window/stretch/mode="canvas_items"` 缩放到实际窗口。该模式会让字体
按最终窗口尺寸重新栅格化，因此 1152x648 等小窗口下文字依然清晰；若改回
手动 `scale` 缩放 Control，字体会先按原字号渲染再被拉伸，从而发虚。
