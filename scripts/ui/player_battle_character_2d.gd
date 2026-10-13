class_name PlayerBattleCharacter2D
extends BattleCharacter2D

## 玩家队伍的默认 2D 战斗外观。

const GOLD_ACCENT := Color(0.93, 0.78, 0.44)


func _draw_body(canvas: CanvasItem) -> void:
	var cloth := accent.darkened(0.4)
	var cloth_light := accent.darkened(0.1)
	var dark := Color(0.1, 0.14, 0.18)

	canvas.draw_rect(
		Rect2(Vector2(-24.0, -48.0), Vector2(19.0, 48.0)),
		dark
	)
	canvas.draw_rect(
		Rect2(Vector2(5.0, -48.0), Vector2(19.0, 48.0)),
		dark.darkened(0.18)
	)
	canvas.draw_rect(
		Rect2(Vector2(-28.0, -118.0), Vector2(56.0, 72.0)),
		cloth
	)
	canvas.draw_rect(
		Rect2(Vector2(-28.0, -118.0), Vector2(56.0, 10.0)),
		cloth_light
	)
	canvas.draw_rect(
		Rect2(Vector2(-41.0, -112.0), Vector2(13.0, 62.0)),
		cloth_light
	)
	canvas.draw_rect(
		Rect2(Vector2(28.0, -112.0), Vector2(13.0, 62.0)),
		cloth_light
	)
	canvas.draw_circle(
		Vector2(0.0, -142.0),
		24.0,
		Color(0.9, 0.75, 0.62)
	)
	canvas.draw_rect(
		Rect2(Vector2(-25.0, -156.0), Vector2(50.0, 12.0)),
		accent.darkened(0.25)
	)


func _draw_weapon(canvas: CanvasItem) -> void:
	canvas.draw_line(
		Vector2(31.0, -104.0),
		Vector2(88.0, -198.0),
		Color(0.78, 0.86, 0.94),
		6.0,
		true
	)
	canvas.draw_line(
		Vector2(31.0, -104.0),
		Vector2(68.0, -118.0),
		GOLD_ACCENT,
		5.0,
		true
	)
