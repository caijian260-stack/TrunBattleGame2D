class_name PlayerAppearanceSwitcher
extends PanelContainer

## 战斗场景中的玩家外观测试面板。
##
## 下拉列表列出 CharacterRegistry 登记的角色与“默认外观”。选中后本面板只
## 发出 appearance_selected，由战斗场景负责替换玩家视觉；所选角色的待机动画
## 由 BattleCharacter2D 自动载入并播放（idle_01 转入 → idle_02 循环），
## 因此替换外观后无需额外操作。本面板只服务表现与调试，不参与战斗规则。

const CharacterRegistryScript := preload(
	"res://scripts/core/character_registry.gd"
)

## 玩家选择外观时发出，携带 CharacterRegistry 的角色 id；-1 表示默认外观。
signal appearance_selected(character_id: int)

## 玩家修改显示尺寸时发出，携带玩家外观的显示高度（像素）。
signal appearance_size_selected(height_px: float)

## 默认外观沿用 PlayerBattleCharacter2D 的程序化绘制。
const DEFAULT_CHARACTER_ID := -1
const DEFAULT_OPTION_LABEL := "默认外观"
## 缺少待机动画素材的角色在下拉列表中显示为不可选。
const MISSING_SUFFIX := "（无待机素材）"
## 尺寸输入的取值范围与初始值（像素，指显示高度）。
const SIZE_MIN := 40.0
const SIZE_MAX := 1200.0
const SIZE_STEP := 2.0
const SIZE_FALLBACK := 150.0
## 两行标签同宽，保证输入控件左对齐。
const CAPTION_WIDTH := 62.0

var _option: OptionButton
var _size_input: SpinBox
var _size_label: Label
var _status: Label
var _entries: Array[Dictionary] = []


func _ready() -> void:
	_build()
	_collect_entries()
	_populate()
	_sync_status(DEFAULT_CHARACTER_ID)


## 返回下拉列表当前选中的外观 id。
func get_selected_appearance_id() -> int:
	var index := _option.selected
	if index < 0 or index >= _entries.size():
		return DEFAULT_CHARACTER_ID
	return int(_entries[index]["id"])


## 由外部同步下拉列表选项，不触发 appearance_selected。
func select_appearance(character_id: int) -> bool:
	for index in _entries.size():
		if int(_entries[index]["id"]) != character_id:
			continue
		_option.select(index)
		_sync_status(character_id)
		return true
	return false


## 由战斗场景推送当前外观尺寸：源素材尺寸与实际显示尺寸。
##
## 显示高度会在用户正在输入时保持不变，避免每帧覆盖输入框内容。
func set_visual_size(source_size: Vector2, display_size: Vector2) -> void:
	var ready := source_size.x > 0.0 and source_size.y > 0.0
	if _size_label != null:
		if ready:
			_size_label.text = "源 %d × %d → %d × %d" % [
				roundi(source_size.x),
				roundi(source_size.y),
				roundi(display_size.x),
				roundi(display_size.y),
			]
		else:
			_size_label.text = "外观尺寸未就绪"
	if _size_input == null:
		return
	if _size_input.get_line_edit().has_focus():
		return
	var height := display_size.y if ready else SIZE_FALLBACK
	_size_input.set_value_no_signal(
		clampf(roundf(height), SIZE_MIN, SIZE_MAX)
	)


## 供测试与调试读取下拉列表控件。
func get_option_button() -> OptionButton:
	return _option


## 返回指定外观 id 在下拉列表中的位置，未登记时返回 -1。
func find_option_index(character_id: int) -> int:
	for index in _entries.size():
		if int(_entries[index]["id"]) == character_id:
			return index
	return -1


## 返回下拉列表指定位置对应的外观 id。
func get_option_character_id(index: int) -> int:
	if index < 0 or index >= _entries.size():
		return DEFAULT_CHARACTER_ID
	return int(_entries[index]["id"])


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	row.add_child(_make_caption("玩家外观"))

	_option = OptionButton.new()
	_option.name = "AppearanceOption"
	_option.custom_minimum_size = Vector2(232.0, 32.0)
	_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option.item_selected.connect(_on_item_selected)
	row.add_child(_option)

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	column.add_child(size_row)

	size_row.add_child(_make_caption("尺寸"))

	_size_input = SpinBox.new()
	_size_input.name = "AppearanceSizeInput"
	_size_input.min_value = SIZE_MIN
	_size_input.max_value = SIZE_MAX
	_size_input.step = SIZE_STEP
	_size_input.suffix = " px"
	_size_input.value = SIZE_FALLBACK
	_size_input.custom_minimum_size = Vector2(104.0, 32.0)
	_size_input.tooltip_text = "玩家外观的显示高度（像素）"
	_size_input.value_changed.connect(_on_size_selected)
	size_row.add_child(_size_input)

	_size_label = Label.new()
	_size_label.name = "AppearanceSizeLabel"
	_size_label.clip_text = true
	_size_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size_label.add_theme_font_size_override("font_size", 12)
	_size_label.add_theme_color_override("font_color", Color(0.62, 0.76, 0.84))
	_size_label.text = "外观尺寸未就绪"
	size_row.add_child(_size_label)

	_status = Label.new()
	_status.name = "AppearanceStatus"
	# 单行省略：自动换行会在宽度未确定时把最小高度算成多行，撑高面板。
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size = Vector2(0.0, 16.0)
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.62, 0.76, 0.84))
	column.add_child(_status)


func _make_caption(text_value: String) -> Label:
	var caption := Label.new()
	caption.text = text_value
	caption.custom_minimum_size = Vector2(CAPTION_WIDTH, 0.0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0))
	return caption


## 第一项固定为默认外观，其余按 CharacterRegistry 顺序排列。
func _collect_entries() -> void:
	_entries.clear()
	_entries.append(
		{
			"id": DEFAULT_CHARACTER_ID,
			"label": DEFAULT_OPTION_LABEL,
			"available": true,
		}
	)
	for entry in CharacterRegistryScript.CHARACTERS:
		var character_id: int = entry["id"]
		var available: bool = CharacterRegistryScript.asset_exists(
			character_id,
			CharacterRegistryScript.IDLE_ANIMATION_FILE
		)
		var label: String = entry["label"]
		if not available:
			label += MISSING_SUFFIX
		_entries.append(
			{
				"id": character_id,
				"label": label,
				"available": available,
			}
		)


func _populate() -> void:
	_option.clear()
	for index in _entries.size():
		_option.add_item(_entries[index]["label"], index)
		_option.set_item_disabled(index, not _entries[index]["available"])
	_option.select(0)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var character_id := int(_entries[index]["id"])
	_sync_status(character_id)
	appearance_selected.emit(character_id)


func _on_size_selected(height_px: float) -> void:
	appearance_size_selected.emit(height_px)


## 状态行展示所选角色已就绪的待机剪片，方便确认动画是否自动加载。
func _sync_status(character_id: int) -> void:
	if _status == null:
		return
	if character_id == DEFAULT_CHARACTER_ID:
		_status.text = "程序化默认外观"
		return
	_status.text = _idle_summary(character_id)


## 紧凑展示待机剪片，避免文本撑宽面板。
func _idle_summary(character_id: int) -> String:
	var path := CharacterRegistryScript.get_idle_animation_path(character_id)
	if not FileAccess.file_exists(path):
		return "待机动画缺失"
	var frames := load(path) as SpriteFrames
	if frames == null:
		return "待机动画无法加载"
	var names := frames.get_animation_names()
	if names.is_empty():
		return "待机动画为空"
	return "待机 %s · %.1f fps" % [
		" → ".join(names),
		frames.get_animation_speed(names[0]),
	]


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.055, 0.08, 0.9)
	style.border_color = Color(0.24, 0.75, 0.98, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 6
	return style
