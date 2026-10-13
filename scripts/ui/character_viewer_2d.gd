class_name CharacterViewer2D
extends Control

## 角色素材查看器：从角色下拉列表选择角色，按角色目录约定读取角色文档
## README.md、立绘/视图、真实待机动画与 SpriteFrames 行走动画。
## 角色目录缺失时，界面显示“不存在”并禁用对应预览。

const VIEW_IDLE := 0
const VIEW_WALK := 1

const IDLE_SOURCE_DEFS := [
	{"label": "待机01 · 站立转入", "animation": &"idle_01"},
	{"label": "待机02 · 持续循环", "animation": &"idle_02"},
]
const IDLE_SOURCE_LOOP := 1
const IDLE_LOOP_SECONDS_MIN := 0.1
const IDLE_LOOP_SECONDS_MAX := 2.0
const IDLE_LOOP_SECONDS_STEP := 0.05
const IDLE_LOOP_SECONDS_DEFAULT := 0.5
const WALK_SCALE_MIN := 0.2
const WALK_SCALE_MAX := 0.85

const CharacterRegistryScript := preload(
	"res://scripts/core/character_registry.gd"
)
const BattleUnitScript := preload("res://scripts/core/battle_unit.gd")
const BattleCharacter2DScript := preload(
	"res://scripts/ui/battle_character_2d.gd"
)
const LxqBattleCharacter2DScript := preload(
	"res://scripts/ui/lxq_battle_character_2d.gd"
)
const AssetBattleCharacter2DScript := preload(
	"res://scripts/ui/asset_battle_character_2d.gd"
)
const ACCENT := Color(0.28, 0.74, 0.9)

var portrait_view: TextureRect
var idle_stage: IdleStage
var animation_sprite: AnimatedSprite2D
var animation_info: Label

var _character_option: OptionButton
var _character_status: Label
var _portrait_caption: Label
var _character_doc_label: Label
var _portrait_button_row: HBoxContainer
var _stage_control: Control
var _idle_controls: Control
var _walk_controls: VBoxContainer
var _play_button: Button
var _flip_button: Button
var _source_option: OptionButton
var _idle_source_option: OptionButton
var _idle_seconds_slider: HSlider
var _idle_seconds_label: Label
var _idle_note: Label
var _save_idle_button: Button
var _speed_slider: HSlider
var _speed_label: Label
var _view_buttons: Array[Button] = []

var _current_character_id := CharacterRegistryScript.CharacterId.LXQ
var _current_view := VIEW_IDLE
var _portraits: Array[Dictionary] = []
var _walk_sources: Array[Dictionary] = []
var _portrait_index := 0
var _idle_source_index := IDLE_SOURCE_LOOP
var _idle_loop_seconds := IDLE_LOOP_SECONDS_DEFAULT
var _walk_source_index := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	select_character(CharacterRegistryScript.CharacterId.LXQ)


func _process(_delta: float) -> void:
	if _current_view == VIEW_WALK:
		_update_animation_info()


## 切换当前查看的角色。角色名来自 CharacterRegistry 枚举/列表，所有素材
## 按 assets/characters/<id>/ 现有布局动态读取，缺失项显示“不存在”。
func select_character(character_id: int) -> bool:
	if not CharacterRegistryScript.has_character(character_id):
		return false
	_current_character_id = character_id
	_sync_character_option()

	var document := CharacterRegistryScript.load_character_document(
		character_id
	)
	if document != "":
		_character_doc_label.text = document
	else:
		_character_doc_label.text = "角色文档不存在（README.md）"

	_build_portrait_list(character_id)
	_prepare_idle_stage(character_id)
	_load_walk_sources(character_id)

	var missing := _collect_missing_assets(character_id, document)
	if missing.is_empty():
		_character_status.text = "资源已加载 · README/立绘/待机/行走"
		_character_status.add_theme_color_override(
			"font_color",
			Color(0.62, 0.84, 0.68)
		)
	else:
		_character_status.text = "资源不存在: %s" % "、".join(missing)
		_character_status.add_theme_color_override(
			"font_color",
			Color(0.96, 0.52, 0.46)
		)

	if _portraits.is_empty():
		portrait_view.texture = null
		_portrait_caption.text = "立绘不存在"
	else:
		select_portrait(0)

	if _walk_sources.is_empty():
		animation_sprite.sprite_frames = null
		animation_sprite.stop()
		_play_button.text = "播放"
	else:
		_walk_source_index = 0
		animation_sprite.sprite_frames = _walk_sources[0]["frames"]
		animation_sprite.animation = &"walk_left"
		if _current_view == VIEW_WALK:
			animation_sprite.play()
			_play_button.text = "暂停"

	_apply_walk_controls_state()
	select_view(_current_view)
	_update_idle_loop_label()
	return true


func select_portrait(index: int) -> bool:
	if index < 0 or index >= _portraits.size():
		return false
	_portrait_index = index
	var entry: Dictionary = _portraits[index]
	var texture: Texture2D = load(entry["path"])
	if texture == null:
		printerr("角色查看器无法加载立绘: %s" % entry["path"])
		return false
	portrait_view.texture = texture
	_portrait_caption.text = "%s · %s" % [
		entry["label"],
		entry["file"],
	]
	var visual = idle_stage.get_visual() if idle_stage != null else null
	var method: StringName = entry["method"]
	if visual != null and visual.has_method(method):
		visual.call(method)
	return true


func select_idle_source(index: int) -> bool:
	if index < 0 or index >= IDLE_SOURCE_DEFS.size():
		return false
	_idle_source_index = index
	if _idle_source_option != null:
		_idle_source_option.select(index)
	if idle_stage != null:
		idle_stage.set_idle_animation(
			StringName(IDLE_SOURCE_DEFS[index]["animation"])
		)
	_update_animation_info()
	return true


func set_idle_loop_seconds(seconds: float) -> bool:
	var clamped := clampf(
		seconds,
		IDLE_LOOP_SECONDS_MIN,
		IDLE_LOOP_SECONDS_MAX
	)
	_idle_loop_seconds = clamped
	if _idle_seconds_slider != null:
		_idle_seconds_slider.set_value_no_signal(clamped)
	if idle_stage != null:
		idle_stage.set_idle_loop_seconds(clamped)
	_update_idle_loop_label()
	_update_animation_info()
	return is_equal_approx(_idle_loop_seconds, clamped)


func save_idle_loop_seconds() -> bool:
	if idle_stage == null:
		return false
	var frames: SpriteFrames = idle_stage.get_idle_frames()
	if frames == null or not frames.has_animation(&"idle_02"):
		return false
	var error := ResourceSaver.save(
		frames,
		CharacterRegistryScript.get_idle_animation_path(
			_current_character_id
		)
	)
	if error != OK:
		printerr("保存待机 02 失败: %s" % error_string(error))
		return false
	if _idle_seconds_label != null:
		_idle_seconds_label.text = "%.2fs · 已保存" % _idle_loop_seconds
	return true


func select_view(view: int) -> void:
	if view != VIEW_IDLE and view != VIEW_WALK:
		return
	_current_view = view
	for index in _view_buttons.size():
		_view_buttons[index].set_pressed_no_signal(index == view)
	idle_stage.visible = view == VIEW_IDLE
	_idle_controls.visible = view == VIEW_IDLE
	animation_sprite.visible = view == VIEW_WALK
	_walk_controls.visible = view == VIEW_WALK
	if view == VIEW_WALK and animation_sprite.sprite_frames != null:
		animation_sprite.play()
		_play_button.text = "暂停"
	_update_animation_info()


func select_walk_source(index: int) -> bool:
	if index < 0 or index >= _walk_sources.size():
		return false
	_walk_source_index = index
	if _source_option != null:
		_source_option.select(index)
	animation_sprite.sprite_frames = _walk_sources[index]["frames"]
	animation_sprite.animation = &"walk_left"
	if _current_view == VIEW_WALK:
		animation_sprite.play()
		_play_button.text = "暂停"
	_on_stage_resized()
	_update_animation_info()
	return true


func toggle_playback() -> void:
	if (
		animation_sprite == null
		or animation_sprite.sprite_frames == null
	):
		return
	if animation_sprite.is_playing():
		animation_sprite.pause()
		_play_button.text = "播放"
	else:
		animation_sprite.play()
		_play_button.text = "暂停"


func set_walk_flipped(flipped: bool) -> void:
	if animation_sprite != null:
		animation_sprite.flip_h = flipped
	if _flip_button != null:
		_flip_button.set_pressed_no_signal(flipped)


func set_walk_speed(speed_value: float) -> void:
	if animation_sprite == null:
		return
	var clamped := clampf(speed_value, 0.1, 2.0)
	animation_sprite.speed_scale = clamped
	if _speed_slider != null:
		_speed_slider.set_value_no_signal(clamped)
	if _speed_label != null:
		_speed_label.text = "%.2fx" % clamped
	_update_animation_info()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.035, 0.047)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var outer_margin := MarginContainer.new()
	outer_margin.name = "RootMargin"
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 22)
	outer_margin.add_theme_constant_override("margin_right", 22)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(outer_margin)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer_margin.add_child(header)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	header.add_child(title_row)

	var title := Label.new()
	title.text = "角色素材查看器"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	title_row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	var subtitle := Label.new()
	subtitle.text = "立绘 / 角色文档 / 当前角色待机动画 / 行走动画"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.72, 0.8))
	title_row.add_child(subtitle)

	_character_option = OptionButton.new()
	_character_option.name = "CharacterOption"
	_character_option.custom_minimum_size = Vector2(150.0, 36.0)
	for entry in CharacterRegistryScript.CHARACTERS:
		_character_option.add_item(entry["label"], entry["id"])
	_character_option.select(0)
	_character_option.item_selected.connect(_on_character_selected)
	title_row.add_child(_character_option)

	_character_status = Label.new()
	_character_status.name = "CharacterStatus"
	_character_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_character_status.custom_minimum_size = Vector2(260.0, 36.0)
	_character_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_character_status.add_theme_font_size_override("font_size", 14)
	title_row.add_child(_character_status)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
	header.add_child(rule)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	header.add_child(main)

	main.add_child(_build_portrait_panel())
	main.add_child(_build_preview_panel())


func _build_portrait_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "PortraitPanel"
	panel.custom_minimum_size = Vector2(412.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(ACCENT))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_section_label("立绘"))

	var frame := PanelContainer.new()
	frame.name = "PortraitFrame"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.45, 0.8, 0.92))
	)
	portrait_view = TextureRect.new()
	portrait_view.name = "PortraitView"
	portrait_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_view.custom_minimum_size = Vector2(0.0, 240.0)
	portrait_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(portrait_view)
	column.add_child(frame)

	_portrait_button_row = HBoxContainer.new()
	_portrait_button_row.name = "PortraitButtons"
	_portrait_button_row.add_theme_constant_override("separation", 8)
	column.add_child(_portrait_button_row)

	_portrait_caption = Label.new()
	_portrait_caption.name = "PortraitCaption"
	_portrait_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_portrait_caption.add_theme_color_override(
		"font_color",
		Color(0.7, 0.82, 0.88)
	)
	column.add_child(_portrait_caption)

	column.add_child(_section_label("角色文档"))
	var doc_scroll := ScrollContainer.new()
	doc_scroll.name = "CharacterDocumentScroll"
	doc_scroll.custom_minimum_size = Vector2(0.0, 96.0)
	doc_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	doc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_character_doc_label = Label.new()
	_character_doc_label.name = "CharacterDocument"
	_character_doc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_character_doc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_doc_label.add_theme_font_size_override("font_size", 13)
	_character_doc_label.add_theme_color_override(
		"font_color",
		Color(0.7, 0.8, 0.86)
	)
	doc_scroll.add_child(_character_doc_label)
	column.add_child(doc_scroll)
	return panel


func _build_preview_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.name = "PreviewPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 10)

	panel.add_child(_build_view_switcher())
	panel.add_child(_build_stage())

	_idle_controls = _build_idle_controls()
	panel.add_child(_idle_controls)

	_walk_controls = _build_walk_controls() as VBoxContainer
	panel.add_child(_walk_controls)

	animation_info = Label.new()
	animation_info.name = "AnimationInfo"
	animation_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	animation_info.add_theme_font_size_override("font_size", 15)
	animation_info.add_theme_color_override(
		"font_color",
		Color(0.72, 0.84, 0.9)
	)
	panel.add_child(animation_info)
	return panel


func _build_view_switcher() -> Control:
	var row := HBoxContainer.new()
	row.name = "ViewSwitcher"
	row.add_theme_constant_override("separation", 8)
	_view_buttons.clear()
	row.add_child(_make_mode_button("待机动画", VIEW_IDLE))
	row.add_child(_make_mode_button("行走动画", VIEW_WALK))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var hint := Label.new()
	hint.text = "角色立绘与动画预览"
	hint.add_theme_color_override("font_color", Color(0.58, 0.7, 0.77))
	row.add_child(hint)
	return row


func _make_mode_button(text_value: String, view: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(118.0, 38.0)
	button.pressed.connect(select_view.bind(view))
	_style_button(button, Color(0.34, 0.72, 0.86))
	_view_buttons.append(button)
	return button


func _build_idle_controls() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "IdleControls"
	box.add_theme_constant_override("separation", 8)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var label := Label.new()
	label.text = "待机剪片"
	label.custom_minimum_size = Vector2(86.0, 34.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0))
	row.add_child(label)

	_idle_source_option = OptionButton.new()
	_idle_source_option.custom_minimum_size = Vector2(286.0, 36.0)
	for index in IDLE_SOURCE_DEFS.size():
		_idle_source_option.add_item(
			IDLE_SOURCE_DEFS[index]["label"],
			index
		)
	_idle_source_option.select(IDLE_SOURCE_LOOP)
	_idle_source_option.item_selected.connect(select_idle_source)
	row.add_child(_idle_source_option)

	_idle_note = Label.new()
	_idle_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_idle_note.add_theme_font_size_override("font_size", 14)
	_idle_note.add_theme_color_override("font_color", Color(0.58, 0.7, 0.77))
	row.add_child(_idle_note)

	var cut_row := HBoxContainer.new()
	cut_row.add_theme_constant_override("separation", 8)
	box.add_child(cut_row)

	var cut_label := Label.new()
	cut_label.text = "记录 02 · 截取时长"
	cut_label.custom_minimum_size = Vector2(86.0, 36.0)
	cut_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cut_label.add_theme_font_size_override("font_size", 15)
	cut_label.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0))
	cut_row.add_child(cut_label)

	_idle_seconds_slider = HSlider.new()
	_idle_seconds_slider.min_value = IDLE_LOOP_SECONDS_MIN
	_idle_seconds_slider.max_value = IDLE_LOOP_SECONDS_MAX
	_idle_seconds_slider.step = IDLE_LOOP_SECONDS_STEP
	_idle_seconds_slider.value = IDLE_LOOP_SECONDS_DEFAULT
	_idle_seconds_slider.custom_minimum_size = Vector2(190.0, 34.0)
	_idle_seconds_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_idle_seconds_slider.value_changed.connect(set_idle_loop_seconds)
	cut_row.add_child(_idle_seconds_slider)

	_idle_seconds_label = Label.new()
	_idle_seconds_label.custom_minimum_size = Vector2(110.0, 36.0)
	_idle_seconds_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_idle_seconds_label.add_theme_font_size_override("font_size", 14)
	_idle_seconds_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.84, 0.9)
	)
	cut_row.add_child(_idle_seconds_label)

	_save_idle_button = Button.new()
	_save_idle_button.text = "保存 02"
	_save_idle_button.custom_minimum_size = Vector2(96.0, 36.0)
	_save_idle_button.pressed.connect(save_idle_loop_seconds)
	_style_button(_save_idle_button, Color(0.72, 0.55, 0.3))
	cut_row.add_child(_save_idle_button)

	_update_idle_loop_label()

	return box


func _build_stage() -> Control:
	var panel := PanelContainer.new()
	panel.name = "StagePanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.5, 0.62, 0.7))
	)

	var stage := Control.new()
	stage.name = "Stage"
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stage)

	var stage_background := ColorRect.new()
	stage_background.name = "StageBackground"
	stage_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_background.color = Color(0.012, 0.026, 0.036)
	stage_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(stage_background)

	idle_stage = IdleStage.new()
	idle_stage.name = "IdleStage"
	idle_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	idle_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(idle_stage)

	_stage_control = stage
	_stage_control.resized.connect(_on_stage_resized)

	animation_sprite = AnimatedSprite2D.new()
	animation_sprite.name = "WalkSprite"
	stage.add_child(animation_sprite)
	_on_stage_resized()
	return panel


func _build_walk_controls() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "WalkControls"
	box.add_theme_constant_override("separation", 8)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	_source_option = OptionButton.new()
	_source_option.custom_minimum_size = Vector2(215.0, 36.0)
	_source_option.item_selected.connect(select_walk_source)
	top.add_child(_source_option)

	_play_button = Button.new()
	_play_button.text = "暂停"
	_play_button.custom_minimum_size = Vector2(86.0, 36.0)
	_play_button.pressed.connect(toggle_playback)
	_style_button(_play_button, Color(0.36, 0.78, 0.9))
	top.add_child(_play_button)

	_flip_button = Button.new()
	_flip_button.text = "翻转"
	_flip_button.toggle_mode = true
	_flip_button.custom_minimum_size = Vector2(86.0, 36.0)
	_flip_button.toggled.connect(
		func(pressed: bool) -> void:
			if animation_sprite != null:
				animation_sprite.flip_h = pressed
	)
	_style_button(_flip_button, Color(0.62, 0.46, 0.86))
	top.add_child(_flip_button)

	box.add_child(top)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	var previous := Button.new()
	previous.text = "上一帧"
	previous.custom_minimum_size = Vector2(92.0, 36.0)
	previous.pressed.connect(_step_frame.bind(-1))
	_style_button(previous, Color(0.3, 0.55, 0.68))
	bottom.add_child(previous)

	var next := Button.new()
	next.text = "下一帧"
	next.custom_minimum_size = Vector2(92.0, 36.0)
	next.pressed.connect(_step_frame.bind(1))
	_style_button(next, Color(0.3, 0.55, 0.68))
	bottom.add_child(next)

	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.1
	_speed_slider.max_value = 2.0
	_speed_slider.step = 0.05
	_speed_slider.value = 1.0
	_speed_slider.custom_minimum_size = Vector2(170.0, 34.0)
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_slider.value_changed.connect(set_walk_speed)
	bottom.add_child(_speed_slider)

	_speed_label = Label.new()
	_speed_label.text = "1.00x"
	_speed_label.custom_minimum_size = Vector2(54.0, 0.0)
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_speed_label)

	box.add_child(bottom)
	return box


func _build_portrait_list(character_id: int) -> void:
	_portraits.clear()
	for entry in CharacterRegistryScript.PORTRAIT_FILES:
		var relative_path: String = entry["file"]
		if not CharacterRegistryScript.asset_exists(
			character_id,
			relative_path
		):
			continue
		_portraits.append(
			{
				"label": entry["label"],
				"file": relative_path,
				"path": CharacterRegistryScript.asset_path(
					character_id,
					relative_path
				),
				"method": _view_method_for(relative_path),
			}
		)

	for child in _portrait_button_row.get_children():
		_portrait_button_row.remove_child(child)
		child.free()
	for index in _portraits.size():
		var entry: Dictionary = _portraits[index]
		var button := Button.new()
		button.text = entry["label"]
		button.custom_minimum_size = Vector2(68.0, 34.0)
		button.pressed.connect(select_portrait.bind(index))
		_style_button(button, ACCENT)
		_portrait_button_row.add_child(button)


func _prepare_idle_stage(character_id: int) -> void:
	if idle_stage == null:
		return
	var visual_script := _visual_script_for(character_id)
	idle_stage.prepare(
		BattleUnitScript,
		visual_script,
		Color(0.24, 0.75, 0.98),
		true,
		character_id
	)
	idle_stage.set_idle_animation(
		StringName(IDLE_SOURCE_DEFS[_idle_source_index]["animation"])
	)
	idle_stage.set_idle_loop_seconds(_idle_loop_seconds)


func _load_walk_sources(character_id: int) -> void:
	_walk_sources.clear()
	_source_option.clear()
	for source in CharacterRegistryScript.WALK_SOURCES:
		var relative_path: String = source["path"]
		if not CharacterRegistryScript.asset_exists(
			character_id,
			relative_path
		):
			continue
		var frames = load(
			CharacterRegistryScript.asset_path(character_id, relative_path)
		)
		if frames is SpriteFrames:
			_walk_sources.append(
				{
					"label": source["label"],
					"path": relative_path,
					"frames": frames,
				}
			)
			_source_option.add_item(source["label"])
	if _walk_sources.is_empty():
		_source_option.add_item("资源不存在")
		_source_option.select(0)
	else:
		_source_option.select(0)


func _visual_script_for(character_id: int) -> GDScript:
	if character_id == CharacterRegistryScript.CharacterId.LXQ:
		return LxqBattleCharacter2DScript
	return AssetBattleCharacter2DScript


func _view_method_for(relative_path: String) -> StringName:
	match relative_path:
		"portrait.png":
			return &"use_portrait"
		"left.png":
			return &"use_left_view"
		"right.png":
			return &"use_right_view"
		"front.png":
			return &"use_front_view"
		"back.png":
			return &"use_back_view"
	return &"use_portrait"


func _collect_missing_assets(
	character_id: int,
	document: String
) -> Array[String]:
	var missing: Array[String] = []
	if document == "":
		missing.append("角色文档 README.md")
	if not CharacterRegistryScript.asset_exists(
		character_id,
		CharacterRegistryScript.IDLE_ANIMATION_FILE
	):
		missing.append("待机动画")
	var portrait_count := 0
	for entry in CharacterRegistryScript.PORTRAIT_FILES:
		if CharacterRegistryScript.asset_exists(
			character_id,
			entry["file"]
		):
			portrait_count += 1
	if portrait_count == 0:
		missing.append("立绘")
	var walk_count := 0
	for source in CharacterRegistryScript.WALK_SOURCES:
		if CharacterRegistryScript.asset_exists(
			character_id,
			source["path"]
		):
			walk_count += 1
	if walk_count == 0:
		missing.append("行走动画")
	return missing


func _sync_character_option() -> void:
	if _character_option == null:
		return
	for index in CharacterRegistryScript.CHARACTERS.size():
		if (
			CharacterRegistryScript.CHARACTERS[index]["id"]
			== _current_character_id
		):
			_character_option.select(index)
			return


func _on_character_selected(index: int) -> void:
	if index < 0 or index >= CharacterRegistryScript.CHARACTERS.size():
		return
	select_character(CharacterRegistryScript.CHARACTERS[index]["id"])


func _apply_walk_controls_state() -> void:
	var has_walk := not _walk_sources.is_empty()
	_source_option.disabled = not has_walk
	_play_button.disabled = not has_walk
	_flip_button.disabled = not has_walk
	_speed_slider.editable = has_walk


func _on_stage_resized() -> void:
	if (
		_stage_control == null
		or animation_sprite == null
		or animation_sprite.sprite_frames == null
	):
		return
	var frame_texture := animation_sprite.sprite_frames.get_frame_texture(
		animation_sprite.animation,
		animation_sprite.frame
	)
	var frame_size := Vector2(384.0, 512.0)
	if frame_texture != null:
		frame_size = Vector2(
			frame_texture.get_width(),
			frame_texture.get_height()
		)
	var target_size := _stage_control.size
	if target_size.x < 80.0 or target_size.y < 80.0:
		target_size = Vector2(960.0, 620.0)
	animation_sprite.position = target_size * Vector2(0.5, 0.56)
	var target_scale := minf(target_size.x / 720.0, target_size.y / 620.0)
	var max_scale := minf(
		target_size.x * 0.9 / frame_size.x,
		target_size.y * 0.9 / frame_size.y
	)
	animation_sprite.scale = Vector2.ONE * minf(
		clampf(target_scale, WALK_SCALE_MIN, WALK_SCALE_MAX),
		max_scale
	)


func _step_frame(offset: int) -> void:
	if animation_sprite == null or animation_sprite.sprite_frames == null:
		return
	var count := animation_sprite.sprite_frames.get_frame_count(
		animation_sprite.animation
	)
	if count <= 0:
		return
	animation_sprite.frame = wrapi(
		animation_sprite.frame + offset,
		0,
		count
	)


func _update_idle_loop_label() -> void:
	var loop_frame_count := 0
	var has_idle_frames := false
	if idle_stage != null and idle_stage.get_idle_frames() != null:
		var frames: SpriteFrames = idle_stage.get_idle_frames()
		if frames.has_animation(&"idle_02"):
			loop_frame_count = frames.get_frame_count(&"idle_02")
			has_idle_frames = true
	if _save_idle_button != null:
		_save_idle_button.disabled = not has_idle_frames
	if _idle_seconds_label != null:
		_idle_seconds_label.text = "%.2fs · %d帧" % [
			_idle_loop_seconds,
			loop_frame_count,
		]
	if _idle_note != null:
		if has_idle_frames:
			_idle_note.text = "02 记录 01 最后 %.2f 秒做循环" % _idle_loop_seconds
		else:
			_idle_note.text = "待机资源不存在"


func _update_animation_info() -> void:
	if animation_info == null:
		return
	var character_label := CharacterRegistryScript.get_character_label(
		_current_character_id
	)
	if _current_view == VIEW_WALK:
		if _walk_sources.is_empty() or animation_sprite.sprite_frames == null:
			animation_info.text = "%s 行走动画资源不存在" % character_label
			return
		var frames: SpriteFrames = animation_sprite.sprite_frames
		var count := frames.get_frame_count(animation_sprite.animation)
		var source_label: String = _walk_sources[_walk_source_index]["label"]
		animation_info.text = "%s · %s · 帧 %d/%d · %.2fx" % [
			source_label,
			animation_sprite.animation,
			animation_sprite.frame + 1,
			count,
			animation_sprite.speed_scale,
		]
		return

	var frames_source: SpriteFrames = null
	if idle_stage != null:
		frames_source = idle_stage.get_idle_frames()
	if (
		frames_source == null
		or frames_source.get_animation_names().is_empty()
	):
		animation_info.text = "%s 待机动画资源不存在" % character_label
		return
	var animation_name := &"idle_01"
	if idle_stage != null:
		var preview_name := idle_stage.get_idle_animation_name()
		if preview_name != &"":
			animation_name = preview_name
	if frames_source.has_animation(animation_name):
		var count := frames_source.get_frame_count(animation_name)
		var speed := frames_source.get_animation_speed(animation_name)
		var source_label: String = IDLE_SOURCE_DEFS[0]["label"]
		if (
			_idle_source_index >= 0
			and _idle_source_index < IDLE_SOURCE_DEFS.size()
		):
			source_label = IDLE_SOURCE_DEFS[_idle_source_index]["label"]
		var cut_text := ""
		if animation_name == &"idle_02":
			cut_text = " · 截取 %.2fs" % _idle_loop_seconds
		animation_info.text = "%s · %s · %s · %d 帧 / %.1f fps%s" % [
			character_label,
			source_label,
			animation_name,
			count,
			speed,
			cut_text,
		]


func _on_speed_changed(value: float) -> void:
	set_walk_speed(value)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.032, 0.052, 0.96)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 10
	return style


func _style_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.58)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.36)
	hover.border_color = accent.lightened(0.18)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.2)
	pressed.border_color = Color.WHITE

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))


func _section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0))
	return label


class IdleStage:
	extends Control

	const ORIGIN_Y_RATIO := 0.72

	var _unit_script: GDScript
	var _visual_script: GDScript
	var _unit = null
	var _visual = null
	var _initialized := false
	var _accent := Color.WHITE
	var _is_player := true

	func prepare(
		unit_script: GDScript,
		visual_script: GDScript,
		accent: Color,
		is_player: bool,
		character_id := -1
	) -> void:
		_unit_script = unit_script
		_visual_script = visual_script
		_accent = accent
		_is_player = is_player
		_unit = _unit_script.new()
		_unit.unit_name = "待机预览"
		_unit.max_hp = 120
		_unit.hp = 120
		_visual = _visual_script.new()
		_visual.display_scale = 0.9
		if (
			character_id >= 0
			and _visual.has_method("setup_character")
		):
			_visual.setup_character(
				character_id,
				_unit,
				_accent,
				_is_player
			)
		else:
			_visual.setup(_unit, _accent, _is_player)
		_initialized = true
		queue_redraw()

	func set_idle_animation(animation_name: StringName) -> void:
		if _visual != null:
			_visual.set_idle_animation_preview(animation_name)
		queue_redraw()


	func set_idle_loop_seconds(seconds: float) -> void:
		if _visual != null:
			_visual.set_idle_loop_seconds(seconds)
		queue_redraw()


	func get_idle_frames():
		if _visual != null:
			return _visual.idle_frames
		return null


	func get_idle_animation_name() -> StringName:
		if _visual != null and _visual.idle_frames != null:
			return _visual.idle_animation_override
		return &""

	func get_visual_origin() -> Vector2:
		return Vector2(size.x * 0.5, size.y * ORIGIN_Y_RATIO)

	func _process(delta: float) -> void:
		if not _initialized or not is_visible_in_tree():
			return
		_visual.update(delta)
		queue_redraw()

	func _draw() -> void:
		if not _initialized or _visual == null:
			return
		_visual.draw(self, get_visual_origin(), true)

	func is_ready() -> bool:
		return _initialized and _visual != null

	func get_visual():
		return _visual
