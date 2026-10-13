extends SceneTree

## 无界面自动化测试：验证战斗场景内的玩家外观测试面板。
##
## 覆盖下拉列表内容、下拉选择触发的玩家外观替换，以及替换后自动载入
## 所选角色的待机动画（idle_01 转入 → idle_02 循环）。

const BattleScene2DScript := preload("res://scripts/ui/battle_2d_scene.gd")
const CharacterRegistryScript := preload(
	"res://scripts/core/character_registry.gd"
)
const AssetBattleCharacter2DScript := preload(
	"res://scripts/ui/asset_battle_character_2d.gd"
)
const PlayerBattleCharacter2DScript := preload(
	"res://scripts/ui/player_battle_character_2d.gd"
)

const PLAYER_ACCENT := Color(0.24, 0.75, 0.98)

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_appearance_switcher()

	if failures == 0:
		print("BATTLE APPEARANCE TESTS PASSED")
		quit(0)
	else:
		print("BATTLE APPEARANCE TESTS FAILED: %d" % failures)
		quit(1)


func _test_appearance_switcher() -> void:
	var scene := BattleScene2DScript.new()
	root.size = Vector2i(1600, 900)
	root.add_child(scene)
	await process_frame
	await process_frame

	var switcher: PlayerAppearanceSwitcher = scene._appearance_switcher
	_check(switcher != null, "战斗场景应包含玩家外观测试面板")
	if switcher == null:
		scene.queue_free()
		await process_frame
		return

	var option := switcher.get_option_button()
	_check(option != null, "外观面板应提供下拉列表")
	if option == null:
		scene.queue_free()
		await process_frame
		return

	_check(
		option.item_count == CharacterRegistryScript.CHARACTERS.size() + 1,
		"下拉列表应为默认外观加注册表角色"
	)
	_check(
		switcher.get_selected_appearance_id() == -1,
		"下拉列表默认应选中程序化默认外观"
	)
	for index in CharacterRegistryScript.CHARACTERS.size():
		var character_id: int = CharacterRegistryScript.CHARACTERS[index]["id"]
		var item_index: int = switcher.find_option_index(character_id)
		_check(item_index >= 0, "下拉列表应包含注册角色 %d" % character_id)
		if item_index < 0:
			continue
		_check(
			switcher.get_option_character_id(item_index) == character_id,
			"下拉列表第 %d 项应绑定角色 %d" % [item_index, character_id]
		)
		_check(
			option.is_item_disabled(item_index)
			== not CharacterRegistryScript.asset_exists(
				character_id,
				CharacterRegistryScript.IDLE_ANIMATION_FILE
			),
			"缺少待机素材的角色应禁用，否则可选"
		)

	_check(
		scene.get_player_appearance_id() == -1,
		"战斗开始时玩家应使用默认外观"
	)
	var default_visual = scene._get_character_visual(
		scene.player_unit,
		PLAYER_ACCENT,
		true
	)
	_check(
		default_visual is PlayerBattleCharacter2DScript,
		"默认玩家外观应为 PlayerBattleCharacter2D"
	)

	_test_invalid_character(scene)
	await _test_switch_via_dropdown(scene, switcher, option)
	await _test_appearance_size(scene, switcher)

	scene.queue_free()
	await process_frame


func _test_invalid_character(scene: BattleScene2D) -> void:
	_check(
		not scene.set_player_appearance(4096),
		"未登记的角色 id 应被外观切换拒绝"
	)
	_check(
		scene.get_player_appearance_id() == -1,
		"被拒绝的切换不应改变当前外观"
	)


func _test_switch_via_dropdown(
	scene: BattleScene2D,
	switcher: PlayerAppearanceSwitcher,
	option: OptionButton
) -> void:
	var character_id: int = CharacterRegistryScript.CharacterId.LXQ
	var item_index: int = switcher.find_option_index(character_id)
	_check(item_index > 0, "下拉列表应提供 lxq 外观")
	if item_index <= 0:
		return
	if option.is_item_disabled(item_index):
		_check(false, "lxq 待机素材应存在且可选")
		return

	option.select(item_index)
	option.item_selected.emit(item_index)
	await process_frame

	_check(
		scene.get_player_appearance_id() == character_id,
		"选择下拉项后应切换到对应角色外观"
	)
	var asset_visual := scene._get_character_visual(
		scene.player_unit,
		PLAYER_ACCENT,
		true
	) as AssetBattleCharacter2D
	_check(asset_visual != null, "替换后的玩家外观应由角色素材驱动")
	if asset_visual == null:
		return
	_check(
		asset_visual.character_id == character_id,
		"替换后的外观应绑定所选角色 id"
	)
	_check(
		asset_visual.idle_frames != null
		and asset_visual.idle_frames.has_animation(&"idle_01"),
		"替换外观后应自动加载所选角色的待机动画"
	)
	if asset_visual.idle_frames == null:
		return

	asset_visual.update(0.1)
	_check(
		asset_visual.get_idle_animation_name() == &"idle_01",
		"待机动画应从头播放 idle_01"
	)
	asset_visual.update(4.0)
	_check(
		asset_visual.get_idle_animation_name() == &"idle_02",
		"idle_01 转入结束后应自动循环 idle_02"
	)

	option.select(0)
	option.item_selected.emit(0)
	await process_frame
	_check(
		scene.get_player_appearance_id() == -1,
		"选择默认外观应恢复程序化外观"
	)
	var restored = scene._get_character_visual(
		scene.player_unit,
		PLAYER_ACCENT,
		true
	)
	_check(
		restored is PlayerBattleCharacter2DScript,
		"恢复默认外观后应重新使用 PlayerBattleCharacter2D"
	)


func _test_appearance_size(
	scene: BattleScene2D,
	switcher: PlayerAppearanceSwitcher
) -> void:
	scene.set_player_appearance(CharacterRegistryScript.CharacterId.LXQ)
	await process_frame

	var input: SpinBox = switcher._size_input
	_check(input != null, "外观面板应提供尺寸输入框")
	if input == null:
		return
	var size_label: Label = switcher._size_label
	_check(size_label != null, "外观面板应提供尺寸显示")
	if size_label != null:
		_check(
			size_label.text.contains("源") and size_label.text.contains("→"),
			"尺寸显示应同时给出源尺寸与显示尺寸"
		)

	var target := 320.0
	input.value = target
	await process_frame
	_check(
		is_equal_approx(scene.get_player_appearance_height(), target),
		"输入尺寸后战斗场景应记录新的显示高度"
	)
	var visual := scene._get_character_visual(
		scene.player_unit,
		PLAYER_ACCENT,
		true
	)
	_check(
		absf(visual.get_display_size().y - target) <= 1.0,
		"输入尺寸后玩家外观的显示高度应等于输入值"
	)
	if size_label != null:
		_check(
			size_label.text.contains(str(int(target))),
			"尺寸显示应随输入同步更新"
		)
	_check(
		is_equal_approx(input.value, target),
		"尺寸输入框应与当前显示高度保持一致"
	)

	scene.set_player_appearance_height(0.0)
	_check(
		is_zero_approx(scene.get_player_appearance_height()),
		"传入 0 应恢复 UNIT_SCALE 统一缩放"
	)
	_check(
		visual.display_scale > 0.0,
		"恢复统一缩放后角色仍应保持可见缩放"
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
