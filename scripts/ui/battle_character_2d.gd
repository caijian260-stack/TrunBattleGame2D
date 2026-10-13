class_name BattleCharacter2D
extends RefCounted

## 2D 战斗角色视觉父类。
##
## 本类只负责表现，不参与战斗规则。所有具体角色外观都应继承本类，并覆写
## _draw_body() 与 _draw_weapon()；公共的待机动画、阴影、选中光环和死亡姿态
## 由父类统一处理。

enum AnimationState {
	IDLE,
	DEFEATED,
}

const SHADOW_RADIUS := Vector2(78.0, 22.0)
const RING_RADIUS := Vector2(66.0, 18.0)
const ACTIVE_RING_RADIUS := Vector2(80.0, 23.0)
const IDLE_BOB_AMPLITUDE := 3.0
const IDLE_BOB_SPEED := 2.4
const IDLE_BREATH_AMPLITUDE := 0.012
const RING_PULSE_SPEED := 4.0
const IDLE_ENTER_ANIMATION_NAME := &"idle_01"
const IDLE_LOOP_ANIMATION_NAME := &"idle_02"
const IDLE_LEGACY_ANIMATION_NAME := &"idle_left"

var unit: BattleUnit = null
var accent := Color.WHITE
var is_player := false
var display_scale := 1.0

## 当前动画状态。后续新增攻击、受击等状态时只需扩展 AnimationState。
var animation_state := AnimationState.IDLE
## 从本视觉对象创建开始累计的动画时间。
var animation_time := 0.0

## 可选贴图外观。为空时由子类绘制程序化角色。
var appearance_texture: Texture2D = null
## 贴图以脚底中心为原点，尺寸和偏移均使用角色局部坐标。
var appearance_size := Vector2(112.0, 194.0)
var appearance_offset := Vector2.ZERO
var appearance_modulate := Color.WHITE
## 角色自己的待机 SpriteFrames。设置后待机姿态优先播放真实精灵帧，
## 未设置时才回退到父类程序化浮动/呼吸动画。
var idle_frames: SpriteFrames = null
## 查看器可把待机固定到指定剪片；为空时按 idle_01 → idle_02 自动切换。
var idle_animation_override: StringName = &""
## 待机 02 截取 01 末尾的持续时长（秒）。
var idle_loop_seconds := 0.5

var _state_elapsed := 0.0


func setup(
	p_unit: BattleUnit,
	p_accent: Color,
	p_is_player: bool
) -> void:
	unit = p_unit
	accent = p_accent
	is_player = p_is_player
	animation_time = _initial_animation_phase()
	animation_state = AnimationState.IDLE
	_state_elapsed = 0.0


## 每帧推进当前动画。BattleScene2D 会统一调用所有角色视觉对象。
func update(delta: float) -> void:
	if unit == null:
		return

	animation_time += delta
	_state_elapsed += delta

	if not is_alive():
		play_animation(AnimationState.DEFEATED)
	elif animation_state == AnimationState.DEFEATED:
		play_idle()


## 切换动画状态。相同状态不会重复重置计时。
func play_animation(state: int) -> void:
	if animation_state == state:
		return
	animation_state = state
	_state_elapsed = 0.0


## 播放待机动画。后续其他角色动画应以同样方式提供公开入口。
func play_idle() -> void:
	play_animation(AnimationState.IDLE)


## 返回当前应播放的待机剪片名。
func get_idle_animation_name() -> StringName:
	if idle_frames == null:
		return &""
	if (
		idle_animation_override != &""
		and idle_frames.has_animation(idle_animation_override)
	):
		return idle_animation_override
	if idle_frames.has_animation(IDLE_LOOP_ANIMATION_NAME):
		var enter_duration := _idle_enter_duration()
		if (
			enter_duration > 0.0
			and idle_frames.has_animation(IDLE_ENTER_ANIMATION_NAME)
			and _state_elapsed < enter_duration
		):
			return IDLE_ENTER_ANIMATION_NAME
		return IDLE_LOOP_ANIMATION_NAME
	if idle_frames.has_animation(IDLE_ENTER_ANIMATION_NAME):
		return IDLE_ENTER_ANIMATION_NAME
	if idle_frames.has_animation(IDLE_LEGACY_ANIMATION_NAME):
		return IDLE_LEGACY_ANIMATION_NAME
	return &""


## 查看器预览用：固定播放 01 或 02，并从头开始。
func set_idle_animation_preview(animation_name: StringName) -> void:
	idle_animation_override = animation_name
	_state_elapsed = 0.0


## 从 idle_01 末尾重新生成 idle_02，不修改 idle_01 本身。
func set_idle_loop_seconds(seconds: float) -> void:
	idle_loop_seconds = maxf(seconds, 0.0)
	if idle_frames == null:
		return
	if not idle_frames.has_animation(IDLE_ENTER_ANIMATION_NAME):
		return
	var source_count := idle_frames.get_frame_count(IDLE_ENTER_ANIMATION_NAME)
	if source_count <= 0:
		return
	var speed := idle_frames.get_animation_speed(IDLE_ENTER_ANIMATION_NAME)
	if speed <= 0.0:
		speed = 12.0
	var tail_frames := clampi(
		int(roundf(idle_loop_seconds * speed)),
		1,
		source_count
	)
	if not idle_frames.has_animation(IDLE_LOOP_ANIMATION_NAME):
		idle_frames.add_animation(IDLE_LOOP_ANIMATION_NAME)
	while idle_frames.get_frame_count(IDLE_LOOP_ANIMATION_NAME) > 0:
		idle_frames.remove_frame(IDLE_LOOP_ANIMATION_NAME, 0)
	idle_frames.set_animation_speed(IDLE_LOOP_ANIMATION_NAME, speed)
	idle_frames.set_animation_loop(IDLE_LOOP_ANIMATION_NAME, true)
	var last_index := source_count - 1
	var first_index := last_index - tail_frames + 1
	for index in range(first_index, last_index + 1):
		var texture := idle_frames.get_frame_texture(
			IDLE_ENTER_ANIMATION_NAME,
			index
		)
		if texture != null:
			idle_frames.add_frame(IDLE_LOOP_ANIMATION_NAME, texture)
	for index in range(last_index - 1, first_index - 1, -1):
		var texture := idle_frames.get_frame_texture(
			IDLE_ENTER_ANIMATION_NAME,
			index
		)
		if texture != null:
			idle_frames.add_frame(IDLE_LOOP_ANIMATION_NAME, texture)


func is_alive() -> bool:
	return unit != null and unit.hp > 0


## 返回当前外观的素材像素尺寸（源尺寸），程序化外观返回其名义尺寸。
func get_appearance_pixel_size() -> Vector2:
	return appearance_size


## 返回当前外观在战场上的实际像素尺寸。
func get_display_size() -> Vector2:
	return appearance_size * display_scale


## 使用指定贴图替换本角色外观。贴图默认以脚底中心对齐角色原点。
func set_appearance_texture(
	texture: Texture2D,
	size: Vector2,
	offset := Vector2.ZERO,
	modulate := Color.WHITE
) -> void:
	appearance_texture = texture
	appearance_size = size
	appearance_offset = offset
	appearance_modulate = modulate


## 在 BattleScene2D._draw() 中绘制角色。
func draw(canvas: CanvasItem, origin: Vector2, active: bool) -> void:
	if unit == null:
		return

	canvas.draw_set_transform(
		origin,
		0.0,
		Vector2(display_scale, display_scale)
	)
	_draw_stage(canvas, active and is_alive())

	if is_alive():
		_draw_idle_pose(canvas, origin)
	else:
		canvas.draw_set_transform(
			origin,
			0.0,
			Vector2(display_scale, display_scale)
		)
		_draw_defeated_body(canvas)

	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 待机动画只改变角色本体，不影响地面阴影和选中光环。
func _draw_idle_pose(canvas: CanvasItem, origin: Vector2) -> void:
	var idle_animation_name := get_idle_animation_name()
	var using_idle_frames := (
		idle_frames != null
		and idle_animation_name != &""
		and idle_frames.has_animation(idle_animation_name)
		and idle_frames.get_frame_count(idle_animation_name) > 0
	)
	var idle_wave := sin(animation_time * IDLE_BOB_SPEED)
	if using_idle_frames:
		var frame_index := get_idle_frame_index()
		var frame_texture := idle_frames.get_frame_texture(
			idle_animation_name,
			frame_index
		)
		if frame_texture != null:
			appearance_texture = frame_texture
			appearance_size = Vector2(
				frame_texture.get_width(),
				frame_texture.get_height()
			)
		canvas.draw_set_transform(
			origin,
			0.0,
			Vector2(display_scale, display_scale)
		)
	else:
		var bob := idle_wave * IDLE_BOB_AMPLITUDE
		var breath_scale := 1.0 + idle_wave * IDLE_BREATH_AMPLITUDE
		var final_scale := Vector2(
			display_scale * breath_scale,
			display_scale * breath_scale
		)

		canvas.draw_set_transform(
			origin + Vector2(0.0, bob * display_scale),
			0.0,
			final_scale
		)
	if appearance_texture != null:
		_draw_appearance_texture(canvas)
	else:
		_draw_body(canvas)
		_draw_weapon(canvas)


## 返回当前待机剪片应显示的帧序号。预览固定到 idle_01 时按整段循环，
## 战斗自动过渡阶段仍停在末帧等待切到 idle_02。
func get_idle_frame_index() -> int:
	var animation_name := get_idle_animation_name()
	if (
		idle_frames == null
		or animation_name == &""
		or not idle_frames.has_animation(animation_name)
	):
		return 0
	var frame_count := idle_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return 0
	var frame_speed := idle_frames.get_animation_speed(animation_name)
	var frame_index := wrapi(
		int(floor(_idle_local_time(animation_name) * frame_speed)),
		0,
		frame_count
	)
	if (
		animation_name == IDLE_ENTER_ANIMATION_NAME
		and idle_animation_override != animation_name
	):
		frame_index = clampi(
			int(floor(_idle_local_time(animation_name) * frame_speed)),
			0,
			frame_count - 1
		)
	return frame_index


func _idle_enter_duration() -> float:
	if (
		idle_frames == null
		or not idle_frames.has_animation(IDLE_ENTER_ANIMATION_NAME)
	):
		return 0.0
	var speed := idle_frames.get_animation_speed(IDLE_ENTER_ANIMATION_NAME)
	if speed <= 0.0:
		return 0.0
	return float(idle_frames.get_frame_count(IDLE_ENTER_ANIMATION_NAME)) / speed


func _idle_local_time(animation_name: StringName) -> float:
	if idle_animation_override == animation_name:
		return _state_elapsed
	if animation_name == IDLE_LOOP_ANIMATION_NAME:
		return maxf(_state_elapsed - _idle_enter_duration(), 0.0)
	return _state_elapsed


func _draw_appearance_texture(canvas: CanvasItem) -> void:
	var rect := Rect2(
		appearance_offset - Vector2(appearance_size.x * 0.5, appearance_size.y),
		appearance_size
	)
	canvas.draw_texture_rect(
		appearance_texture,
		rect,
		false,
		appearance_modulate
	)


func _draw_stage(canvas: CanvasItem, active: bool) -> void:
	var shadow := _ellipse_points(Vector2.ZERO, SHADOW_RADIUS, 40)
	canvas.draw_colored_polygon(shadow, Color(0.015, 0.03, 0.045, 0.45))

	var ring := _ellipse_points(Vector2.ZERO, RING_RADIUS, 40)
	ring.append(ring[0])
	canvas.draw_polyline(
		ring,
		Color(accent.r, accent.g, accent.b, 0.75 if active else 0.3),
		2.6 if active else 1.6,
		true
	)

	if active:
		var pulse := 1.0 + 0.06 * sin(animation_time * RING_PULSE_SPEED)
		var outer := _ellipse_points(
			Vector2.ZERO,
			ACTIVE_RING_RADIUS * pulse,
			40
		)
		outer.append(outer[0])
		canvas.draw_polyline(
			outer,
			Color(accent.r, accent.g, accent.b, 0.45),
			2.0,
			true
		)


func _draw_defeated_body(canvas: CanvasItem) -> void:
	var body := Color(0.16, 0.18, 0.22, 0.9)
	canvas.draw_rect(
		Rect2(Vector2(-56.0, -32.0), Vector2(112.0, 22.0)),
		body
	)
	canvas.draw_circle(Vector2(-66.0, -22.0), 15.0, body)
	canvas.draw_line(
		Vector2(-96.0, -36.0),
		Vector2(-46.0, -20.0),
		accent.darkened(0.45),
		5.0,
		true
	)


## 子类覆写：绘制角色身体。
func _draw_body(_canvas: CanvasItem) -> void:
	pass


## 子类覆写：绘制角色武器。
func _draw_weapon(_canvas: CanvasItem) -> void:
	pass


func _initial_animation_phase() -> float:
	if unit == null:
		return 0.0
	return float(absi(unit.unit_name.hash()) % 100) * 0.05


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
