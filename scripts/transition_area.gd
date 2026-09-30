@tool
extends Area2D

signal activated(transition_id: String)
@export var transition_id: String = ""
@export var area_size: Vector2 = Vector2(64, 24):
	set(value):
		area_size = value
		update_shape()
@export var area_color: Color = Color(0.025, 0.035, 0.055, 1):
	set(value):
		area_color = value
		queue_redraw()

func _ready() -> void:
	update_shape()
	set_physics_process(not Engine.is_editor_hint())

func _physics_process(_delta: float) -> void:
	# Retry contact after the manager's short cooldown or a dialogue finishes.
	# A body_entered-only handler can otherwise lose a contact during cooldown.
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			activated.emit(transition_id)
			return

func update_shape() -> void:
	var collider := get_node_or_null("CollisionShape2D")
	if collider != null:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(maxf(area_size.x, 1), maxf(area_size.y, 1))
		collider.shape = shape
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-area_size / 2, area_size), area_color)
	if Engine.is_editor_hint():
		draw_rect(Rect2(-area_size / 2, area_size), Color(0.8, 0.6, 1, 1), false, 2)
