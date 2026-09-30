extends Node2D

const ContentLoader = preload("res://scripts/content_loader.gd")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
@export_file("*.cfg") var initial_config: String = "res://data/maps/start_map.cfg"
var loader = ContentLoader.new()
var current_map: Node2D
var current_data: Dictionary = {}
var player: CharacterBody2D
var changing: bool = false
var debug_visible: bool = false
var transition_cooldown: float = 0.0
var toast_time: float = 0.0
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var hint: Label = $HUD/Hint
@onready var debug_text: Label = $HUD/Debug
@onready var status_text: Label = $HUD/Status

func _ready() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_movement_locked(true)
	dialogue_box.closed.connect(func(): player.set_movement_locked(false))
	change_map(initial_config)

func instantiate_map(data: Dictionary) -> Node2D:
	var packed: PackedScene = load(data["scene"])
	if packed == null:
		loader.report(data["path"], "scene", "Map scene could not be loaded.", data["scene"])
		return null
	var map: Node = packed.instantiate()
	if not map is Node2D or not map.has_method("apply_content"):
		loader.report(data["path"], "scene", "Map must be Node2D using game_map.gd.", data["scene"])
		map.free()
		return null
	for container in ["Actors", "Walls", "SpawnPoints", "Transitions"]:
		if map.get_node_or_null(container) == null:
			loader.report(data["path"], "scene", "Map scene is missing " + container, data["scene"])
			map.free()
			return null
	return map

func spawn_points(map: Node2D, path: String) -> Dictionary:
	var points: Dictionary = {}
	var container := map.get_node_or_null("SpawnPoints")
	if container == null:
		loader.report(path, "scene", "Scene is missing SpawnPoints.")
		return points
	for point in container.get_children():
		if not point is Marker2D or not "spawn_id" in point or point.spawn_id.is_empty():
			loader.report(path, "scene", "SpawnPoint requires Marker2D and a non-empty spawn_id.", point.name)
			continue
		if points.has(point.spawn_id):
			loader.report(path, "scene", "Duplicate SpawnPoint ID.", point.spawn_id)
			continue
		points[point.spawn_id] = point
	return points

func validate_transitions(data: Dictionary, map: Node2D) -> void:
	var ids: Dictionary = {}
	var container := map.get_node_or_null("Transitions")
	if container == null:
		loader.report(data["path"], "scene", "Scene is missing Transitions.")
		data["transitions"].clear()
		return
	for area in container.get_children():
		if not area is Area2D or not "transition_id" in area:
			loader.report(data["path"], "scene", "Transition area must use transition_area.gd.", area.name)
			continue
		if ids.has(area.transition_id):
			loader.report(data["path"], "transition:" + area.transition_id, "Duplicate transition ID in scene. Transition disabled.")
			data["transitions"].erase(area.transition_id)
		else:
			ids[area.transition_id] = true
	for id in data["transitions"].keys():
		if not ids.has(id):
			loader.report(data["path"], "transition:" + id, "No matching TransitionArea in scene. Transition disabled.")
			data["transitions"].erase(id)
			continue
		var link: Dictionary = data["transitions"][id]
		var target: Dictionary = loader.load_map(loader.map_path(link["target_map"]))
		if target.is_empty():
			data["transitions"].erase(id)
			continue
		var destination := instantiate_map(target)
		if destination == null:
			data["transitions"].erase(id)
			continue
		if target["id"] != link["target_map"]:
			loader.report(data["path"], "transition:" + id, "Target scene must be Node2D and CFG id must match target_map.", link["target_map"])
			data["transitions"].erase(id)
			destination.free()
			continue
		var points := spawn_points(destination, target["path"])
		if not points.has(link["target_spawn"]):
			loader.report(data["path"], "transition:" + id, "target_spawn does not exist. Transition disabled.", link["target_spawn"])
			data["transitions"].erase(id)
		destination.free()

func change_map(config_path: String, target_spawn: String = "") -> bool:
	var data: Dictionary = loader.load_map(config_path)
	if data.is_empty():
		show_status("맵 설정을 읽지 못했습니다. 8로 오류를 확인하세요.")
		return false
	var next_map := instantiate_map(data)
	if next_map == null:
		show_status("맵 씬을 불러오지 못했습니다. 8로 오류를 확인하세요.")
		return false
	var points := spawn_points(next_map, config_path)
	var spawn_id: String = data["default_spawn"] if target_spawn.is_empty() else target_spawn
	if not points.has(spawn_id):
		loader.report(config_path, "map", "Requested SpawnPoint does not exist. Current map kept.", spawn_id)
		next_map.free()
		show_status("출현 지점을 찾지 못했습니다. 8로 오류를 확인하세요.")
		return false
	validate_transitions(data, next_map)
	dialogue_box.close()
	if player.get_parent() != self:
		player.reparent(self)
	if current_map != null:
		remove_child(current_map)
		current_map.queue_free()
	current_map = next_map
	current_data = data
	add_child(current_map)
	current_map.apply_content(data, loader, debug_visible)
	player.reparent(current_map.get_node("Actors"), false)
	var spawn: Marker2D = points[spawn_id]
	player.global_position = spawn.global_position
	player.facing = spawn.facing.normalized() if spawn.facing != Vector2.ZERO else Vector2.DOWN
	player.set_movement_locked(false)
	player.get_node("Camera2D").reset_smoothing()
	for area in current_map.get_node("Transitions").get_children():
		if area.has_signal("activated"):
			area.activated.connect(request_transition)
	transition_cooldown = 0.35
	hint.text = "%s\nWASD / 방향키 · E / Space 대화 · 8 좌표 · 9 새로고침" % data["title"]
	show_status("맵 이동 완료" if loader.errors.is_empty() else "콘텐츠 오류 %d개 · 8 확인" % loader.errors.size())
	return true

func request_transition(id: String) -> void:
	if changing or dialogue_box.active or transition_cooldown > 0:
		return
	if not current_data["transitions"].has(id):
		show_status("이동 연결을 확인하세요. 8로 오류를 확인할 수 있습니다.")
		return
	changing = true
	player.set_movement_locked(true)
	# Do not remove physics bodies during an Area2D body_entered callback.
	call_deferred("perform_transition", current_data["transitions"][id])

func perform_transition(link: Dictionary) -> void:
	change_map(loader.map_path(link["target_map"]), link["target_spawn"])
	changing = false
	player.set_movement_locked(false)

func reload_content() -> void:
	if changing:
		return
	loader.errors.clear()
	if current_map == null:
		change_map(initial_config)
		return
	var data: Dictionary = loader.load_map(current_data["path"])
	if data.is_empty():
		show_status("새로고침 실패 · 기존 콘텐츠 유지 · 8 오류 확인")
		return
	if data["scene"] != current_data["scene"] or data["id"] != current_data["id"]:
		loader.report(data["path"], "map", "Changing map scene/id requires restarting the game.")
		show_status("맵 ID / scene 변경은 재실행이 필요합니다.")
		return
	validate_transitions(data, current_map)
	dialogue_box.close()
	current_data = data
	current_map.apply_content(data, loader, debug_visible)
	hint.text = "%s\nWASD / 방향키 · E / Space 대화 · 8 좌표 · 9 새로고침" % data["title"]
	show_status("콘텐츠 새로고침 완료" if loader.errors.is_empty() else "새로고침 완료 · 오류 %d개 · 8 확인" % loader.errors.size())

func show_status(message: String) -> void:
	status_text.text = message
	toast_time = 4.0

func _process(delta: float) -> void:
	transition_cooldown = maxf(0.0, transition_cooldown - delta)
	toast_time = maxf(0.0, toast_time - delta)
	status_text.visible = toast_time > 0
	debug_text.visible = debug_visible
	if debug_visible:
		debug_text.text = "MAP: %s\nPLAYER X: %d   Y: %d\n" % [current_data.get("id", "불러오기 실패"), player.position.x, player.position.y]
		if not loader.errors.is_empty():
			debug_text.text += "오류 %d개 (전체 내용은 Godot 출력 창)\n%s" % [loader.errors.size(), loader.errors.back()]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if OS.is_debug_build() and event.is_action_pressed("debug_coordinates"):
		debug_visible = not debug_visible
		if current_map != null: current_map.set_debug_visible(debug_visible)
		get_viewport().set_input_as_handled()
		return
	if OS.is_debug_build() and event.is_action_pressed("reload_content"):
		reload_content()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if dialogue_box.active:
		dialogue_box.advance()
		return
	if changing or current_map == null:
		return
	var target: Node = player.find_interactable()
	if target != null and dialogue_box.start(target.get_dialogue_data()):
		player.set_movement_locked(true)
