extends CharacterBody2D

@export var speed: float = 90.0
var facing: Vector2 = Vector2.DOWN
var movement_locked: bool = false
var walk_time: float = 0.0

func _physics_process(delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		facing = direction
		walk_time += delta * 12.0
	else:
		walk_time = 0.0
	velocity = direction * speed
	move_and_slide()
	queue_redraw()

func set_movement_locked(locked: bool) -> void:
	movement_locked = locked
	velocity = Vector2.ZERO
	walk_time = 0.0
	queue_redraw()

# The ray checks only the facing direction; walls block interaction too.
func find_interactable() -> Node:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + facing * 42.0, 1)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("get_dialogue_data"):
		return hit.collider
	return null

func _draw() -> void:
	draw_set_transform(Vector2(0, 6), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 12, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	var step := sin(walk_time) * 2.0
	draw_rect(Rect2(-8, -2, 7, 10 + step), Color("28384c"))
	draw_rect(Rect2(1, -2, 7, 10 - step), Color("28384c"))
	draw_rect(Rect2(-10, -15, 20, 15), Color("508dc5"))
	draw_rect(Rect2(-7, -28, 14, 14), Color("f0c79d"))
	draw_rect(Rect2(-8, -30, 16, 7), Color("34445b"))
	draw_circle(Vector2(facing.x * 4, -21 + facing.y * 2), 2, Color("263447"))
	draw_line(Vector2(0, -9), Vector2(facing.x * 6, -9 + facing.y * 5), Color("c4e9ed"), 2)
