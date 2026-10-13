extends SceneTree

## 无界面自动化测试：验证角色素材查看器能加载立绘、当前角色真实待机
## SpriteFrames 与行走动画，并能驱动 LxqBattleCharacter2D 动画预览。

const CharacterViewer2DScript := preload(
	"res://scripts/ui/character_viewer_2d.gd"
)
const CharacterRegistryScript := preload(
	"res://scripts/core/character_registry.gd"
)
const IDLE_FRAMES := preload(
	"res://assets/characters/lxq/animation/idle/animation.tres"
)
const WALK_FRAMES_PACKED := preload(
	"res://assets/characters/lxq/animation/walk/full/animation.tres"
)
const WALK_FRAMES_LIGHT := preload(
	"res://assets/characters/lxq/animation/walk/light/animation.tres"
)
const PORTRAIT_PATHS := [
	"res://assets/characters/lxq/portrait.png",
	"res://assets/characters/lxq/left.png",
	"res://assets/characters/lxq/right.png",
	"res://assets/characters/lxq/front.png",
	"res://assets/characters/lxq/back.png",
]
const LxqBattleCharacter2DScript := preload(
	"res://scripts/ui/lxq_battle_character_2d.gd"
)
const BattleUnitScript := preload("res://scripts/core/battle_unit.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_character_layout()
	_test_idle_frames()
	_test_idle_auto_transition()
	_test_walk_frames()
	_test_portrait_paths()
	await _test_viewer()

	if failures == 0:
		print("CHARACTER VIEWER TESTS PASSED")
		quit(0)
	else:
		print("CHARACTER VIEWER TESTS FAILED: %d" % failures)
		quit(1)


func _test_character_layout() -> void:
	var lxq_dir := DirAccess.open("res://assets/characters/lxq")
	_check(
		lxq_dir != null,
		"角色素材目录 assets/characters/lxq 应存在"
	)
	if lxq_dir == null:
		return
	_check(
		lxq_dir.file_exists("portrait.png"),
		"角色目录应包含立绘 portrait.png"
	)
	_check(
		lxq_dir.file_exists("left.png"),
		"角色目录应包含左视图 left.png"
	)
	_check(
		lxq_dir.file_exists("right.png"),
		"角色目录应包含右视图 right.png"
	)
	_check(
		lxq_dir.file_exists("front.png"),
		"角色目录应包含正视图 front.png"
	)
	_check(
		lxq_dir.dir_exists("animation/idle"),
		"动画目录应包含待机 idle 文件夹"
	)
	_check(
		lxq_dir.dir_exists("animation/walk"),
		"动画目录应包含行走 walk 文件夹"
	)


func _test_idle_frames() -> void:
	_check(
		IDLE_FRAMES is SpriteFrames,
		"lxq 待机 SpriteFrames 资源应加载为 SpriteFrames"
	)
	if not (IDLE_FRAMES is SpriteFrames):
		return
	var idle: SpriteFrames = IDLE_FRAMES
	_check(
		idle.has_animation(&"idle_01") and idle.has_animation(&"idle_02"),
		"待机资源应同时包含 idle_01 与 idle_02"
	)
	_check(
		idle.get_frame_count(&"idle_01") == 45,
		"待机 01 应为从站立转入待机的 45 帧动画"
	)
	var loop_count := idle.get_frame_count(&"idle_02")
	var tail_frames := (loop_count + 1) >> 1
	_check(
		loop_count > 0 and loop_count % 2 == 1
		and tail_frames <= idle.get_frame_count(&"idle_01"),
		"待机 02 应按 x → 末帧 → 回到 x 生成奇数帧对称循环"
	)
	_check(
		not idle.get_animation_loop(&"idle_01"),
		"待机 01 应为不循环的转入动画"
	)
	_check(
		idle.get_animation_loop(&"idle_02"),
		"待机 02 应为持续循环动画"
	)
	_check(
		is_equal_approx(idle.get_animation_speed(&"idle_01"), 12.0)
		and is_equal_approx(idle.get_animation_speed(&"idle_02"), 12.0),
		"待机 01/02 应保持 12 fps"
	)
	var expected_sources := PackedInt32Array()
	for index in range(tail_frames):
		expected_sources.append(45 - tail_frames + index)
	for index in range(tail_frames - 1, 0, -1):
		expected_sources.append(45 - tail_frames + index - 1)
	for index in expected_sources.size():
		_check(
			idle.get_frame_texture(&"idle_01", expected_sources[index]) != null
			and idle.get_frame_texture(&"idle_02", index) != null
			and idle.get_frame_texture(&"idle_02", index) == idle.get_frame_texture(
				&"idle_01",
				expected_sources[index]
			),
			"待机 02 第 %d 帧应复用 01 第 %d 帧贴图" % [
				index + 1,
				expected_sources[index] + 1,
			]
		)


func _test_idle_auto_transition() -> void:
	var unit = BattleUnitScript.new()
	unit.unit_name = "待机过渡测试"
	unit.max_hp = 100
	unit.hp = 100
	var visual = LxqBattleCharacter2DScript.new()
	visual.setup(unit, Color.WHITE, true)
	_check(
		visual.idle_frames == IDLE_FRAMES,
		"LxqBattleCharacter2D 应挂载 lxq 自己的待机 SpriteFrames"
	)
	_check(
		visual.get_idle_animation_name() == &"idle_01",
		"战斗待机开始时应先播放 idle_01 转入动画"
	)
	visual.update(3.7)
	_check(
		visual.get_idle_animation_name() == &"idle_01",
		"3.75 秒前应仍处于 idle_01 转入剪片"
	)
	visual.update(0.1)
	_check(
		visual.get_idle_animation_name() == &"idle_02",
		"idle_01 播放完后应自动切到 idle_02 持续循环"
	)
	visual.update(2.0)
	_check(
		visual.get_idle_animation_name() == &"idle_02",
		"进入 idle_02 后应保持持续循环剪片"
	)


func _test_walk_frames() -> void:
	_check(
		WALK_FRAMES_PACKED is SpriteFrames,
		"39 帧行走动画资源应加载为 SpriteFrames"
	)
	_check(
		WALK_FRAMES_LIGHT is SpriteFrames,
		"16 帧行走动画资源应加载为 SpriteFrames"
	)
	if WALK_FRAMES_PACKED is SpriteFrames:
		var packed: SpriteFrames = WALK_FRAMES_PACKED
		_check(
			packed.has_animation(&"walk_left"),
			"39 帧资源应包含 walk_left 动画"
		)
		_check(
			packed.get_frame_count(&"walk_left") == 39,
			"完整行走动画应为 39 帧"
		)
		_check(
			packed.get_frame_texture(&"walk_left", 0) != null,
			"完整行走动画首帧应加载到贴图"
		)
	if WALK_FRAMES_LIGHT is SpriteFrames:
		var light: SpriteFrames = WALK_FRAMES_LIGHT
		_check(
			light.has_animation(&"walk_left"),
			"16 帧资源应包含 walk_left 动画"
		)
		_check(
			light.get_frame_count(&"walk_left") == 16,
			"轻量行走动画应为 16 帧"
		)
		_check(
			light.get_frame_texture(&"walk_left", 0) != null,
			"轻量行走动画首帧应加载到贴图"
		)


func _test_portrait_paths() -> void:
	var all_loaded := true
	for path in PORTRAIT_PATHS:
		if not load(path) is Texture2D:
			all_loaded = false
			printerr("FAIL: 立绘无法加载: " + path)
	_check(all_loaded, "五张 lxq 立绘/视图像素图都应加载为 Texture2D")


func _test_viewer() -> void:
	var viewer := CharacterViewer2DScript.new()
	root.size = Vector2i(1152, 648)
	root.add_child(viewer)
	await process_frame
	await process_frame

	_check(viewer is Control, "查看器根节点应为 Control")
	_check(
		viewer._idle_controls != null and viewer._idle_controls.visible,
		"待机控制区应默认可见"
	)
	_check(
		viewer._save_idle_button != null
		and viewer._save_idle_button.visible
		and not viewer._save_idle_button.disabled,
		"记录 02 保存按钮应显示且可用"
	)
	if viewer._save_idle_button != null:
		var viewport_rect: Rect2 = root.get_visible_rect()
		var save_rect: Rect2 = viewer._save_idle_button.get_global_rect()
		_check(
			save_rect.end.y <= viewport_rect.end.y + 1.0,
			"记录 02 按钮应保持在查看器视口内"
		)
	_check(
		viewer.portrait_view != null and viewer.portrait_view.texture != null,
		"查看器启动后应默认显示第一张立绘"
	)
	_check(
		viewer.idle_stage != null and viewer.idle_stage.is_ready(),
		"查看器应初始化角色待机预览"
	)
	if viewer.idle_stage != null and viewer.idle_stage.size.y > 0.0:
		var origin_ratio: float = (
			viewer.idle_stage.get_visual_origin().y
			/ viewer.idle_stage.size.y
		)
		_check(
			origin_ratio >= 2.0 / 3.0 and origin_ratio <= 0.85,
			"待机落脚点/圆圈应位于舞台下方 1/3 处"
		)
	_check(
		viewer._character_option != null
		and viewer._character_option.item_count
		== CharacterRegistryScript.CHARACTERS.size(),
		"角色下拉列表应包含注册表全部角色"
	)
	if viewer._character_option != null:
		for index in CharacterRegistryScript.CHARACTERS.size():
			var entry: Dictionary = CharacterRegistryScript.CHARACTERS[index]
			_check(
				viewer._character_option.get_item_text(index) == entry["label"]
				and viewer._character_option.get_item_id(index) == entry["id"],
				"下拉列表第 %d 项应为 %s" % [index + 1, entry["label"]]
			)
	_check(
		viewer._character_status != null
		and viewer._character_status.text.contains("资源已加载"),
		"lxq 角色素材完整时状态应显示已加载"
	)
	_check(
		viewer._character_doc_label != null
		and not viewer._character_doc_label.text.contains("不存在"),
		"lxq 应加载角色文档 README.md"
	)
	var idle_visual = viewer.idle_stage.get_visual()
	_check(
		idle_visual != null
		and idle_visual.get_script() == LxqBattleCharacter2DScript,
		"查看器待机预览应实例化 LxqBattleCharacter2D 子类"
	)
	_check(
		idle_visual != null and idle_visual.appearance_texture != null,
		"LxqBattleCharacter2D 应加载角色贴图外观"
	)
	_check(
		idle_visual != null and idle_visual.idle_frames == IDLE_FRAMES,
		"LxqBattleCharacter2D 应挂载 lxq 自己的待机动画"
	)
	_check(
		viewer._portraits.size() == CharacterRegistryScript.PORTRAIT_FILES.size(),
		"lxq 应加载全部 5 张立绘/视图"
	)
	if idle_visual != null and idle_visual.idle_frames != null:
		viewer.set_idle_loop_seconds(1.0)
		_check(
			idle_visual.idle_frames.get_frame_count(&"idle_02") == 23,
			"02 截取时长调为 1.0 秒后应生成 23 帧对称循环"
		)
		viewer.set_idle_loop_seconds(0.5)
		_check(
			idle_visual.idle_frames.get_frame_count(&"idle_02") == 11,
			"02 截取时长调回 0.5 秒后应恢复 11 帧对称循环"
		)
	_check(
		viewer.select_portrait(1) and viewer.portrait_view.texture != null,
		"选择第二张立绘后应更新贴图"
	)

	var player_id := CharacterRegistryScript.CharacterId.PLAYER
	_check(
		viewer.select_character(player_id),
		"应能切换到注册表中的 player 角色"
	)
	_check(
		viewer._character_status != null
		and viewer._character_status.text.contains("不存在"),
		"player 无素材时状态应显示资源不存在"
	)
	_check(
		viewer._character_doc_label != null
		and viewer._character_doc_label.text.contains("不存在"),
		"player 缺少 README 时应提示角色文档不存在"
	)
	_check(
		viewer.portrait_view.texture == null
		and viewer._portrait_caption.text.contains("不存在"),
		"player 缺少立绘时应清空预览并提示立绘不存在"
	)
	_check(
		viewer._portraits.is_empty() and viewer._walk_sources.is_empty(),
		"player 缺少立绘和行走动画时列表应为空"
	)
	_check(
		viewer.animation_sprite.sprite_frames == null,
		"player 缺少待机/行走动画时不应用 SpriteFrames"
	)
	var player_visual = viewer.idle_stage.get_visual()
	_check(
		player_visual != null
		and player_visual.get_script()
		== preload("res://scripts/ui/asset_battle_character_2d.gd"),
		"player 应使用通用 AssetBattleCharacter2D 子类"
	)
	_check(
		player_visual == null or player_visual.idle_frames == null,
		"player 缺少待机动画时 idle_frames 应为空"
	)
	_check(
		viewer.select_character(CharacterRegistryScript.CharacterId.LXQ),
		"切换回 lxq 后应恢复素材预览"
	)
	_check(
		viewer._character_status != null
		and viewer._character_status.text.contains("资源已加载"),
		"切回 lxq 后状态应恢复为资源已加载"
	)
	_check(
		viewer.portrait_view.texture != null,
		"切回 lxq 后应恢复立绘预览"
	)
	idle_visual = viewer.idle_stage.get_visual()
	_check(
		idle_visual != null
		and idle_visual.get_script() == LxqBattleCharacter2DScript
		and idle_visual.idle_frames == IDLE_FRAMES,
		"切回 lxq 后应重建 LxqBattleCharacter2D 待机预览"
	)

	viewer.select_view(CharacterViewer2DScript.VIEW_WALK)
	_check(
		viewer.animation_sprite != null and viewer.animation_sprite.is_playing(),
		"切换到行走动画后应自动播放"
	)
	_check(
		viewer.animation_sprite.sprite_frames.get_frame_count(&"walk_left")
		== 39,
		"行走动画默认应使用 39 帧资源"
	)

	viewer._stage_control.size = Vector2(960, 620)
	await process_frame
	var walk_scale := viewer.animation_sprite.scale.x
	_check(
		walk_scale <= CharacterViewer2DScript.WALK_SCALE_MAX + 0.001,
		"行走动画在小舞台中不应超过最大缩放 %.2f" % (
			CharacterViewer2DScript.WALK_SCALE_MAX
		)
	)
	var walk_texture := viewer.animation_sprite.sprite_frames.get_frame_texture(
		viewer.animation_sprite.animation,
		viewer.animation_sprite.frame
	)
	if walk_texture != null:
		var displayed_height := walk_texture.get_height() * viewer.animation_sprite.scale.y
		_check(
			displayed_height <= viewer._stage_control.size.y * 0.9 + 0.5,
			"行走动画显示尺寸不应超出舞台可用高度"
		)

	_check(
		viewer.select_walk_source(1),
		"切换动画源应返回成功"
	)
	_check(
		viewer.animation_sprite.sprite_frames == WALK_FRAMES_LIGHT,
		"切换后应使用 16 帧行走动画资源"
	)
	_check(
		viewer.animation_sprite.sprite_frames.get_frame_count(&"walk_left")
		== 16,
		"切换后动画帧数应为 16"
	)

	viewer.set_walk_flipped(true)
	_check(viewer.animation_sprite.flip_h, "水平翻转应作用于行走动画")
	viewer.set_walk_speed(1.5)
	_check(
		is_equal_approx(viewer.animation_sprite.speed_scale, 1.5),
		"播放速度应可设置为 1.5 倍"
	)

	var initial_frame: int = viewer.animation_sprite.frame
	for _index in range(15):
		await process_frame
	_check(
		viewer.animation_sprite.frame > initial_frame,
		"行走动画应随时间推进帧"
	)

	viewer.toggle_playback()
	_check(not viewer.animation_sprite.is_playing(), "暂停后行走动画应停止播放")
	viewer.toggle_playback()
	_check(viewer.animation_sprite.is_playing(), "再次切换后应恢复播放")

	viewer.select_view(CharacterViewer2DScript.VIEW_IDLE)
	_check(
		viewer.select_idle_source(0),
		"查看器应能选择待机 01"
	)
	if idle_visual != null:
		_check(
			idle_visual.get_idle_animation_name() == &"idle_01",
			"选择待机 01 后预览应固定播放 idle_01"
		)
		idle_visual.update(4.0)
		_check(
			idle_visual.get_idle_frame_index() < IDLE_FRAMES.get_frame_count(
				&"idle_01"
			) - 1,
			"待机 01 预览超过时长后应回到开头循环播放"
		)
	_check(
		viewer.select_idle_source(1),
		"查看器应能切回待机 02"
	)
	if idle_visual != null:
		_check(
			idle_visual.get_idle_animation_name() == &"idle_02",
			"切回待机 02 后预览应固定播放 idle_02"
		)
	if idle_visual != null:
		var initial_time: float = idle_visual.animation_time
		for _index in range(6):
			await process_frame
		_check(
			idle_visual.animation_time > initial_time,
			"角色待机预览应逐帧推进动画时间"
		)

	viewer.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
