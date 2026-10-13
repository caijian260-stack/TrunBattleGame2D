class_name EnemyBattleCharacter2D
extends BattleCharacter2D

## 敌方单位的默认 2D 战斗外观。


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
		Vector2(78.0, -190.0),
		Color(0.44, 0.36, 0.3),
		7.0,
		true
	)
	canvas.draw_circle(Vector2(80.0, -194.0), 11.0, accent)
