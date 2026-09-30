@tool
extends Node2D

const TILE: int = 32
const WIDTH: int = 20
const HEIGHT: int = 15
var walls: Array[Vector2i] = []
@export_enum("Start", "Field", "Interior") var layout: int = 0
const NPC_SCENE = preload("res://scenes/npc.tscn")
var content: Dictionary = {}

func _ready() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if is_wall(x, y):
				walls.append(Vector2i(x, y))
				if Engine.is_editor_hint():
					continue
				var wall := StaticBody2D.new()
				var collider := CollisionShape2D.new()
				var shape := RectangleShape2D.new()
				shape.size = Vector2(TILE, TILE)
				collider.shape = shape
				wall.position = Vector2(x * TILE + TILE / 2, y * TILE + TILE / 2)
				wall.add_child(collider)
				$Walls.add_child(wall)
	queue_redraw()

func apply_content(data: Dictionary, loader: RefCounted, debug_visible: bool) -> void:
	content = data
	for child in $Actors.get_children():
		if child.has_method("get_dialogue_data"):
			$Actors.remove_child(child)
			child.queue_free()
	for npc_data in data["npcs"]:
		var point: Vector2 = npc_data["position"]
		var blocked := point.x < 10 or point.x > WIDTH * TILE - 10 or point.y < 9 or point.y > HEIGHT * TILE - 9
		for tile in walls:
			if Rect2(Vector2(tile) * TILE, Vector2(TILE, TILE)).intersects(Rect2(point - Vector2(10, 9), Vector2(20, 18))):
				blocked = true
		if blocked:
			loader.report(data["path"], "npc:" + npc_data["id"], "NPC position is outside the map or inside a wall. NPC skipped.", point)
			continue
		var npc := NPC_SCENE.instantiate()
		npc.name = "NPC_" + npc_data["id"]
		npc.configure(npc_data)
		$Actors.add_child(npc)
		npc.set_debug_visible(debug_visible)

func set_debug_visible(enabled: bool) -> void:
	for npc in $Actors.get_children():
		if npc.has_method("set_debug_visible"):
			npc.set_debug_visible(enabled)

func is_wall(x: int, y: int) -> bool:
	if layout == 2:
		return ((x == 4 or x == 15) and y >= 2 and y <= 12) or (y == 2 and x >= 4 and x <= 15) or (y == 12 and x >= 4 and x <= 15 and x != 9 and x != 10) or x < 4 or x > 15 or y < 2 or y > 12
	var boundary := x == 0 or x == WIDTH - 1 or (y == 0 and not (layout == 0 and x >= 8 and x <= 10)) or (y == HEIGHT - 1 and not (layout == 1 and x >= 8 and x <= 10))
	if layout == 1:
		return boundary or (x >= 12 and x <= 16 and y >= 3 and y <= 6 and not (y == 6 and x == 14))
	return boundary or (y == 4 and x >= 3 and x <= 8 and x != 6) or (x == 3 and y >= 2 and y <= 3) or (x == 14 and y >= 6 and y <= 10 and y != 8) or (y == 10 and x >= 14 and x <= 17)

func _draw() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			var path := (x >= 8 and x <= 10) or (y >= 7 and y <= 8) or (x >= 4 and x <= 7 and y >= 2 and y <= 3)
			var color := Color("c0b38c") if path else (Color("718565") if (x + y) % 2 == 0 else Color("75896a"))
			if layout == 2:
				color = Color("a7947b") if (x + y) % 2 == 0 else Color("af9c81")
			draw_rect(rect, color)
			draw_rect(rect, Color(0, 0, 0, 0.055), false)
			if not path and (x * 7 + y * 3) % 5 == 0:
				draw_line(rect.position + Vector2(8, 23), rect.position + Vector2(10, 19), Color("60765b"), 1)
	for tile in walls:
		var rect := Rect2(Vector2(tile) * TILE, Vector2(TILE, TILE))
		draw_rect(rect, Color("535b65"))
		draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(30, 23)), Color("818991"))
		draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(30, 2), Color("a5adb1"), 2)
		draw_line(rect.position + Vector2(0, 15), rect.position + Vector2(32, 15), Color("67717a"), 1)
	if layout == 1:
		draw_rect(Rect2(384, 96, 160, 64), Color("785454"))
		for roof_y in range(102, 160, 12):
			draw_line(Vector2(386, roof_y), Vector2(542, roof_y), Color("a57668"), 2)
		draw_rect(Rect2(384, 160, 160, 48), Color("c4ad85"))
		draw_rect(Rect2(400, 170, 28, 24), Color("5c8390"))
		draw_rect(Rect2(502, 170, 28, 24), Color("5c8390"))
		draw_rect(Rect2(450, 180, 28, 28), Color("59463a"))
		return
	if layout == 2:
		draw_rect(Rect2(192, 144, 64, 32), Color("795b48"))
		draw_rect(Rect2(194, 142, 60, 28), Color("bd9368"))
		return
	for pos in [Vector2(80, 208), Vector2(112, 208), Vector2(528, 112), Vector2(560, 112)]:
		draw_circle(pos, 7, Color("586f52"))
		draw_circle(pos + Vector2(0, -3), 3, Color("e7c686"))
	draw_rect(Rect2(386, 126, 28, 10), Color("5a5149"))
	draw_rect(Rect2(384, 104, 32, 26), Color("979b99"))
	draw_rect(Rect2(390, 109, 20, 15), Color("344f5a"))
