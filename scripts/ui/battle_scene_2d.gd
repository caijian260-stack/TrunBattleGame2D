class_name BattleScene2D
extends Control

## 2D 战斗场景父类：左右对峙的指令式战斗界面。
##
## 布局约定：敌人位于画面左侧，己方角色位于右侧，敌人血量以左上角横条呈现，
## 回合与行动资源在右上角，己方队伍卡与指令区集中在右侧。
## 本类只负责 2D 表现与输入界面，战斗规则仍由 BattleEngine 和 CharacterClass
## 子类提供。具体 2D 场景可以通过继承本类替换职业、敌人和默认外观。

const BattleEngineScript := preload("res://scripts/core/battle_engine.gd")
const BattleQTEScript := preload("res://scripts/core/battle_qte.gd")
const SwordCultivatorScript := preload("res://scripts/classes/sword_cultivator.gd")
const TrainingDummyScript := preload("res://scripts/classes/training_dummy.gd")
const BattleMenuScript := preload("res://scripts/core/battle_menu.gd")
const PlayerBattleCharacter2DScript := preload(
	"res://scripts/ui/player_battle_character_2d.gd"
)
const EnemyBattleCharacter2DScript := preload(
	"res://scripts/ui/enemy_battle_character_2d.gd"
)
const AssetBattleCharacter2DScript := preload(
	"res://scripts/ui/asset_battle_character_2d.gd"
)
const PlayerAppearanceSwitcherScript := preload(
	"res://scripts/ui/player_appearance_switcher.gd"
)
const CharacterRegistryScript := preload(
	"res://scripts/core/character_registry.gd"
)

# --------------------------------------------------------------------------
# 配色
# --------------------------------------------------------------------------

const PLAYER_ACCENT := Color(0.24, 0.75, 0.98)
const ENEMY_ACCENT := Color(0.95, 0.3, 0.28)
const GOLD_ACCENT := Color(0.93, 0.78, 0.44)
const HEALTH_HIGH := Color(0.25, 0.9, 0.52)
const HEALTH_MEDIUM := Color(1.0, 0.76, 0.2)
const HEALTH_LOW := Color(1.0, 0.25, 0.2)
const TEXT_PRIMARY := Color(0.94, 0.965, 0.98)
const TEXT_MUTED := Color(0.63, 0.71, 0.77)
const PLATE_FILL := Color(0.035, 0.07, 0.105, 0.9)
const PLATE_FILL_SOFT := Color(0.03, 0.055, 0.08, 0.82)

# --------------------------------------------------------------------------
# 布局（基准分辨率 1600x900）
# --------------------------------------------------------------------------
# 界面固定按 DESIGN_SIZE 排版，缩放由项目设置里的 canvas_items 拉伸完成
# （见 project.godot 的 display/window/stretch），因此 1152x648 等小窗口下
# HUD 与角色一起缩小，且字体按最终尺寸重新栅格化，不会发虚。
# --------------------------------------------------------------------------

const PLATE_SKEW := 34.0
const PLATE_MARGIN := Vector2(22.0, 18.0)
const ENEMY_PLATE_SIZE := Vector2(620.0, 98.0)
const STATUS_PLATE_SIZE := Vector2(400.0, 98.0)
const ACTION_PANEL_WIDTH := 344.0
const ACTION_PANEL_TOP := 268.0
const ACTION_PANEL_MIN_HEIGHT := 300.0
const PARTY_SLOT_COUNT := 3
const PARTY_CARD_SIZE := Vector2(240.0, 96.0)
const PARTY_CARD_GAP := 12.0
const LOG_PANEL_SIZE := Vector2(470.0, 132.0)
const QTE_PANEL_SIZE := Vector2(620.0, 150.0)
const RESULT_PANEL_SIZE := Vector2(540.0, 186.0)
const UI_MARGIN := 22.0
const ENEMY_FIELD_CENTER := Vector2(0.21, 0.60)
const PLAYER_FIELD_CENTER := Vector2(0.72, 0.60)
## 玩家外观测试面板（基准分辨率下的尺寸与顶部位置）。
const APPEARANCE_PANEL_SIZE := Vector2(470.0, 136.0)
const APPEARANCE_PANEL_TOP := 134.0
## 玩家外观默认值：-1 使用 PlayerBattleCharacter2D 的程序化外观。
const PLAYER_APPEARANCE_DEFAULT := -1
## 玩家外观显示高度（像素）的可输入范围。
const APPEARANCE_HEIGHT_MIN := 40.0
const APPEARANCE_HEIGHT_MAX := 1200.0

## 画面缩放：HUD 与字体统一按该系数缩小。
const UI_SCALE := 0.82
## 角色缩放：数值越小越像“拉远视角”，两名角色的间距同时被拉开。
const UNIT_SCALE := 0.78

@export var background_texture: Texture2D
@export var background_modulate: Color = Color.WHITE
@export var draw_arena_over_background := false

enum View {
	MAIN,
	SKILLS,
	CLASS_SPECIAL,
}

var engine: BattleEngine
var player_unit: BattleUnit
var enemy_unit: BattleUnit
var focus_enemy: BattleUnit
var current_view: int = View.MAIN
var encounter_data: Dictionary = {}

# 左上：敌人血量
var _enemy_plate: Control
var _enemy_plate_row: HBoxContainer
var _enemy_name_label: Label
var _enemy_hp_value_label: Label
var _enemy_hp_caption: Label

# 右上：回合与资源
var _status_plate: Control
var _status_row: HBoxContainer
var _turn_label: Label
var _battle_progress_label: Label
var _state_chip: PanelContainer
var _state_label: Label
var _ap_caption: Label

# 右侧：指令区
var _action_panel: PanelContainer
var _action_title: Label
var _action_subtitle: Label
var _action_list: VBoxContainer
var _action_shortcuts: Array[Callable] = []
var _end_turn_button: Button

# 右下：己方队伍卡 / 左下：战斗记录
var _party_strip: HBoxContainer
var _feed_panel: PanelContainer
var _log_label: RichTextLabel
var _player_battle_label: Label
var _enemy_battle_label: Label

# 覆盖层
var _dim_overlay: ColorRect
var _result_panel: PanelContainer
var _result_label: Label
var _result_hint: Label
var _return_scene_button: Button

var _qte_panel: PanelContainer
var _qte_title: Label
var _qte_instruction: Label
var _qte_input_hint: Label
var _qte_result: Label
var _qte_track: Control
var _qte_pointer: ColorRect
var _qte_success_zone: ColorRect
var _qte_perfect_zone: ColorRect
var _qte_task: BattleQTE = null
var _qte_active := false
var _qte_elapsed := 0.0
var _qte_hide_at := 0.0

var _scene_flow: Node = null
var _pulse := 0.0
var _character_visuals: Dictionary = {}

# 玩家外观测试：当前选中的 CharacterRegistry 角色 id。
var player_appearance_id := PLAYER_APPEARANCE_DEFAULT
# 玩家外观测试：显示高度（像素）。0 表示按 UNIT_SCALE 统一缩放。
var player_appearance_height := 0.0
var _appearance_switcher: PlayerAppearanceSwitcher


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	_load_encounter_context()
	_build_hud()
	_setup_battle()
	_layout_hud()
	_refresh_ui()


func _process(delta: float) -> void:
	if _qte_active and _qte_task != null:
		_qte_elapsed += delta
		var progress := clampf(
			_qte_elapsed / maxf(_qte_task.duration, 0.001),
			0.0,
			1.0
		)
		_set_qte_progress(progress)
		if progress >= 1.0:
			_finish_qte(BattleQTEScript.Grade.FAILURE)

	if (
		_qte_panel != null
		and _qte_panel.visible
		and not _qte_active
		and _qte_hide_at > 0.0
		and Time.get_ticks_msec() / 1000.0 >= _qte_hide_at
	):
		_qte_panel.visible = false
		_qte_hide_at = 0.0

	if engine != null:
		_pulse += delta
		for visual in _character_visuals.values():
			if visual != null:
				visual.update(delta)
		_sync_appearance_panel_size()
		queue_redraw()


# --------------------------------------------------------------------------
# 绘制
# --------------------------------------------------------------------------


func _draw() -> void:
	var canvas := size
	if canvas.x <= 1.0 or canvas.y <= 1.0:
		return

	_draw_backdrop(canvas)
	if background_texture == null or draw_arena_over_background:
		_draw_arena(canvas)

	_draw_field()

	_draw_plate(_enemy_plate_rect(), ENEMY_ACCENT, true)
	_draw_enemy_health_bar()
	_draw_plate(_status_plate_rect(), PLAYER_ACCENT, false)
	_draw_ap_pips()


func _draw_backdrop(canvas: Vector2) -> void:
	if background_texture != null:
		draw_texture_rect(
			background_texture,
			Rect2(Vector2.ZERO, canvas),
			false,
			background_modulate
		)
	else:
		_draw_default_background(canvas)

	# 上下压暗，保证 HUD 文字在明亮背景上依然清晰。
	_draw_scrim(Rect2(0.0, 0.0, canvas.x, 172.0), 0.4, true)
	_draw_scrim(Rect2(0.0, canvas.y - 200.0, canvas.x, 200.0), 0.45, false)


func _draw_default_background(canvas: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas), Color(0.035, 0.055, 0.08))
	draw_rect(
		Rect2(0.0, canvas.y * 0.58, canvas.x, canvas.y * 0.42),
		Color(0.06, 0.1, 0.12)
	)


func _draw_scrim(rect: Rect2, max_alpha: float, from_top: bool) -> void:
	var clear := Color(0.012, 0.02, 0.032, 0.0)
	var solid := Color(0.012, 0.02, 0.032, max_alpha)
	var top_color := solid if from_top else clear
	var bottom_color := clear if from_top else solid
	draw_polygon(
		PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	)


func _draw_arena(canvas: Vector2) -> void:
	var arena_center := Vector2(canvas.x * 0.5, canvas.y * 0.68)
	var arena_radius := Vector2(canvas.x * 0.42, canvas.y * 0.18)
	var arena_points := _ellipse_points(arena_center, arena_radius, 72)
	arena_points.append(arena_points[0])
	draw_colored_polygon(arena_points, Color(0.09, 0.145, 0.18, 0.9))
	draw_polyline(arena_points, Color(0.18, 0.48, 0.62, 0.6), 3.0, true)


func _plate_points(rect: Rect2, slant_right: bool) -> PackedVector2Array:
	var skew := minf(_s(PLATE_SKEW), rect.size.x * 0.2)
	if slant_right:
		return PackedVector2Array([
			rect.position,
			Vector2(rect.end.x - skew, rect.position.y),
			Vector2(rect.end.x, rect.position.y + skew),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
	return PackedVector2Array([
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x + skew, rect.position.y),
		Vector2(rect.position.x, rect.position.y + skew),
		Vector2(rect.position.x, rect.end.y),
		rect.end,
	])


func _draw_plate(rect: Rect2, accent: Color, slant_right: bool) -> void:
	var points := _plate_points(rect, slant_right)
	draw_colored_polygon(points, PLATE_FILL)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(
		outline,
		Color(accent.r, accent.g, accent.b, 0.5),
		_s(1.6),
		true
	)

	var underline := _s(3.0)
	draw_rect(
		Rect2(rect.position.x, rect.end.y - underline, rect.size.x, underline),
		Color(accent.r, accent.g, accent.b, 0.85)
	)

	var bar_width := _s(5.0)
	var bar_x := rect.position.x if slant_right else rect.end.x - bar_width
	draw_rect(
		Rect2(bar_x, rect.position.y, bar_width, rect.size.y - underline),
		Color(accent.r, accent.g, accent.b, 0.9)
	)


func _draw_enemy_health_bar() -> void:
	var bar := _enemy_hp_bar_rect()
	var unit := _focus_unit()
	var ratio := 0.0 if unit == null else clampf(unit.hp_ratio(), 0.0, 1.0)

	draw_rect(bar, Color(0.02, 0.03, 0.045, 0.94))
	var inner := Rect2(
		bar.position + Vector2(_s(2.0), _s(2.0)),
		Vector2(
			maxf((bar.size.x - _s(4.0)) * ratio, 0.0),
			bar.size.y - _s(4.0)
		)
	)
	if inner.size.x > 0.0:
		var fill := ENEMY_ACCENT if ratio > 0.25 else Color(1.0, 0.45, 0.32)
		draw_rect(inner, fill)
		draw_rect(
			Rect2(inner.position, Vector2(inner.size.x, _s(3.0))),
			fill.lightened(0.4)
		)

	for tick in range(1, 5):
		var x := (
			bar.position.x
			+ _s(2.0)
			+ (bar.size.x - _s(4.0)) * (float(tick) / 5.0)
		)
		draw_line(
			Vector2(x, bar.position.y + _s(2.0)),
			Vector2(x, bar.end.y - _s(2.0)),
			Color(0.0, 0.0, 0.0, 0.3),
			_s(1.0)
		)

	draw_rect(
		bar,
		Color(ENEMY_ACCENT.r, ENEMY_ACCENT.g, ENEMY_ACCENT.b, 0.8),
		false,
		_s(1.5)
	)


func _draw_ap_pips() -> void:
	if player_unit == null:
		return
	var rect := _ap_pips_rect()
	var count := maxi(player_unit.max_ap, 1)
	var gap := _s(6.0)
	var pip_width := minf(
		_s(13.0),
		(rect.size.x - gap * float(count - 1)) / float(count)
	)
	if pip_width <= 1.0:
		return
	var total := pip_width * float(count) + gap * float(count - 1)
	var start_x := rect.end.x - total
	var center_y := rect.position.y + rect.size.y * 0.5
	var half_height := _s(7.0)

	for index in range(count):
		var center_x := start_x + pip_width * 0.5 + float(index) * (pip_width + gap)
		var points := PackedVector2Array([
			Vector2(center_x, center_y - half_height),
			Vector2(center_x + pip_width * 0.5, center_y),
			Vector2(center_x, center_y + half_height),
			Vector2(center_x - pip_width * 0.5, center_y),
		])
		if index < player_unit.ap:
			draw_colored_polygon(
				points,
				Color(PLAYER_ACCENT.r, PLAYER_ACCENT.g, PLAYER_ACCENT.b, 0.95)
			)
		else:
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(
				outline,
				Color(PLAYER_ACCENT.r, PLAYER_ACCENT.g, PLAYER_ACCENT.b, 0.32),
				_s(1.4),
				true
			)


# --------------------------------------------------------------------------
# 战场
# --------------------------------------------------------------------------


func _draw_field() -> void:
	if engine == null:
		return

	var enemies := _field_enemies()
	var enemy_origins := _field_origins(ENEMY_FIELD_CENTER, enemies.size())
	for index in range(enemies.size()):
		var unit := enemies[index]
		if index >= enemy_origins.size():
			continue
		var origin := enemy_origins[index]
		_draw_unit(unit, origin, ENEMY_ACCENT, false)
		if unit == focus_enemy and _is_player_turn():
			_draw_target_marker(origin)

	var players := _field_players()
	var player_origins := _field_origins(PLAYER_FIELD_CENTER, players.size())
	for index in range(players.size()):
		if index >= player_origins.size():
			continue
		_draw_unit(players[index], player_origins[index], PLAYER_ACCENT, true)


func _field_enemies() -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	if engine != null:
		units = engine.enemy_units
	return units


func _field_players() -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	if engine != null:
		units = engine.player_units
	return units


func _field_origins(center_ratio: Vector2, count: int) -> Array[Vector2]:
	var origins: Array[Vector2] = []
	if count <= 0:
		return origins

	var center := Vector2(size.x * center_ratio.x, size.y * center_ratio.y)
	var spread := clampf(size.x / 1600.0, 0.65, 1.6)
	var offsets: Array[Vector2] = []
	if count == 1:
		offsets = [Vector2.ZERO]
	elif count == 2:
		offsets = [Vector2(-78.0, -14.0), Vector2(78.0, 18.0)]
	else:
		offsets = [
			Vector2(-140.0, -10.0),
			Vector2(0.0, 26.0),
			Vector2(140.0, -10.0),
		]
		while offsets.size() < count:
			offsets.append(Vector2(0.0, 26.0))

	for offset in offsets:
		origins.append(center + offset * spread)
	return origins


func _draw_unit(
	unit: BattleUnit,
	origin: Vector2,
	accent: Color,
	is_player: bool
) -> void:
	if unit == null:
		return
	var active := engine != null and engine.active_actor == unit
	var visual := _get_character_visual(unit, accent, is_player)
	if visual == null:
		return
	visual.draw(self, origin, active)


func _get_character_visual(
	unit: BattleUnit,
	accent: Color,
	is_player: bool
) -> BattleCharacter2D:
	var visual: BattleCharacter2D = _character_visuals.get(unit)
	if visual == null:
		visual = _create_character_visual(unit, accent, is_player)
		_character_visuals[unit] = visual
	return visual


func _create_character_visual(
	unit: BattleUnit,
	accent: Color,
	is_player: bool
) -> BattleCharacter2D:
	if is_player and player_appearance_id != PLAYER_APPEARANCE_DEFAULT:
		return _create_appearance_visual(unit, accent)
	var visual: BattleCharacter2D
	if is_player:
		visual = PlayerBattleCharacter2DScript.new()
	else:
		visual = EnemyBattleCharacter2DScript.new()
	visual.setup(unit, accent, is_player)
	_apply_visual_height(visual)
	return visual


## 按 CharacterRegistry 中的角色素材创建玩家外观。
##
## AssetBattleCharacter2D 会读取该角色目录下的待机 SpriteFrames，因此新视觉
## 建立后由 BattleCharacter2D 自动播放所选角色的待机动画。
func _create_appearance_visual(
	unit: BattleUnit,
	accent: Color
) -> BattleCharacter2D:
	var visual: BattleCharacter2D = AssetBattleCharacter2DScript.new()
	visual.setup_character(player_appearance_id, unit, accent, true)
	_apply_visual_height(visual)
	return visual


## 按 player_appearance_height 决定视觉缩放；未设置尺寸时沿用 UNIT_SCALE。
func _apply_visual_height(visual: BattleCharacter2D) -> void:
	if visual == null:
		return
	if player_appearance_height <= 0.0:
		visual.display_scale = UNIT_SCALE
		return
	var source_height := visual.get_appearance_pixel_size().y
	if source_height <= 0.0:
		visual.display_scale = UNIT_SCALE
		return
	visual.display_scale = player_appearance_height / source_height


## 切换玩家外观（外观测试用）。
##
## character_id 取 CharacterRegistry 登记的角色 id；传入
## PLAYER_APPEARANCE_DEFAULT(-1) 恢复默认程序化外观。切换后玩家视觉会被
## 重建，所选角色的待机动画自动载入并从头播放。
func set_player_appearance(character_id: int) -> bool:
	if (
		character_id != PLAYER_APPEARANCE_DEFAULT
		and not CharacterRegistryScript.has_character(character_id)
	):
		return false
	player_appearance_id = character_id
	_drop_player_visuals()
	if _appearance_switcher != null:
		_appearance_switcher.select_appearance(character_id)
	queue_redraw()
	return true


## 返回玩家当前使用的外观 id（PLAYER_APPEARANCE_DEFAULT 为默认外观）。
func get_player_appearance_id() -> int:
	return player_appearance_id


## 设置玩家外观的显示高度（像素）。
##
## 传入正数后玩家视觉按“显示高度 / 素材高度”计算缩放，因此切换外观时
## 屏幕上的角色高矮保持一致；传 0 恢复 UNIT_SCALE 统一缩放。
func set_player_appearance_height(height_px: float) -> bool:
	if height_px < 0.0:
		return false
	if is_zero_approx(height_px):
		player_appearance_height = 0.0
	else:
		player_appearance_height = clampf(
			height_px,
			APPEARANCE_HEIGHT_MIN,
			APPEARANCE_HEIGHT_MAX
		)
	_apply_player_visual_size()
	_sync_appearance_panel_size()
	queue_redraw()
	return true


## 返回玩家外观的显示高度（像素），0 表示沿用 UNIT_SCALE。
func get_player_appearance_height() -> float:
	return player_appearance_height


## 把当前显示高度重新套用到已缓存的玩家视觉上。
func _apply_player_visual_size() -> void:
	if engine == null:
		return
	for unit in engine.player_units:
		_apply_visual_height(
			_character_visuals.get(unit) as BattleCharacter2D
		)


## 丢弃玩家视觉缓存，让下一次绘制按当前外观重建。
func _drop_player_visuals() -> void:
	if engine == null:
		return
	for unit in engine.player_units:
		_character_visuals.erase(unit)


func _on_player_appearance_selected(character_id: int) -> void:
	set_player_appearance(character_id)


func _on_player_appearance_size_selected(height_px: float) -> void:
	set_player_appearance_height(height_px)


func _draw_target_marker(origin: Vector2) -> void:
	draw_set_transform(origin, 0.0, Vector2(UNIT_SCALE, UNIT_SCALE))
	var bob := 4.0 * sin(_pulse * 3.0)
	var center := Vector2(0.0, -214.0 + bob)
	var half := 12.0
	var diamond := PackedVector2Array([
		Vector2(center.x, center.y - half),
		Vector2(center.x + half * 0.72, center.y),
		Vector2(center.x, center.y + half),
		Vector2(center.x - half * 0.72, center.y),
	])
	draw_colored_polygon(
		diamond,
		Color(ENEMY_ACCENT.r, ENEMY_ACCENT.g, ENEMY_ACCENT.b, 0.9)
	)
	var outline := diamond.duplicate()
	outline.append(diamond[0])
	draw_polyline(outline, Color(1.0, 0.94, 0.9, 0.9), 1.6, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(center.x, center.y + 21.0),
			Vector2(center.x - 7.0, center.y + 9.0),
			Vector2(center.x + 7.0, center.y + 9.0),
		]),
		Color(ENEMY_ACCENT.r, ENEMY_ACCENT.g, ENEMY_ACCENT.b, 0.75)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --------------------------------------------------------------------------
# HUD 构建
# --------------------------------------------------------------------------


func _build_hud() -> void:
	_build_enemy_plate()
	_build_status_plate()
	_build_action_panel()
	_party_strip = _build_party_strip()
	_build_log_panel()
	_player_battle_label = _create_battle_label(PLAYER_ACCENT)
	_enemy_battle_label = _create_battle_label(ENEMY_ACCENT)
	_qte_panel = _build_qte_panel()

	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "DimOverlay"
	_dim_overlay.color = Color(0.01, 0.02, 0.03, 0.62)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim_overlay.visible = false
	add_child(_dim_overlay)

	_result_panel = _build_result_panel()
	_appearance_switcher = _build_appearance_switcher()


## 玩家外观测试面板：下拉列表切换玩家外观，替换后自动载入所选待机动画。
func _build_appearance_switcher() -> PlayerAppearanceSwitcher:
	var switcher := PlayerAppearanceSwitcherScript.new() as PlayerAppearanceSwitcher
	switcher.name = "PlayerAppearanceSwitcher"
	switcher.appearance_selected.connect(_on_player_appearance_selected)
	switcher.appearance_size_selected.connect(
		_on_player_appearance_size_selected
	)
	add_child(switcher)
	switcher.select_appearance(player_appearance_id)
	return switcher


## 把玩家外观的源尺寸与显示尺寸推送到测试面板。
func _sync_appearance_panel_size() -> void:
	if _appearance_switcher == null or player_unit == null:
		return
	var visual := _get_character_visual(player_unit, PLAYER_ACCENT, true)
	_apply_visual_height(visual)
	_appearance_switcher.set_visual_size(
		visual.get_appearance_pixel_size(),
		visual.get_display_size()
	)


func _build_enemy_plate() -> void:
	_enemy_plate = Control.new()
	_enemy_plate.name = "EnemyPlate"
	_enemy_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_plate)

	_enemy_plate_row = HBoxContainer.new()
	_enemy_plate_row.name = "EnemyPlateRow"
	_enemy_plate_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_plate_row.add_theme_constant_override("separation", 12)
	_enemy_plate.add_child(_enemy_plate_row)

	var tag_holder := PanelContainer.new()
	tag_holder.custom_minimum_size = _sv(Vector2(86.0, 28.0))
	tag_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_holder.add_theme_stylebox_override(
		"panel",
		_flat_style(
			Color(0.34, 0.08, 0.09, 0.92),
			Color(ENEMY_ACCENT.r, ENEMY_ACCENT.g, ENEMY_ACCENT.b, 0.72),
			3
		)
	)
	_enemy_plate_row.add_child(tag_holder)

	var tag_label := Label.new()
	tag_label.text = "ENEMY"
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_label.add_theme_font_size_override("font_size", _fs(14))
	tag_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.78))
	tag_holder.add_child(tag_label)

	_enemy_name_label = Label.new()
	_enemy_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_name_label.add_theme_font_size_override("font_size", _fs(23))
	_enemy_name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	_enemy_name_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.85)
	)
	_enemy_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_enemy_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_enemy_plate_row.add_child(_enemy_name_label)

	_enemy_hp_value_label = Label.new()
	_enemy_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_hp_value_label.custom_minimum_size = _sv(Vector2(168.0, 0.0))
	_enemy_hp_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_hp_value_label.add_theme_font_size_override("font_size", _fs(18))
	_enemy_hp_value_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.9, 0.86)
	)
	_enemy_plate_row.add_child(_enemy_hp_value_label)

	_enemy_hp_caption = Label.new()
	_enemy_hp_caption.text = BattleAttribute.label(BattleAttribute.Type.HP)
	_enemy_hp_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_hp_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_hp_caption.add_theme_font_size_override("font_size", _fs(14))
	_enemy_hp_caption.add_theme_color_override(
		"font_color",
		Color(1.0, 0.68, 0.62)
	)
	_enemy_plate.add_child(_enemy_hp_caption)


func _build_status_plate() -> void:
	_status_plate = Control.new()
	_status_plate.name = "StatusPlate"
	_status_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_plate)

	_status_row = HBoxContainer.new()
	_status_row.name = "StatusRow"
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.add_theme_constant_override("separation", 8)
	_status_plate.add_child(_status_row)

	_turn_label = Label.new()
	_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_label.add_theme_font_size_override("font_size", _fs(22))
	_turn_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	_turn_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.85)
	)
	_turn_label.add_theme_constant_override("shadow_offset_x", 1)
	_turn_label.add_theme_constant_override("shadow_offset_y", 2)
	_status_row.add_child(_turn_label)

	_battle_progress_label = Label.new()
	_battle_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_battle_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_battle_progress_label.custom_minimum_size = _sv(Vector2(140.0, 0.0))
	_battle_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_progress_label.add_theme_font_size_override("font_size", _fs(14))
	_battle_progress_label.add_theme_color_override("font_color", TEXT_MUTED)
	_status_row.add_child(_battle_progress_label)

	_state_chip = PanelContainer.new()
	_state_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_plate.add_child(_state_chip)

	_state_label = Label.new()
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_label.add_theme_font_size_override("font_size", _fs(15))
	_state_chip.add_child(_state_label)

	_ap_caption = Label.new()
	_ap_caption.text = BattleAttribute.label(BattleAttribute.Type.AP)
	_ap_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ap_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ap_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ap_caption.add_theme_font_size_override("font_size", _fs(14))
	_ap_caption.add_theme_color_override("font_color", TEXT_MUTED)
	_status_plate.add_child(_ap_caption)


func _build_action_panel() -> void:
	_action_panel = PanelContainer.new()
	_action_panel.name = "ActionPanel"
	_action_panel.add_theme_stylebox_override("panel", _panel_style(PLAYER_ACCENT))
	add_child(_action_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_action_panel.add_child(content)

	_action_title = Label.new()
	_action_title.add_theme_font_size_override("font_size", _fs(20))
	_action_title.add_theme_color_override("font_color", GOLD_ACCENT)
	content.add_child(_action_title)

	_action_subtitle = Label.new()
	_action_subtitle.add_theme_font_size_override("font_size", _fs(13))
	_action_subtitle.add_theme_color_override("font_color", TEXT_MUTED)
	content.add_child(_action_subtitle)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, _s(2.0))
	divider.color = Color(PLAYER_ACCENT.r, PLAYER_ACCENT.g, PLAYER_ACCENT.b, 0.4)
	content.add_child(divider)

	_action_list = VBoxContainer.new()
	_action_list.name = "ActionList"
	_action_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_list.add_theme_constant_override("separation", 8)
	content.add_child(_action_list)

	_end_turn_button = Button.new()
	_end_turn_button.text = "结束回合"
	_end_turn_button.custom_minimum_size = Vector2(0.0, _s(42.0))
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_style_button(_end_turn_button, GOLD_ACCENT)
	content.add_child(_end_turn_button)


func _build_party_strip() -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.name = "PartyStrip"
	strip.add_theme_constant_override("separation", int(PARTY_CARD_GAP))
	add_child(strip)
	return strip


func _build_log_panel() -> void:
	_feed_panel = PanelContainer.new()
	_feed_panel.name = "BattleLog"
	_feed_panel.add_theme_stylebox_override(
		"panel",
		_flat_style(
			Color(0.02, 0.035, 0.05, 0.8),
			Color(0.4, 0.58, 0.7, 0.42),
			6
		)
	)
	add_child(_feed_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_feed_panel.add_child(content)

	var heading := Label.new()
	heading.text = "战斗记录"
	heading.add_theme_font_size_override("font_size", _fs(14))
	heading.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	content.add_child(heading)

	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.scroll_following = true
	_log_label.scroll_active = true
	_log_label.add_theme_font_size_override("normal_font_size", _fs(13))
	_log_label.add_theme_color_override("default_color", Color(0.86, 0.92, 0.95))
	content.add_child(_log_label)


func _create_battle_label(accent: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", _fs(15))
	label.add_theme_color_override("font_color", accent.lightened(0.25))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label


func _build_qte_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "QTEPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(GOLD_ACCENT))
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	_qte_title = Label.new()
	_qte_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_title.add_theme_font_size_override("font_size", _fs(20))
	_qte_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	content.add_child(_qte_title)

	_qte_instruction = Label.new()
	_qte_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_instruction.add_theme_font_size_override("font_size", _fs(14))
	_qte_instruction.add_theme_color_override(
		"font_color",
		Color(0.86, 0.92, 0.97)
	)
	content.add_child(_qte_instruction)

	_qte_track = Control.new()
	_qte_track.custom_minimum_size = Vector2(0.0, _s(46.0))
	_qte_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_qte_track)

	var track_background := ColorRect.new()
	track_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_background.color = Color(0.05, 0.08, 0.11, 0.98)
	_qte_track.add_child(track_background)

	_qte_success_zone = ColorRect.new()
	_qte_success_zone.color = Color(0.16, 0.55, 0.72, 0.72)
	_qte_track.add_child(_qte_success_zone)

	_qte_perfect_zone = ColorRect.new()
	_qte_perfect_zone.color = Color(1.0, 0.72, 0.22, 0.92)
	_qte_track.add_child(_qte_perfect_zone)

	_qte_pointer = ColorRect.new()
	_qte_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_pointer.color = Color.WHITE
	_qte_pointer.size = Vector2(_s(4.0), _s(46.0))
	_qte_track.add_child(_qte_pointer)

	var hint_row := HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.add_theme_constant_override("separation", 18)
	content.add_child(hint_row)

	_qte_input_hint = Label.new()
	_qte_input_hint.add_theme_font_size_override("font_size", _fs(14))
	_qte_input_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	hint_row.add_child(_qte_input_hint)

	_qte_result = Label.new()
	_qte_result.text = "等待判定"
	_qte_result.add_theme_font_size_override("font_size", _fs(14))
	_qte_result.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	hint_row.add_child(_qte_result)

	panel.visible = false
	return panel


func _build_result_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ResultPanel"
	panel.add_theme_stylebox_override("panel", _panel_style(GOLD_ACCENT))
	add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", _fs(26))
	_result_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	content.add_child(_result_label)

	_result_hint = Label.new()
	_result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_hint.add_theme_font_size_override("font_size", _fs(14))
	_result_hint.add_theme_color_override("font_color", TEXT_MUTED)
	content.add_child(_result_hint)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	content.add_child(action_row)

	_return_scene_button = Button.new()
	_return_scene_button.text = "返回场景"
	_return_scene_button.custom_minimum_size = _sv(Vector2(132.0, 40.0))
	_return_scene_button.pressed.connect(_on_return_scene_pressed)
	_style_button(_return_scene_button, PLAYER_ACCENT)
	action_row.add_child(_return_scene_button)

	var restart_button := Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = _sv(Vector2(132.0, 40.0))
	restart_button.pressed.connect(_on_restart_pressed)
	_style_button(restart_button, GOLD_ACCENT)
	action_row.add_child(restart_button)

	panel.visible = false
	return panel


# --------------------------------------------------------------------------
# HUD 布局
# --------------------------------------------------------------------------


func _enemy_plate_rect() -> Rect2:
	return Rect2(_sv(PLATE_MARGIN), _sv(ENEMY_PLATE_SIZE))


func _status_plate_rect() -> Rect2:
	var plate_size := _sv(STATUS_PLATE_SIZE)
	var margin := _sv(PLATE_MARGIN)
	return Rect2(
		Vector2(size.x - plate_size.x - margin.x, margin.y),
		plate_size
	)


func _enemy_hp_bar_rect() -> Rect2:
	var plate := _enemy_plate_rect()
	return Rect2(
		plate.position + _sv(Vector2(52.0, 54.0)),
		Vector2(_s(ENEMY_PLATE_SIZE.x - 52.0 - 30.0), _s(22.0))
	)


func _ap_pips_rect() -> Rect2:
	var plate := _status_plate_rect()
	return Rect2(
		plate.position + _sv(Vector2(196.0, 54.0)),
		Vector2(_s(STATUS_PLATE_SIZE.x - 196.0 - 22.0), _s(24.0))
	)


func _layout_hud() -> void:
	if _enemy_plate == null:
		return
	var canvas := size
	if canvas.x <= 1.0 or canvas.y <= 1.0:
		return

	# 左上：敌人血量
	_enemy_plate.position = _sv(PLATE_MARGIN)
	_enemy_plate.size = _sv(ENEMY_PLATE_SIZE)
	_enemy_plate_row.position = _sv(Vector2(20.0, 12.0))
	_enemy_plate_row.size = Vector2(_s(ENEMY_PLATE_SIZE.x - 40.0), _s(30.0))
	_enemy_hp_caption.position = _sv(Vector2(20.0, 53.0))
	_enemy_hp_caption.size = _sv(Vector2(26.0, 24.0))

	# 右上：回合与行动资源
	_status_plate.size = _sv(STATUS_PLATE_SIZE)
	_status_plate.position = _status_plate_rect().position
	_status_row.position = _sv(Vector2(20.0, 12.0))
	_status_row.size = Vector2(_s(STATUS_PLATE_SIZE.x - 40.0), _s(30.0))
	_state_chip.position = _sv(Vector2(20.0, 52.0))
	_state_chip.size = _sv(Vector2(112.0, 28.0))
	_ap_caption.position = Vector2(_s(STATUS_PLATE_SIZE.x - 216.0), _s(52.0))
	_ap_caption.size = _sv(Vector2(28.0, 28.0))

	# 右侧：指令区
	var party_top := canvas.y - _s(UI_MARGIN) - _s(PARTY_CARD_SIZE.y)
	var panel_bottom := party_top - _s(20.0)
	var min_height := _s(ACTION_PANEL_MIN_HEIGHT)
	var available := maxf(panel_bottom - _s(ACTION_PANEL_TOP), min_height)
	var panel_height := clampf(_action_panel_height(), min_height, available)
	_action_panel.position = Vector2(
		canvas.x - _s(ACTION_PANEL_WIDTH) - _s(UI_MARGIN),
		panel_bottom - panel_height
	)
	_action_panel.size = Vector2(_s(ACTION_PANEL_WIDTH), panel_height)

	# 右下：己方队伍卡
	var strip_width := (
		_s(PARTY_CARD_SIZE.x) * float(PARTY_SLOT_COUNT)
		+ _s(PARTY_CARD_GAP) * float(PARTY_SLOT_COUNT - 1)
	)
	_party_strip.add_theme_constant_override("separation", int(_s(PARTY_CARD_GAP)))
	_party_strip.position = Vector2(canvas.x - _s(UI_MARGIN) - strip_width, party_top)
	_party_strip.size = Vector2(strip_width, _s(PARTY_CARD_SIZE.y))

	# 左下：战斗记录
	_feed_panel.position = Vector2(
		_s(UI_MARGIN),
		canvas.y - _s(UI_MARGIN) - _s(LOG_PANEL_SIZE.y)
	)
	_feed_panel.size = _sv(LOG_PANEL_SIZE)

	# 覆盖层
	_dim_overlay.position = Vector2.ZERO
	_dim_overlay.size = canvas
	_qte_panel.size = _sv(QTE_PANEL_SIZE)
	_qte_panel.position = Vector2(
		(canvas.x - _s(QTE_PANEL_SIZE.x)) * 0.5,
		party_top - _s(12.0) - _s(QTE_PANEL_SIZE.y)
	)
	_result_panel.size = _sv(RESULT_PANEL_SIZE)
	_result_panel.position = (canvas - _sv(RESULT_PANEL_SIZE)) * 0.5

	# 顶部居中：玩家外观测试面板，位于顶部两块状态板下方
	if _appearance_switcher != null:
		var switcher_size := _sv(APPEARANCE_PANEL_SIZE)
		_appearance_switcher.size = switcher_size
		_appearance_switcher.position = Vector2(
			(canvas.x - switcher_size.x) * 0.5,
			_s(APPEARANCE_PANEL_TOP)
		)

	_layout_battle_labels()


## 指令区高度按按钮数量估算，避免面板被拉长后中间留出大片空白。
func _action_panel_height() -> float:
	var buttons := maxi(_action_list.get_child_count(), 1)
	return (
		_s(144.0)
		+ float(buttons) * _s(50.0)
		+ float(buttons - 1) * _s(8.0)
	)


func _layout_battle_labels() -> void:
	if _player_battle_label == null or _enemy_battle_label == null:
		return
	var label_size := _sv(Vector2(260.0, 44.0))
	var label_offset := _sv(Vector2(-130.0, 18.0))
	_enemy_battle_label.position = _enemy_origin() + label_offset
	_enemy_battle_label.size = label_size
	_player_battle_label.position = _player_origin() + label_offset
	_player_battle_label.size = label_size


func _enemy_origin() -> Vector2:
	var enemies := _field_enemies()
	var origins := _field_origins(ENEMY_FIELD_CENTER, maxi(enemies.size(), 1))
	if origins.is_empty():
		return Vector2(size.x * ENEMY_FIELD_CENTER.x, size.y * ENEMY_FIELD_CENTER.y)
	var index := enemies.find(focus_enemy)
	if index < 0 or index >= origins.size():
		index = 0
	return origins[index]


func _player_origin() -> Vector2:
	var origins := _field_origins(PLAYER_FIELD_CENTER, 1)
	if origins.is_empty():
		return Vector2(size.x * PLAYER_FIELD_CENTER.x, size.y * PLAYER_FIELD_CENTER.y)
	return origins[0]


func _on_resized() -> void:
	_layout_hud()
	if _qte_track != null:
		_set_qte_progress(_qte_progress())
	queue_redraw()


# --------------------------------------------------------------------------
# 战斗装配
# --------------------------------------------------------------------------


func _load_encounter_context() -> void:
	var scene_flow := _get_scene_flow()
	if scene_flow == null:
		return
	encounter_data = scene_flow.encounter_data.duplicate(true)


func _get_scene_flow() -> Node:
	if _scene_flow != null and is_instance_valid(_scene_flow):
		return _scene_flow
	_scene_flow = get_node_or_null("/root/SceneFlow")
	return _scene_flow


func _setup_battle() -> void:
	engine = BattleEngineScript.new()
	_character_visuals.clear()
	var player_class := _create_player_class()
	var enemy_class := _create_enemy_class()
	var player_name := str(encounter_data.get("player_name", "剑修"))
	var enemy_name := str(encounter_data.get("enemy_name", "训练假人"))
	var enemy_max_hp := int(encounter_data.get("enemy_max_hp", 260))
	var enemy_attack := int(encounter_data.get("enemy_attack", 14))

	engine.state_changed.connect(_on_state_changed)
	engine.log_emitted.connect(_on_log_emitted)
	engine.unit_changed.connect(_on_unit_changed)
	engine.battle_finished.connect(_on_battle_finished)
	engine.battle_escaped.connect(_on_battle_escaped)
	engine.qte_started.connect(_on_qte_started)
	engine.qte_resolved.connect(_on_qte_resolved)

	engine.setup_battle(
		[{
			"name": player_name,
			"max_hp": int(encounter_data.get("player_max_hp", 180)),
			"attack": int(encounter_data.get("player_attack", 20)),
			"class": player_class,
		}],
		[{
			"name": enemy_name,
			"max_hp": enemy_max_hp,
			"attack": enemy_attack,
			"class": enemy_class,
		}]
	)
	player_unit = engine.player_units[0]
	enemy_unit = engine.enemy_units[0]
	focus_enemy = enemy_unit
	engine.start()


func _create_player_class() -> CharacterClass:
	var sword_class := SwordCultivatorScript.new()
	sword_class.spiritual_sense = 25
	return sword_class


func _create_enemy_class() -> CharacterClass:
	return TrainingDummyScript.new()


# --------------------------------------------------------------------------
# 界面刷新
# --------------------------------------------------------------------------


func _refresh_ui() -> void:
	if player_unit == null or enemy_unit == null or engine == null:
		return

	_update_focus_enemy()

	_turn_label.text = _turn_text()
	_battle_progress_label.text = "BATTLE %d/%d" % [
		int(encounter_data.get("battle_index", 1)),
		int(encounter_data.get("battle_total", 1)),
	]
	_state_label.text = _state_text()
	_apply_state_chip_style()

	var focus := _focus_unit()
	if focus != null:
		_enemy_name_label.text = focus.unit_name
		_enemy_hp_value_label.text = "%d / %d" % [focus.hp, focus.max_hp]
	_enemy_battle_label.text = _format_battle_label(focus)
	_player_battle_label.text = _format_battle_label(player_unit)
	_layout_battle_labels()

	_end_turn_button.disabled = (
		engine.current_state != BattleEngineScript.State.PLAYER_TURN
	)
	_update_party_strip()
	_refresh_action_menu()
	_layout_hud()
	queue_redraw()


func _update_focus_enemy() -> void:
	focus_enemy = null
	if engine == null:
		return
	for unit in engine.enemy_units:
		if unit.hp > 0:
			focus_enemy = unit
			break
	if focus_enemy == null and not engine.enemy_units.is_empty():
		focus_enemy = engine.enemy_units[0]


func _focus_unit() -> BattleUnit:
	return focus_enemy if focus_enemy != null else enemy_unit


func _apply_state_chip_style() -> void:
	if _state_chip == null:
		return
	var accent := PLAYER_ACCENT
	match engine.current_state:
		BattleEngineScript.State.ENEMY_TURN:
			accent = ENEMY_ACCENT
		BattleEngineScript.State.QTE, BattleEngineScript.State.BATTLE_END:
			accent = GOLD_ACCENT
		BattleEngineScript.State.RESOLVING, BattleEngineScript.State.TURN_END:
			accent = Color(0.62, 0.7, 0.76)
		_:
			accent = PLAYER_ACCENT
	_state_chip.add_theme_stylebox_override(
		"panel",
		_flat_style(
			Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2, 0.92),
			Color(accent.r, accent.g, accent.b, 0.75),
			3
		)
	)
	_state_label.add_theme_color_override("font_color", accent.lightened(0.3))


func _refresh_action_menu() -> void:
	for child in _action_list.get_children():
		_action_list.remove_child(child)
		child.queue_free()
	_action_shortcuts.clear()

	var is_player_turn := _is_player_turn()
	var actor := engine.active_actor if is_player_turn else null
	if not is_player_turn or actor == null:
		_action_title.text = "等待"
		_action_subtitle.text = "敌方行动中"
		var waiting := Label.new()
		waiting.text = "当前不是玩家回合"
		waiting.add_theme_color_override("font_color", TEXT_MUTED)
		waiting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_list.add_child(waiting)
		return

	_action_subtitle.text = "%s  ·  %s %d / %d" % [
		actor.unit_name,
		BattleAttribute.label(BattleAttribute.Type.AT),
		actor.at,
		actor.max_at,
	]

	match current_view:
		View.SKILLS:
			_action_title.text = "技能"
			_add_command_buttons(actor, actor.battle_class.build_skill_commands(), true)
		View.CLASS_SPECIAL:
			_action_title.text = actor.battle_class.get_class_action_menu_name()
			_add_command_buttons(
				actor,
				actor.battle_class.build_class_action_commands(),
				true
			)
		_:
			_action_title.text = "行动"
			_add_main_buttons(actor)


func _add_main_buttons(actor: BattleUnit) -> void:
	var skill_commands := actor.battle_class.build_skill_commands()
	var special_commands := actor.battle_class.build_class_action_commands()
	var attack_command := actor.battle_class.build_attack_command()
	var ultimate_command := actor.battle_class.build_ultimate_command()

	_add_action_button(
		"攻击",
		func() -> void: _submit_command(
			attack_command.id if attack_command != null else &""
		),
		_command_tooltip(actor, attack_command),
		_is_command_available_for_actor(actor, attack_command)
	)
	_add_action_button(
		"技能",
		func() -> void: _set_view(View.SKILLS),
		"" if not skill_commands.is_empty() else "当前没有可用技能",
		not skill_commands.is_empty()
	)
	_add_action_button(
		actor.battle_class.get_class_action_menu_name(),
		func() -> void: _set_view(View.CLASS_SPECIAL),
		"" if not special_commands.is_empty() else "当前没有职业特殊行动",
		not special_commands.is_empty()
	)
	if ultimate_command != null:
		_add_action_button(
			ultimate_command.display_name,
			func() -> void: _submit_command(ultimate_command.id),
			_command_tooltip(actor, ultimate_command),
			_is_command_available_for_actor(actor, ultimate_command)
		)
	_add_action_button(
		BattleMenuScript.option_label(BattleMenuScript.Option.ESCAPE),
		func() -> void: engine.escape_player(),
		"尝试离开战斗",
		true
	)


func _add_command_buttons(
	actor: BattleUnit,
	commands: Array[BattleCommand],
	allow_back: bool
) -> void:
	for command in commands:
		_add_action_button(
			command.display_name,
			func() -> void: _submit_command(command.id),
			_command_tooltip(actor, command),
			_is_command_available_for_actor(actor, command)
		)
	if allow_back:
		_add_action_button("返回", _on_back_requested, "返回主菜单", true)


func _add_action_button(
	text: String,
	action: Callable,
	tooltip: String,
	available: bool = true
) -> void:
	var shortcut := _action_list.get_child_count() + 1
	var button := Button.new()
	button.text = "%d  %s" % [shortcut, text]
	button.tooltip_text = tooltip
	button.disabled = not available
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, _s(50.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	_style_button(button, PLAYER_ACCENT)
	_action_list.add_child(button)
	_action_shortcuts.append(action if available else Callable())


func _update_party_strip() -> void:
	if _party_strip == null:
		return
	for child in _party_strip.get_children():
		_party_strip.remove_child(child)
		child.queue_free()

	var units := _field_players()
	for index in range(PARTY_SLOT_COUNT):
		if index < units.size():
			var unit := units[index]
			var active := engine != null and engine.active_actor == unit
			_party_strip.add_child(_make_party_card(unit, active))
		else:
			_party_strip.add_child(_make_empty_card())


func _make_party_card(unit: BattleUnit, active: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = _sv(PARTY_CARD_SIZE)
	card.add_theme_stylebox_override(
		"panel",
		_flat_style(
			Color(0.03, 0.055, 0.08, 0.92) if active
				else Color(0.025, 0.04, 0.055, 0.82),
			PLAYER_ACCENT if active else Color(0.36, 0.44, 0.5, 0.55),
			6
		)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = _sv(Vector2(62.0, 72.0))
	portrait.add_theme_stylebox_override(
		"panel",
		_flat_style(
			PLAYER_ACCENT.darkened(0.62),
			Color(PLAYER_ACCENT.r, PLAYER_ACCENT.g, PLAYER_ACCENT.b, 0.7),
			4
		)
	)
	row.add_child(portrait)

	var portrait_label := Label.new()
	portrait_label.text = unit.unit_name.substr(0, 1)
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.add_theme_font_size_override("font_size", _fs(30))
	portrait_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.97, 1.0, 0.92)
	)
	portrait.add_child(portrait_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info.add_child(name_row)

	var name_label := Label.new()
	name_label.text = unit.unit_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", _fs(16))
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_row.add_child(name_label)

	var tag := Label.new()
	tag.text = "行动中" if active else "待命"
	tag.add_theme_font_size_override("font_size", _fs(12))
	tag.add_theme_color_override(
		"font_color",
		PLAYER_ACCENT if active else TEXT_MUTED
	)
	name_row.add_child(tag)

	var hp := ProgressBar.new()
	hp.min_value = 0.0
	hp.max_value = 1.0
	hp.value = unit.hp_ratio()
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0.0, _s(13.0))
	hp.add_theme_stylebox_override(
		"background",
		_flat_style(Color(0.02, 0.03, 0.04, 0.92), Color(0.24, 0.32, 0.36, 0.55), 2)
	)
	var hp_color := _health_color(unit.hp_ratio())
	hp.add_theme_stylebox_override(
		"fill",
		_flat_style(hp_color, hp_color.lightened(0.25), 2)
	)
	info.add_child(hp)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 8)
	info.add_child(stat_row)

	var hp_text := Label.new()
	hp_text.text = "%d / %d" % [unit.hp, unit.max_hp]
	hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_text.add_theme_font_size_override("font_size", _fs(12))
	hp_text.add_theme_color_override("font_color", Color(0.82, 0.88, 0.92))
	stat_row.add_child(hp_text)

	var ap_text := Label.new()
	ap_text.text = "%s %d / %d" % [
		BattleAttribute.label(BattleAttribute.Type.AP),
		unit.ap,
		unit.max_ap,
	]
	ap_text.add_theme_font_size_override("font_size", _fs(12))
	ap_text.add_theme_color_override("font_color", PLAYER_ACCENT)
	stat_row.add_child(ap_text)

	return card


func _make_empty_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = _sv(PARTY_CARD_SIZE)
	card.add_theme_stylebox_override(
		"panel",
		_flat_style(
			Color(0.02, 0.03, 0.04, 0.5),
			Color(0.26, 0.32, 0.36, 0.45),
			6
		)
	)
	var label := Label.new()
	label.text = "空位"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _fs(15))
	label.add_theme_color_override("font_color", Color(0.45, 0.52, 0.56))
	card.add_child(label)
	return card


# --------------------------------------------------------------------------
# 交互
# --------------------------------------------------------------------------


func _set_view(view: int) -> void:
	current_view = view
	_refresh_ui()


func _submit_command(command_id: StringName) -> void:
	if command_id == &"":
		return
	engine.submit_player_command(command_id)
	_refresh_ui()


func _on_back_requested() -> void:
	current_view = View.MAIN
	_refresh_ui()


func _on_end_turn_pressed() -> void:
	if engine != null:
		engine.end_player_turn()
	_refresh_ui()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_return_scene_pressed() -> void:
	var scene_flow := _get_scene_flow()
	if scene_flow == null or not scene_flow.has_battle_return():
		return
	var target: Dictionary = scene_flow.take_battle_return()
	var scene_path := str(target.get("scene_path", ""))
	if scene_path.is_empty():
		return
	scene_flow.queue_scene_entry(
		scene_path,
		StringName(target.get("spawn_id", &"")),
		target.get("position", null),
		target.get("yaw", null)
	)
	get_tree().change_scene_to_file(scene_path)


func _on_state_changed(state: int) -> void:
	if state != BattleEngineScript.State.PLAYER_TURN:
		current_view = View.MAIN
	_refresh_ui()


func _on_unit_changed(_unit: BattleUnit) -> void:
	_refresh_ui()


func _on_battle_finished(player_won: bool) -> void:
	_result_label.text = "战斗结束：" + ("胜利" if player_won else "失败")
	_refresh_result_panel()


func _on_battle_escaped() -> void:
	_result_label.text = "战斗结束：成功逃走"
	_refresh_result_panel()


func _refresh_result_panel() -> void:
	var scene_flow := _get_scene_flow()
	var can_return := scene_flow != null and bool(scene_flow.has_battle_return())
	_return_scene_button.visible = can_return
	_result_hint.text = "选择返回场景或重新开始" if can_return else "点击重新开始再战"
	_dim_overlay.visible = true
	_result_panel.visible = true
	_refresh_ui()


func _on_log_emitted(text: String) -> void:
	_log_label.append_text(text + "\n")


func _input(event: InputEvent) -> void:
	if _qte_active and _qte_task != null:
		if (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		):
			_finish_qte(_qte_task.evaluate(_qte_progress()))
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey:
			var qte_key := event as InputEventKey
			if qte_key.pressed and not qte_key.echo and qte_key.keycode == KEY_SPACE:
				_finish_qte(_qte_task.evaluate(_qte_progress()))
				get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		var index := int(key_event.keycode) - int(KEY_1)
		if index < 0 or index >= _action_shortcuts.size():
			return
		var shortcut := _action_shortcuts[index]
		if shortcut.is_valid():
			shortcut.call()
			get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------
# QTE
# --------------------------------------------------------------------------


func _on_qte_started(task: BattleQTE) -> void:
	_qte_task = task
	_qte_active = true
	_qte_elapsed = 0.0
	_qte_hide_at = 0.0
	_qte_panel.visible = true
	_qte_title.text = task.get_title()
	_qte_instruction.text = task.get_instruction()
	_qte_input_hint.text = task.get_input_hint()
	_qte_result.text = "等待判定"
	_qte_result.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	_apply_qte_zones(task)
	_set_qte_progress(0.0)


func _on_qte_resolved(task: BattleQTE, grade: int) -> void:
	_qte_result.text = "结果：" + task.get_result_label(grade)
	var color := Color(0.72, 0.8, 0.86)
	match grade:
		BattleQTEScript.Grade.FAILURE:
			color = Color(1.0, 0.42, 0.36)
		BattleQTEScript.Grade.SUCCESS:
			color = Color(0.4, 0.86, 1.0)
		BattleQTEScript.Grade.PERFECT:
			color = Color(1.0, 0.82, 0.3)
	_qte_result.add_theme_color_override("font_color", color)
	_qte_hide_at = Time.get_ticks_msec() / 1000.0 + 0.75


func _finish_qte(grade: int) -> void:
	if not _qte_active or _qte_task == null or engine == null:
		return
	_qte_active = false
	_set_qte_progress(_qte_progress())
	engine.resolve_qte(grade)


func _apply_qte_zones(task: BattleQTE) -> void:
	if _qte_success_zone == null or _qte_perfect_zone == null or task == null:
		return
	_qte_success_zone.anchor_left = 0.5 - task.success_window
	_qte_success_zone.anchor_right = 0.5 + task.success_window
	_qte_success_zone.anchor_top = 0.0
	_qte_success_zone.anchor_bottom = 1.0
	_qte_perfect_zone.anchor_left = 0.5 - task.perfect_window
	_qte_perfect_zone.anchor_right = 0.5 + task.perfect_window
	_qte_perfect_zone.anchor_top = 0.0
	_qte_perfect_zone.anchor_bottom = 1.0


func _qte_progress() -> float:
	if _qte_task == null:
		return 0.0
	return clampf(_qte_elapsed / maxf(_qte_task.duration, 0.001), 0.0, 1.0)


func _set_qte_progress(progress: float) -> void:
	if _qte_track == null or _qte_pointer == null:
		return
	var width := maxf(_qte_track.size.x, 1.0)
	_qte_pointer.size.y = _qte_track.size.y
	_qte_pointer.position = Vector2(
		clampf(progress, 0.0, 1.0) * width - _qte_pointer.size.x * 0.5,
		0.0
	)


# --------------------------------------------------------------------------
# 文案
# --------------------------------------------------------------------------


func _format_battle_label(unit: BattleUnit) -> String:
	if unit == null:
		return ""
	return "%s\n%s %d / %d" % [
		unit.unit_name,
		BattleAttribute.label(BattleAttribute.Type.HP),
		unit.hp,
		unit.max_hp,
	]


func _turn_text() -> String:
	return "第 %d 回合" % engine.round_number


func _state_text() -> String:
	var state_name := "准备"
	match engine.current_state:
		BattleEngineScript.State.PLAYER_TURN:
			state_name = "玩家回合"
		BattleEngineScript.State.ENEMY_TURN:
			state_name = "敌方回合"
		BattleEngineScript.State.QTE:
			state_name = "判定中"
		BattleEngineScript.State.RESOLVING:
			state_name = "行动结算"
		BattleEngineScript.State.TURN_START:
			state_name = "回合开始"
		BattleEngineScript.State.TURN_END:
			state_name = "回合结束"
		BattleEngineScript.State.BATTLE_END:
			state_name = "战斗结束"
		_:
			state_name = "战斗准备"
	return state_name


func _is_player_turn() -> bool:
	return (
		engine != null
		and engine.current_state == BattleEngineScript.State.PLAYER_TURN
	)


func _command_tooltip(actor: BattleUnit, command: BattleCommand) -> String:
	if command == null:
		return ""
	var tooltip := command.description
	if not command.disabled_reason.is_empty():
		tooltip += "\n不可用：" + command.disabled_reason
	elif command.uses_action and actor != null and actor.at <= 0:
		tooltip += (
			"\n不可用："
			+ BattleAttribute.label(BattleAttribute.Type.AT)
			+ "不足"
		)
	return tooltip


func _is_command_available_for_actor(actor: BattleUnit, command: BattleCommand) -> bool:
	if actor == null or command == null or not command.available:
		return false
	if command.uses_action and actor.at <= 0:
		return false
	return true


# --------------------------------------------------------------------------
# 样式工具
# --------------------------------------------------------------------------


## HUD 尺寸缩放。
func _s(value: float) -> float:
	return value * UI_SCALE


## HUD 尺寸缩放（向量）。
func _sv(value: Vector2) -> Vector2:
	return value * UI_SCALE


## 字号缩放，保证缩小后仍不小于 10px。
func _fs(base: float) -> int:
	return maxi(10, int(round(base * UI_SCALE)))


func _health_color(ratio: float) -> Color:
	if ratio > 0.55:
		return HEALTH_HIGH
	if ratio > 0.25:
		return HEALTH_MEDIUM
	return HEALTH_LOW


func _ellipse_points(
	center: Vector2,
	radius: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(
			center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		)
	return points


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE_FILL_SOFT
	style.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(maxi(2, int(round(6.0 * UI_SCALE))))
	style.content_margin_left = _s(14.0)
	style.content_margin_right = _s(14.0)
	style.content_margin_top = _s(12.0)
	style.content_margin_bottom = _s(12.0)
	return style


func _flat_style(
	color: Color,
	border_color: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(maxi(2, int(round(float(radius) * UI_SCALE))))
	style.content_margin_left = _s(8.0)
	style.content_margin_right = _s(8.0)
	style.content_margin_top = _s(5.0)
	style.content_margin_bottom = _s(5.0)
	return style


func _command_style(
	color: Color,
	accent: Color,
	border_alpha: float
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	style.border_width_left = maxi(2, int(round(4.0 * UI_SCALE)))
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(maxi(2, int(round(4.0 * UI_SCALE))))
	style.content_margin_left = _s(14.0)
	style.content_margin_right = _s(12.0)
	style.content_margin_top = _s(8.0)
	style.content_margin_bottom = _s(8.0)
	return style


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_command_style(
			Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.2, 0.95),
			accent,
			0.55
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_command_style(
			Color(accent.r * 0.32, accent.g * 0.32, accent.b * 0.36, 0.98),
			accent,
			0.9
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_command_style(
			Color(accent.r * 0.46, accent.g * 0.46, accent.b * 0.52, 1.0),
			accent.lightened(0.15),
			1.0
		)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_command_style(
			Color(0.06, 0.07, 0.09, 0.8),
			Color(0.3, 0.34, 0.38, 0.5),
			0.4
		)
	)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.48, 0.52))
	button.add_theme_font_size_override("font_size", _fs(16))
