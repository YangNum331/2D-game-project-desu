@tool
extends Marker2D

@export var spawn_id: String = ""
@export var facing: Vector2 = Vector2.DOWN

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 8, Color(0.3, 0.9, 0.7, 0.7))
		draw_line(Vector2.ZERO, facing.normalized() * 20, Color.WHITE, 2)
