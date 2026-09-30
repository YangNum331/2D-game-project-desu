extends RefCounted

# Small file reader/validator, shared by map startup and 9 reload.
const FALLBACK_PORTRAIT := "res://assets/portraits/test_npc.svg"
var errors: Array[String] = []

func report(file: String, section: String, problem: String, value: Variant = null) -> void:
	var message := "[CONTENT ERROR]\nFile: %s\nSection: %s\nProblem: %s\nCurrent value: %s" % [file, section, problem, var_to_str(value)]
	errors.append(message)
	push_warning(message)

func valid_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_]+$")
	return regex.search(value) != null

func map_path(id: String) -> String:
	return "res://data/maps/%s.cfg" % id if valid_id(id) else ""

func required_string(cfg: ConfigFile, path: String, section: String, key: String) -> String:
	var value: Variant = cfg.get_value(section, key) if cfg.has_section_key(section, key) else null
	if not value is String or value.strip_edges().is_empty():
		report(path, section, key + " must be a non-empty quoted string.", value)
		return ""
	return value.strip_edges()

func read_dialogue(path: String, cfg_path: String, section: String) -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		report(cfg_path, section, "Dialogue file does not exist or cannot be read.", path)
	else:
		while not file.eof_reached():
			var line := file.get_line().strip_edges().trim_prefix("\ufeff")
			if not line.is_empty() and not line.begins_with("#"):
				result.append(line)
		if result.is_empty():
			report(cfg_path, section, "Dialogue file has no dialogue pages.", path)
	if result.is_empty():
		result.append("대화 파일을 확인해 주세요. 8로 오류를 확인할 수 있습니다.")
	return result

func read_portrait(path: String, cfg_path: String, section: String) -> Texture2D:
	# Reading the source image also lets 9 load newly added PNGs without restarting.
	if FileAccess.file_exists(path):
		var image := Image.new()
		var status: int = ERR_UNAVAILABLE
		var bytes := FileAccess.get_file_as_bytes(path)
		match path.get_extension().to_lower():
			"svg": status = image.load_svg_from_string(bytes.get_string_from_utf8())
			"png": status = image.load_png_from_buffer(bytes)
			"jpg", "jpeg": status = image.load_jpg_from_buffer(bytes)
			"webp": status = image.load_webp_from_buffer(bytes)
		if status == OK and not image.is_empty():
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource is Texture2D:
			return resource
	report(cfg_path, section, "Portrait does not exist or is not a readable texture; using placeholder.", path)
	return load(FALLBACK_PORTRAIT)

func load_map(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		report(path, "map", "Map configuration file does not exist.")
		return {}
	# ConfigFile merges repeated sections, so detect duplicates in the source first.
	var section_regex := RegEx.new()
	section_regex.compile("^\\s*\\[([^\\]]+)\\]")
	var seen: Dictionary = {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var match_result := section_regex.search(line.trim_prefix("\ufeff"))
		if match_result == null:
			continue
		var section := match_result.get_string(1).strip_edges()
		if seen.has(section):
			report(path, section, "Duplicate section / NPC or transition ID. Use a unique ID.", section)
			return {}
		seen[section] = true
	var cfg := ConfigFile.new()
	var status := cfg.load(path)
	if status != OK:
		report(path, "file", "Cannot parse CFG. Check quotes, section brackets and '='.", error_string(status))
		return {}
	var id := required_string(cfg, path, "map", "id")
	var scene_path := required_string(cfg, path, "map", "scene")
	var spawn := required_string(cfg, path, "map", "default_spawn")
	if not valid_id(id) or spawn.is_empty() or scene_path.is_empty():
		report(path, "map", "Map id must contain only letters, digits or underscore.", id)
		return {}
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		report(path, "map", "Map scene does not exist.", scene_path)
		return {}
	var npcs: Array[Dictionary] = []
	var transitions: Dictionary = {}
	for section in cfg.get_sections():
		if section.begins_with("npc:"):
			var npc_id := section.trim_prefix("npc:")
			if not valid_id(npc_id):
				report(path, section, "NPC id must contain only letters, digits or underscore.", npc_id)
				continue
			var npc_name := required_string(cfg, path, section, "name")
			var portrait_path := required_string(cfg, path, section, "portrait")
			var dialogue_path := required_string(cfg, path, section, "dialogue")
			var x: Variant = cfg.get_value(section, "position_x") if cfg.has_section_key(section, "position_x") else null
			var y: Variant = cfg.get_value(section, "position_y") if cfg.has_section_key(section, "position_y") else null
			if not (x is int or x is float) or not (y is int or y is float):
				report(path, section, "position_x and position_y must be numbers (without quotes). NPC skipped.", [x, y])
				continue
			if not is_finite(float(x)) or not is_finite(float(y)):
				report(path, section, "NPC coordinates must be finite numbers.", [x, y])
				continue
			if npc_name.is_empty():
				continue
			npcs.append({"id": npc_id, "name": npc_name, "position": Vector2(x, y), "portrait": read_portrait(portrait_path, path, section), "dialogue": read_dialogue(dialogue_path, path, section)})
		elif section.begins_with("transition:"):
			var transition_id := section.trim_prefix("transition:")
			var target := required_string(cfg, path, section, "target_map")
			var target_spawn := required_string(cfg, path, section, "target_spawn")
			if not valid_id(transition_id) or not valid_id(target) or not valid_id(target_spawn):
				report(path, section, "Transition, target_map and target_spawn IDs must contain only letters, digits or underscore.", [transition_id, target, target_spawn])
				continue
			if not FileAccess.file_exists(map_path(target)):
				report(path, section, "target_map does not exist. Transition disabled.", target)
				continue
			transitions[transition_id] = {"target_map": target, "target_spawn": target_spawn}
	var title: Variant = cfg.get_value("map", "title", id)
	return {"id": id, "path": path, "scene": scene_path, "default_spawn": spawn, "title": title if title is String else id, "npcs": npcs, "transitions": transitions}
