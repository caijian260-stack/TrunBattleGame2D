class_name AssetBattleCharacter2D
extends BattleCharacter2D

## 通用素材驱动角色子类：按 CharacterRegistry 中的角色 id 读取
## assets/characters/<id>/ 下的立绘、四视图和待机动画，供查看器直接复用。

const CharacterRegistryScript := preload(
	"res://scripts/core/character_registry.gd"
)

var character_id := -1
var portrait_texture: Texture2D
var left_texture: Texture2D
var right_texture: Texture2D
var front_texture: Texture2D
var back_texture: Texture2D


func setup_character(
	p_character_id: int,
	p_unit: BattleUnit,
	p_accent: Color,
	p_is_player: bool
) -> void:
	character_id = p_character_id
	super.setup(p_unit, p_accent, p_is_player)
	_load_look_textures(p_character_id)
	idle_frames = _load_sprite_frames(
		CharacterRegistryScript.get_idle_animation_path(p_character_id)
	)
	if front_texture != null:
		use_front_view()
	elif portrait_texture != null:
		use_portrait()
	elif left_texture != null:
		use_left_view()


func setup(
	p_unit: BattleUnit,
	p_accent: Color,
	p_is_player: bool
) -> void:
	super.setup(p_unit, p_accent, p_is_player)


func use_portrait() -> void:
	_use_texture(portrait_texture)


func use_left_view() -> void:
	_use_texture(left_texture)


func use_right_view() -> void:
	_use_texture(right_texture)


func use_front_view() -> void:
	_use_texture(front_texture)


func use_back_view() -> void:
	_use_texture(back_texture)


func _load_look_textures(p_character_id: int) -> void:
	portrait_texture = _load_texture(
		CharacterRegistryScript.asset_path(p_character_id, "portrait.png")
	)
	left_texture = _load_texture(
		CharacterRegistryScript.asset_path(p_character_id, "left.png")
	)
	right_texture = _load_texture(
		CharacterRegistryScript.asset_path(p_character_id, "right.png")
	)
	front_texture = _load_texture(
		CharacterRegistryScript.asset_path(p_character_id, "front.png")
	)
	back_texture = _load_texture(
		CharacterRegistryScript.asset_path(p_character_id, "back.png")
	)


func _use_texture(texture: Texture2D) -> void:
	if texture == null:
		appearance_texture = null
		return
	set_appearance_texture(
		texture,
		Vector2(texture.get_width(), texture.get_height())
	)


func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var resource := load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _load_sprite_frames(path: String) -> SpriteFrames:
	if not FileAccess.file_exists(path):
		return null
	var resource := load(path)
	if resource is SpriteFrames:
		return resource as SpriteFrames
	return null
