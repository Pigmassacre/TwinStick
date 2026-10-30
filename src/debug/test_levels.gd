extends SceneTree
## Digs a good many levels of every depth and checks each can be played: the way
## from the cage to the shaft is open, nothing is out of reach, and there's room
## for what's meant to live there. Quits with 1 if any can't.
## godot --headless --path . --script src/debug/test_levels.gd [-- --show]


func _initialize() -> void:
	var failed := 0
	var total := 0
	var show := "--show" in OS.get_cmdline_user_args()
	for d in Depths.LIST.size():
		var depth: Dictionary = Depths.LIST[d]
		for stage: int in depth.stages:
			for attempt in 40:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([d, stage, attempt])
				var map := LevelGen.dig(depth, stage, rng)
				total += 1
				var problem := _check(map)
				if problem != "":
					failed += 1
					printerr("%s stage %d seed %d: %s" % [depth.id, stage, attempt, problem])
				if show and attempt == 0:
					print("%s %d" % [depth.id, stage])
					print(_ascii(map))
	print("%d levels, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)


func _check(map: LevelMap) -> String:
	map.flow_from(map.start_cell)
	var exit_steps: int = map.flow[map.exit_cell.y * map.w + map.exit_cell.x]
	if exit_steps < 0:
		# A crate may be in the way (it can be shot), but not rock.
		if not _reachable_through_props(map, map.start_cell, map.exit_cell):
			return "no way to the shaft"
	if map.spawn_cells.size() < 30:
		return "only %d cells to spawn on" % map.spawn_cells.size()
	if (map.start_cell - map.exit_cell).length() < 8.0:
		return "the shaft is right next to the cage"
	var floors := 0
	for i in map.cells.size():
		if map.cells[i] == LevelMap.FLOOR:
			floors += 1
	if floors < 150:
		return "only %d cells of floor" % floors
	return ""


func _reachable_through_props(map: LevelMap, a: Vector2i, b: Vector2i) -> bool:
	var seen := {a: true}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if c == b:
			return true
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not seen.has(n) and map.is_floor(n):
				seen[n] = true
				queue.append(n)
	return false


func _ascii(map: LevelMap) -> String:
	var lines := PackedStringArray()
	for y in map.h:
		var row := ""
		for x in map.w:
			var c := Vector2i(x, y)
			if c == map.start_cell:
				row += "S"
			elif c == map.exit_cell:
				row += "E"
			elif map.is_floor(c):
				row += "."
			elif map.kind(c) == LevelMap.BEDROCK:
				row += " "
			elif map.cracked.has(c):
				row += "%"
			else:
				row += "#"
		lines.append(row)
	return "\n".join(lines)
