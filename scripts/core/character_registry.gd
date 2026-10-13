class_name CharacterRegistry
extends RefCounted

## 角色注册表：查看器与后续角色视觉代码共用的角色 id / 目录映射。
##
## 新增角色时在 CharacterId 枚举与 CHARACTERS 列表中登记，再按现有约定
## 在 assets/characters/<folder>/ 下放置立绘与动画资源即可。

enum CharacterId {
	LXQ,
	PLAYER,
	JPE,
}

const CHARACTER_ID_FOLDERS := {
	CharacterId.LXQ: "lxq",
	CharacterId.PLAYER: "player",
	CharacterId.JPE: "jpe",
}

const CHARACTERS := [
	{"id": CharacterId.LXQ, "label": "lxq"},
	{"id": CharacterId.PLAYER, "label": "player"},
	{"id": CharacterId.JPE, "label": "jpe"},
]

const PORTRAIT_FILES := [
	{"label": "立绘", "file": "portrait.png"},
	{"label": "左视图", "file": "left.png"},
	{"label": "右视图", "file": "right.png"},
	{"label": "正视图", "file": "front.png"},
	{"label": "后视图", "file": "back.png"},
]

const DOCUMENT_FILE := "README.md"
const IDLE_ANIMATION_FILE := "animation/idle/animation.tres"
const WALK_SOURCES := [
	{
		"label": "39 帧 · 24 fps",
		"path": "animation/walk/full/animation.tres",
	},
	{
		"label": "16 帧 · 9.8 fps",
		"path": "animation/walk/light/animation.tres",
	},
]


static func get_root_path(character_id: int) -> String:
	return "res://assets/characters/%s/" % _folder(character_id)


static func get_document_path(character_id: int) -> String:
	return get_root_path(character_id) + DOCUMENT_FILE


static func asset_path(character_id: int, relative_path: String) -> String:
	return get_root_path(character_id) + relative_path


static func get_character_name(character_id: int) -> String:
	return _folder(character_id)


static func has_character(character_id: int) -> bool:
	return CHARACTER_ID_FOLDERS.has(character_id)


static func get_character_label(character_id: int) -> String:
	for entry in CHARACTERS:
		if entry["id"] == character_id:
			return entry["label"]
	return _folder(character_id)


static func get_idle_animation_path(character_id: int) -> String:
	return asset_path(character_id, IDLE_ANIMATION_FILE)


static func asset_exists(character_id: int, relative_path: String) -> bool:
	return FileAccess.file_exists(
		asset_path(character_id, relative_path)
	)


static func load_character_document(character_id: int) -> String:
	var path := get_document_path(character_id)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func _folder(character_id: int) -> String:
	return CHARACTER_ID_FOLDERS.get(
		character_id,
		String.num_int64(character_id)
	)
