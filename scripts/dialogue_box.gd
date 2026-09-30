extends CanvasLayer

signal closed
var active: bool = false
var lines: Array[String] = []
var line_index: int = 0
@onready var panel: PanelContainer = $Screen/Panel
@onready var face: TextureRect = $Screen/Panel/Margin/Row/Portrait
@onready var speaker: Label = $Screen/Panel/Margin/Row/Text/Name
@onready var body: Label = $Screen/Panel/Margin/Row/Text/Body
@onready var marker: Label = $Screen/Panel/Margin/Row/Text/Next

func _ready() -> void:
	panel.hide()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.14, 0.94)
	style.border_color = Color("a6b6cf")
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)

func start(data: Dictionary) -> bool:
	if active or data.get("dialogue", []).is_empty():
		return false
	lines.assign(data["dialogue"])
	line_index = 0
	speaker.text = data.get("name", "")
	face.texture = data.get("portrait")
	active = true
	panel.show()
	show_line()
	return true

func advance() -> void:
	if not active:
		return
	line_index += 1
	if line_index >= lines.size():
		close()
	else:
		show_line()

func close() -> void:
	if not active:
		return
	active = false
	panel.hide()
	closed.emit()

func show_line() -> void:
	body.text = lines[line_index]
	marker.text = "▼   E / Space" if line_index < lines.size() - 1 else "◆   E / Space · 닫기"
