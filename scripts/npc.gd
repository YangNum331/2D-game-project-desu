extends StaticBody2D

var npc_id: String = ""
var npc_name: String = ""
var portrait: Texture2D
var dialogue: Array[String] = []
var debug_label: Label

func configure(data: Dictionary) -> void:
	npc_id = data["id"]
	npc_name = data["name"]
	position = data["position"]
	portrait = data["portrait"]
	dialogue.assign(data["dialogue"])

func set_debug_visible(enabled: bool) -> void:
	if debug_label == null:
		debug_label = Label.new()
		debug_label.position = Vector2(-55, -60)
		debug_label.add_theme_font_size_override("font_size", 11)
		debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		debug_label.add_theme_constant_override("shadow_offset_x", 1)
		debug_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(debug_label)
	debug_label.text = "%s\n(%d, %d)" % [npc_id, position.x, position.y]
	debug_label.visible = enabled

func get_dialogue_data() -> Dictionary:
	return {"name": npc_name, "portrait": portrait, "dialogue": dialogue.duplicate()}

func _draw() -> void:
	draw_set_transform(Vector2(0, 6), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 12, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-8, -2, 16, 10), Color("44364b"))
	draw_rect(Rect2(-10, -15, 20, 16), Color("bf7c70"))
	draw_rect(Rect2(-7, -28, 14, 14), Color("f0c79d"))
	draw_rect(Rect2(-9, -30, 18, 8), Color("684e49"))
	draw_rect(Rect2(-9, -24, 4, 12), Color("684e49"))
	draw_circle(Vector2(-3, -20), 1.5, Color("44364b"))
	draw_circle(Vector2(3, -20), 1.5, Color("44364b"))
