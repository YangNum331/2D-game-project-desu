extends SceneTree

var failures: int = 0
var checks: int = 0
var map: Node2D
var player: CharacterBody2D
var box: CanvasLayer
var manager: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func key(code: int, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func tap(code: int) -> void:
	key(code)
	await frames(2)
	key(code, false)
	await frames(2)

func run() -> void:
	manager = load("res://scenes/demo_map.tscn").instantiate()
	root.add_child(manager)
	current_scene = manager
	map = manager.current_map
	player = manager.player
	box = manager.dialogue_box
	await frames(4)
	check(not box.active and not box.panel.visible, "dialogue hidden on boot")
	for code in [KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		player.position = Vector2(304, 280)
		key(code)
		await frames(3)
		check(is_equal_approx(player.velocity.length(), 90.0), "physical movement mapping " + str(code))
		key(code, false)
		await frames(2)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
		player.position = Vector2(304, 280)
		if direction.x < 0: Input.action_press("move_left")
		if direction.x > 0: Input.action_press("move_right")
		if direction.y < 0: Input.action_press("move_up")
		if direction.y > 0: Input.action_press("move_down")
		await frames(4)
		check(is_equal_approx(player.velocity.length(), 90.0) and player.facing.is_equal_approx(direction.normalized()), "normalized direction " + str(direction))
		for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
		await frames(2)
	player.position = Vector2(50, 280)
	Input.action_press("move_left")
	await frames(25)
	Input.action_release("move_left")
	check(player.position.x >= 40.9 and player.position.x <= 42.0, "wall stops player")
	player.position = Vector2(304, 250)
	Input.action_press("move_up")
	await frames(30)
	Input.action_release("move_up")
	await frames(2)
	check(player.position.y >= 224.9 and player.position.y <= 226.0, "NPC stops player")
	check(player.find_interactable() == map.get_node("Actors/NPC_start_npc"), "front NPC detected")
	player.facing = Vector2.DOWN
	await tap(KEY_E)
	check(not box.active, "cannot talk facing away")
	player.facing = Vector2.UP
	await tap(KEY_E)
	check(box.active and box.line_index == 0 and box.body.text == "안녕! 나는 테스트 NPC야.", "opening press displays first line once")
	check(box.face.texture != null and box.speaker.text == "테스트 NPC", "portrait and speaker assigned")
	var stopped_at := player.position
	Input.action_press("move_right")
	await frames(10)
	check(player.position.is_equal_approx(stopped_at) and player.velocity == Vector2.ZERO, "movement locked during dialogue")
	Input.action_release("move_right")
	key(KEY_E, true, true)
	await frames(2)
	key(KEY_E, false)
	check(box.line_index == 0, "key repeat does not advance")
	for index in range(1, 6):
		await tap(KEY_SPACE if index % 2 else KEY_E)
		check(box.active and box.line_index == index and box.body.text == map.get_node("Actors/NPC_start_npc").dialogue[index], "dialogue line " + str(index + 1))
		if index == 3 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/dialogue_preview.png")
	await tap(KEY_SPACE)
	check(not box.active and not box.panel.visible and not player.movement_locked, "last press closes and unlocks")
	Input.action_press("move_right")
	await frames(4)
	Input.action_release("move_right")
	check(player.position.x > stopped_at.x, "movement resumes")
	player.position = stopped_at
	player.facing = Vector2.UP
	await tap(KEY_SPACE)
	check(box.active and box.line_index == 0, "repeat conversation restarts at first line")
	if DisplayServer.get_name() != "headless":
		box.advance()
		while box.active: box.advance()
		player.position = Vector2(304, 280)
		await frames(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/map_preview.png")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
