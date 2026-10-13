extends SceneTree

## 在现有 lxq 待机 SpriteFrames 中生成待机动画 02。
##
## 01（idle_01）是从站立转入待机的完整剪片；02（idle_02）只截取 01
## 最后 0.5 秒（12 fps 共 6 帧），按 x → 末帧 → 回到 x 对称往返循环。
## 运行方式：
## Godot --headless --path <项目> --script res://tools/generate_idle_02.gd

const IDLE_ANIMATION_RESOURCE := (
	"res://assets/characters/lxq/animation/idle/animation.tres"
)
const LEGACY_ANIMATION := &"idle_left"
const ENTER_ANIMATION := &"idle_01"
const LOOP_ANIMATION := &"idle_02"
const LOOP_FPS := 12.0
const TAIL_FRAME_COUNT := 6


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var frames: SpriteFrames = load(IDLE_ANIMATION_RESOURCE)
	if frames == null:
		printerr("无法加载待机动画资源: " + IDLE_ANIMATION_RESOURCE)
		quit(1)
		return

	if frames.has_animation(LEGACY_ANIMATION):
		frames.rename_animation(LEGACY_ANIMATION, ENTER_ANIMATION)
	elif not frames.has_animation(ENTER_ANIMATION):
		printerr("资源中既没有 idle_left，也没有 idle_01，无法生成 02")
		quit(1)
		return

	frames.set_animation_loop(ENTER_ANIMATION, false)
	frames.set_animation_speed(ENTER_ANIMATION, LOOP_FPS)

	if frames.has_animation(LOOP_ANIMATION):
		frames.remove_animation(LOOP_ANIMATION)

	var enter_count := frames.get_frame_count(ENTER_ANIMATION)
	frames.add_animation(LOOP_ANIMATION)
	frames.set_animation_loop(LOOP_ANIMATION, true)
	frames.set_animation_speed(LOOP_ANIMATION, LOOP_FPS)
	var first_index := enter_count - TAIL_FRAME_COUNT
	for source_index in range(first_index, enter_count):
		if not _append_tail_frame(frames, source_index):
			quit(1)
			return
	for source_index in range(enter_count - 2, first_index - 1, -1):
		if not _append_tail_frame(frames, source_index):
			quit(1)
			return

	var error := ResourceSaver.save(frames, IDLE_ANIMATION_RESOURCE)
	if error != OK:
		printerr("保存待机动画资源失败: %s" % error_string(error))
		quit(1)
		return

	var loop_count := frames.get_frame_count(LOOP_ANIMATION)
	print(
		"IDLE_02 GENERATED: idle_01=%d frames, idle_02=%d frames, %.1f fps"
		% [enter_count, loop_count, LOOP_FPS]
	)
	quit(0)


func _append_tail_frame(frames: SpriteFrames, source_index: int) -> bool:
	var frame_texture: Texture2D = frames.get_frame_texture(
		ENTER_ANIMATION,
		source_index
	)
	if frame_texture == null:
		printerr("idle_01 第 %d 帧缺少贴图，无法生成 idle_02" % (
			source_index + 1
		))
		return false
	frames.add_frame(LOOP_ANIMATION, frame_texture, 1.0)
	return true
