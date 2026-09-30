extends SceneTree

const Loader = preload("res://scripts/content_loader.gd")
var failures: int = 0
var checks: int = 0
var manager: Node2D
var cfg_path := "res://data/maps/start_map.cfg"
var txt_path := "res://data/dialogue/start_npc.txt"
var original_cfg: String
var original_txt: String

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func tap(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await frames(2)

func touch_transition(position: Vector2, action: String, expected: String, spawn: Vector2) -> void:
	manager.player.position = position
	await frames(30)
	Input.action_press(action)
	# Release as soon as the destination loads to inspect the exact spawn location.
	for i in range(65):
		await frames(1)
		if manager.current_data["id"] == expected:
			break
	Input.action_release(action)
	manager.player.velocity = Vector2.ZERO
	check(manager.current_data["id"] == expected, "Area2D contact enters " + expected)
	check(manager.player.position.distance_to(spawn) <= 2.0, "correct spawn " + str(spawn))
	await frames(3)

func talk_to(id: String) -> void:
	var npc: StaticBody2D = manager.current_map.get_node("Actors/NPC_" + id)
	manager.player.position = npc.position + Vector2(0, 30)
	manager.player.facing = Vector2.UP
	await frames(3)
	await tap(KEY_E)
	check(manager.dialogue_box.active and manager.dialogue_box.speaker.text == npc.npc_name and manager.dialogue_box.body.text == npc.dialogue[0], "NPC dialogue " + id)
	check(manager.player.movement_locked and manager.dialogue_box.face.texture != null, "dialogue lock and portrait " + id)
	var current_id: String = manager.current_data["id"]
	manager.request_transition(manager.current_data["transitions"].keys()[0])
	await frames(2)
	check(manager.current_data["id"] == current_id and not manager.changing, "map travel blocked during dialogue " + id)
	while manager.dialogue_box.active:
		await tap(KEY_SPACE)
	check(not manager.player.movement_locked, "dialogue unlock " + id)

func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func invalid_fixture(text: String, expected_message: String) -> void:
	var loader = Loader.new()
	var path := "res://.godot/invalid_content.cfg"
	write_file(path, text)
	loader.load_map(path)
	check(not loader.errors.is_empty() and "\n".join(loader.errors).contains(expected_message), "validation " + expected_message)

func run() -> void:
	original_cfg = FileAccess.get_file_as_string(cfg_path)
	original_txt = FileAccess.get_file_as_string(txt_path)
	manager = load("res://scenes/demo_map.tscn").instantiate()
	root.add_child(manager)
	current_scene = manager
	await frames(5)
	check(manager.current_data["id"] == "start_map", "start map on boot")
	check(manager.loader.errors.is_empty(), "all sample links and NPCs valid")
	await talk_to("start_npc")
	await touch_transition(Vector2(304, 70), "move_up", "second_map", Vector2(304, 416))
	Input.action_press("move_down")
	for i in range(65):
		await frames(1)
		if manager.current_data["id"] == "start_map": break
	Input.action_release("move_down")
	check(manager.current_data["id"] == "start_map", "immediate turnaround contact survives cooldown")
	await touch_transition(Vector2(304, 70), "move_up", "second_map", Vector2(304, 416))
	await talk_to("second_npc")
	await screenshot("second_map_preview")
	# The solid building facade must stop movement away from its doorway.
	manager.player.position = Vector2(400, 250)
	await frames(5)
	Input.action_press("move_up")
	await frames(30)
	Input.action_release("move_up")
	check(manager.current_data["id"] == "second_map" and manager.player.position.y >= 231.0, "building facade collision")
	await touch_transition(Vector2(464, 260), "move_up", "building_01", Vector2(320, 352))
	await talk_to("building_npc")
	await screenshot("building_preview")
	await touch_transition(Vector2(320, 352), "move_down", "second_map", Vector2(464, 260))
	await touch_transition(Vector2(304, 416), "move_down", "start_map", Vector2(304, 64))
	await tap(KEY_8)
	check(manager.debug_visible and manager.debug_text.visible, "8 enables coordinates")
	check(manager.current_map.get_node("Actors/NPC_start_npc").debug_label.visible, "8 NPC coordinates")
	await tap(KEY_8)
	check(not manager.debug_visible, "8 toggles off")
	# Modify real content, reload with the physical 9 key, then restore before quitting.
	var edited := original_cfg.replace('name = "테스트 NPC"', 'name = "수정한 NPC"').replace("position_x = 304", "position_x = 336").replace("test_npc.svg", "village_girl.svg")
	write_file(cfg_path, edited)
	write_file(txt_path, "# ignored comment\n\n수정한 첫 페이지\n\n두 번째 페이지\n")
	var saved_position: Vector2 = manager.player.position
	await tap(KEY_9)
	var npc: StaticBody2D = manager.current_map.get_node("Actors/NPC_start_npc")
	check(npc.npc_name == "수정한 NPC" and npc.position == Vector2(336, 208), "CFG name and local position reload")
	check(npc.dialogue == ["수정한 첫 페이지", "두 번째 페이지"], "TXT comments/blank lines and live reload")
	check(npc.portrait.get_image().get_pixel(0, 0) != load("res://assets/portraits/test_npc.svg").get_image().get_pixel(0, 0), "portrait path reload")
	check(manager.player.position == saved_position, "reload preserves player position")
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	image.save_png("res://.godot/reload_portrait.png")
	write_file(cfg_path, edited.replace("res://assets/portraits/village_girl.svg", "res://.godot/reload_portrait.png"))
	await tap(KEY_9)
	npc = manager.current_map.get_node("Actors/NPC_start_npc")
	check(npc.portrait.get_image().get_pixel(8, 8) == Color.RED, "new unimported PNG loads with 9")
	await talk_to("start_npc")
	# Changing content during a conversation closes it safely.
	manager.player.position = npc.position + Vector2(0, 30)
	manager.player.facing = Vector2.UP
	await frames(2)
	await tap(KEY_E)
	await tap(KEY_9)
	check(not manager.dialogue_box.active and not manager.player.movement_locked, "reload while talking closes safely")
	write_file(cfg_path, original_cfg + '\n[npc:extra_npc]\nname = "추가 NPC"\nposition_x = 368\nposition_y = 280\nportrait = "res://assets/portraits/caretaker.svg"\ndialogue = "res://data/dialogue/building_npc.txt"\n')
	await tap(KEY_9)
	check(manager.current_map.has_node("Actors/NPC_extra_npc"), "new NPC section creates common NPC")
	write_file(cfg_path, original_cfg.replace('target_map = "second_map"', 'target_map = "building_01"').replace('target_spawn = "south_entrance"', 'target_spawn = "entrance"'))
	await tap(KEY_9)
	await touch_transition(Vector2(304, 70), "move_up", "building_01", Vector2(320, 352))
	check(manager.current_data["id"] == "building_01", "CFG-only change reconnects map travel")
	write_file(cfg_path, original_cfg)
	manager.change_map(cfg_path)
	await frames(3)
	# Friendly fallback and invalid value handling in the running game.
	write_file(cfg_path, original_cfg.replace("test_npc.svg", "missing.svg").replace("start_npc.txt", "missing.txt"))
	await tap(KEY_9)
	npc = manager.current_map.get_node("Actors/NPC_start_npc")
	check(npc.portrait != null and npc.dialogue.size() == 1 and manager.loader.errors.size() >= 2, "missing portrait/dialogue fallbacks")
	write_file(cfg_path, original_cfg.replace("position_x = 304", 'position_x = "hello"'))
	await tap(KEY_9)
	check(not manager.current_map.has_node("Actors/NPC_start_npc") and not manager.loader.errors.is_empty(), "bad coordinate skips NPC without crash")
	write_file(cfg_path, original_cfg.replace('target_spawn = "south_entrance"', 'target_spawn = "missing_spawn"'))
	await tap(KEY_9)
	check(not manager.current_data["transitions"].has("north_exit"), "missing target spawn disables transition")
	write_file(cfg_path, original_cfg.replace('[npc:start_npc]', '[npc:start_npc]\n[npc:start_npc]'))
	await tap(KEY_9)
	check(manager.current_data["id"] == "start_map" and not manager.loader.errors.is_empty(), "invalid whole CFG preserves current map")
	write_file(cfg_path, original_cfg)
	write_file(txt_path, original_txt)
	await tap(KEY_9)
	check(manager.loader.errors.is_empty() and manager.current_map.has_node("Actors/NPC_start_npc"), "original content restored")
	invalid_fixture(original_cfg.replace('target_map = "second_map"', 'target_map = "missing_map"'), "target_map does not exist")
	invalid_fixture(original_cfg + "\n[npc:start_npc]\n", "Duplicate section")
	invalid_fixture(original_cfg + "\n[transition:north_exit]\n", "Duplicate section")
	invalid_fixture(original_cfg.replace('name = "테스트 NPC"', ''), "name must be")
	invalid_fixture(original_cfg.replace('scene = "res://maps/start_map.tscn"', 'scene = "res://maps/missing.tscn"'), "Map scene does not exist")
	invalid_fixture("[map\n broken", "Cannot parse CFG")
	var scene: Node2D = load("res://maps/start_map.tscn").instantiate()
	scene.get_node("SpawnPoints/north_entrance").spawn_id = "start"
	manager.loader.errors.clear()
	manager.spawn_points(scene, cfg_path)
	check("\n".join(manager.loader.errors).contains("Duplicate SpawnPoint"), "duplicate spawn IDs reported")
	scene.free()
	scene = load("res://maps/second_map.tscn").instantiate()
	scene.get_node("Transitions/BuildingDoor").transition_id = "return_to_start"
	manager.loader.errors.clear()
	var data: Dictionary = manager.loader.load_map("res://data/maps/second_map.cfg")
	manager.validate_transitions(data, scene)
	check(not data["transitions"].has("return_to_start") and not manager.loader.errors.is_empty(), "duplicate scene transition IDs disabled")
	scene.free()
	var boot_path := "res://.godot/recovery.cfg"
	write_file(boot_path, original_cfg.replace('default_spawn = "start"', 'default_spawn = "missing"'))
	var probe: Node2D = load("res://scenes/demo_map.tscn").instantiate()
	probe.initial_config = boot_path
	root.add_child(probe)
	check(probe.current_map == null and probe.player.movement_locked, "invalid startup leaves safe locked state")
	write_file(boot_path, original_cfg)
	probe.reload_content()
	check(probe.current_map != null and not probe.player.movement_locked, "reload recovers after startup data repair")
	probe.queue_free()
	await frames(3)
	manager.loader.errors.clear()
	manager.player.position = Vector2(304, 280)
	await screenshot("start_map_content_preview")
	print("RESULT: %d content checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
