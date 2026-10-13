class_name LxqBattleCharacter2D
extends BattleCharacter2D

## lxq 的具体 2D 战斗角色外观。
##
## 角色素材统一放在 res://assets/characters/lxq/，本子类直接加载其中
## 的立绘与视图像素图，并保留父类提供的待机动画、阴影、光环和死亡姿态。

const PORTRAIT_TEXTURE := preload(
	"res://assets/characters/lxq/portrait.png"
)
const LEFT_TEXTURE := preload("res://assets/characters/lxq/left.png")
const RIGHT_TEXTURE := preload("res://assets/characters/lxq/right.png")
const FRONT_TEXTURE := preload("res://assets/characters/lxq/front.png")
const BACK_TEXTURE := preload("res://assets/characters/lxq/back.png")
const IDLE_FRAMES := preload(
	"res://assets/characters/lxq/animation/idle/animation.tres"
)

const PORTRAIT_SIZE := Vector2(274.0, 416.0)
const LEFT_SIZE := Vector2(322.0, 409.0)
const RIGHT_SIZE := Vector2(322.0, 409.0)
const FRONT_SIZE := Vector2(230.0, 482.0)
const BACK_SIZE := Vector2(288.0, 486.0)


func setup(
	p_unit: BattleUnit,
	p_accent: Color,
	p_is_player: bool
) -> void:
	super.setup(p_unit, p_accent, p_is_player)
	idle_frames = IDLE_FRAMES
	use_front_view()


func use_portrait() -> void:
	set_appearance_texture(PORTRAIT_TEXTURE, PORTRAIT_SIZE)


func use_left_view() -> void:
	set_appearance_texture(LEFT_TEXTURE, LEFT_SIZE)


func use_right_view() -> void:
	set_appearance_texture(RIGHT_TEXTURE, RIGHT_SIZE)


func use_front_view() -> void:
	set_appearance_texture(FRONT_TEXTURE, FRONT_SIZE)


func use_back_view() -> void:
	set_appearance_texture(BACK_TEXTURE, BACK_SIZE)
