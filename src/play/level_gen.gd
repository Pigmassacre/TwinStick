class_name LevelGen
## Digs the levels: walkers tunnel through solid rock until there is enough
## mine, rooms are stamped along the way, and then it is furnished.

const MARGIN := 6


## A level of depth `depth` (Depths.LIST), stage `stage` (from 0), from `rng`.
static func dig(depth: Dictionary, stage: int, rng: RandomNumberGenerator) -> LevelMap:
	var size: Vector2i = depth.size + Vector2i(stage * 3, stage * 2)
	var map := LevelMap.new(size.x + MARGIN * 2, size.y + MARGIN * 2, LevelMap.BEDROCK)
	for y in range(MARGIN, MARGIN + size.y):
		for x in range(MARGIN, MARGIN + size.x):
			map.set_kind(Vector2i(x, y), LevelMap.ROCK)
	var inner := Rect2i(MARGIN + 1, MARGIN + 1, size.x - 2, size.y - 2)
	var target := int(inner.get_area() * float(depth.get("open", 0.42)))
	var dug := 0
	var first := Vector2i(inner.position.x + rng.randi_range(2, 6), inner.position.y + inner.size.y / 2 + rng.randi_range(-4, 4))
	if rng.randf() < 0.5:
		first.x = inner.end.x - rng.randi_range(3, 7)
	var walkers: Array = [{"at": first, "dir": _random_dir(rng)}]
	var guard := 0
	while dug < target and guard < 40000:
		guard += 1
		for walker: Dictionary in walkers.duplicate():
			var at: Vector2i = walker.at
			dug += _carve(map, inner, at, 2)
			if rng.randf() < float(depth.get("rooms", 0.035)):
				dug += _room(map, inner, at, rng)
			if rng.randf() < 0.28:
				walker.dir = _random_dir(rng)
			var next: Vector2i = at + walker.dir * rng.randi_range(1, 2)
			if not inner.has_point(next) or not inner.has_point(next + Vector2i.ONE):
				walker.dir = _random_dir(rng)
				next = at
			walker.at = next
			if walkers.size() < 4 and rng.randf() < 0.012:
				walkers.append({"at": at, "dir": _random_dir(rng)})
			elif walkers.size() > 1 and rng.randf() < 0.008:
				walkers.erase(walker)
	_pillars(map, inner, rng, depth)
	_fix_slivers(map, inner)
	map.flow_from(first)
	# The cage arrives at the walkers' start; the way down is as far from it as can be walked.
	map.start_cell = _clear_landing(map, first)
	map.flow_from(map.start_cell)
	var far := _farthest(map)
	# Long way round or not, the shaft is to be a good way off.
	if (far - map.start_cell).length() < 10.0:
		far = Vector2i(map.w - first.x, map.h - first.y)
		_tunnel(map, map.start_cell, far)
		map.flow_from(map.start_cell)
	map.exit_cell = _clear_landing(map, far)
	map.flow_from(map.start_cell)
	_collect_spawns(map)
	_furnish(map, depth, rng)
	_secret(map, inner, rng)
	return map


## A rectangular arena for a boss: `size` cells of floor, with the cage to the south.
static func arena(size: Vector2i, depth: Dictionary, rng: RandomNumberGenerator, pillars := 0) -> LevelMap:
	var map := LevelMap.new(size.x + MARGIN * 2, size.y + MARGIN * 2, LevelMap.BEDROCK)
	for y in range(MARGIN, MARGIN + size.y):
		for x in range(MARGIN, MARGIN + size.x):
			map.set_kind(Vector2i(x, y), LevelMap.FLOOR)
	# The corners are cut off, so it doesn't look built.
	for corner_x: int in [MARGIN, MARGIN + size.x - 1]:
		for corner_y: int in [MARGIN, MARGIN + size.y - 1]:
			map.set_kind(Vector2i(corner_x, corner_y), LevelMap.BEDROCK)
	var placed := 0
	var guard := 0
	while placed < pillars and guard < 100:
		guard += 1
		var c := Vector2i(rng.randi_range(MARGIN + 3, MARGIN + size.x - 4), rng.randi_range(MARGIN + 3, MARGIN + size.y - 6))
		var center := Vector2i(MARGIN + size.x / 2, MARGIN + size.y / 2)
		if (c - center).length() < 4.0:
			continue
		var clear := true
		for x in range(-2, 3):
			for y in range(-2, 3):
				if map.kind(c + Vector2i(x, y)) != LevelMap.FLOOR:
					clear = false
		if clear:
			map.set_kind(c, LevelMap.ROCK)
			placed += 1
	map.start_cell = Vector2i(MARGIN + size.x / 2, MARGIN + size.y - 3)
	map.exit_cell = Vector2i(MARGIN + size.x / 2, MARGIN + 2)
	map.flow_from(map.start_cell)
	for y in range(MARGIN, MARGIN + size.y):
		for x in range(MARGIN, MARGIN + size.x):
			if map.is_floor(Vector2i(x, y)):
				map.spawn_cells.append(Vector2i(x, y))
	for i in 5:
		var c := Vector2i(MARGIN + 2 + (size.x - 5) * i / 4, MARGIN - 1)
		if map.kind(c) != LevelMap.FLOOR:
			map.lamps.append(c)
	if depth.has("id"):
		pass
	return map


static func _random_dir(rng: RandomNumberGenerator) -> Vector2i:
	return [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN][rng.randi() % 4]


static func _carve(map: LevelMap, inner: Rect2i, at: Vector2i, size: int) -> int:
	var dug := 0
	for y in size:
		for x in size:
			var c := at + Vector2i(x, y)
			if inner.has_point(c) and map.kind(c) == LevelMap.ROCK:
				map.set_kind(c, LevelMap.FLOOR)
				dug += 1
	return dug


static func _room(map: LevelMap, inner: Rect2i, at: Vector2i, rng: RandomNumberGenerator) -> int:
	var size := Vector2i(rng.randi_range(5, 10), rng.randi_range(4, 7))
	var dug := 0
	var corner := at - size / 2
	for y in size.y:
		for x in size.x:
			# With the corners rounded off.
			if (x == 0 or x == size.x - 1) and (y == 0 or y == size.y - 1):
				continue
			var c := corner + Vector2i(x, y)
			if inner.has_point(c) and map.kind(c) == LevelMap.ROCK:
				map.set_kind(c, LevelMap.FLOOR)
				dug += 1
	return dug


## Lone pillars in the big rooms: something to get behind.
static func _pillars(map: LevelMap, inner: Rect2i, rng: RandomNumberGenerator, depth: Dictionary) -> void:
	var count := int(depth.get("pillars", 5))
	var guard := 0
	while count > 0 and guard < 400:
		guard += 1
		var c := Vector2i(rng.randi_range(inner.position.x + 2, inner.end.x - 3), rng.randi_range(inner.position.y + 2, inner.end.y - 3))
		var clear := true
		for x in range(-2, 3):
			for y in range(-2, 3):
				if not map.is_floor(c + Vector2i(x, y)):
					clear = false
		if clear:
			map.set_kind(c, LevelMap.ROCK)
			count -= 1


## One-cell gaps nobody can get through are filled in, and one-cell rocks in
## the way of everything are knocked out.
static func _fix_slivers(map: LevelMap, inner: Rect2i) -> void:
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var c := Vector2i(x, y)
			if map.is_floor(c):
				var walls := 0
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if map.is_wall(c + d):
						walls += 1
				if walls >= 3:
					map.set_kind(c, LevelMap.ROCK)


## A plain tunnel, two cells wide, from one place to another.
static func _tunnel(map: LevelMap, a: Vector2i, b: Vector2i) -> void:
	var at := a
	while at != b:
		for x in 2:
			for y in 2:
				if map.kind(at + Vector2i(x, y)) == LevelMap.ROCK:
					map.set_kind(at + Vector2i(x, y), LevelMap.FLOOR)
		if at.x != b.x and (at.y == b.y or randf() < 0.5):
			at.x += signi(b.x - at.x)
		else:
			at.y += signi(b.y - at.y)


## Clears a space the size of the cage around `c`, and returns where it is.
static func _clear_landing(map: LevelMap, c: Vector2i) -> Vector2i:
	var at := Vector2i(clampi(c.x, MARGIN + 3, map.w - MARGIN - 4), clampi(c.y, MARGIN + 3, map.h - MARGIN - 4))
	for y in range(-2, 2):
		for x in range(-2, 3):
			if map.kind(at + Vector2i(x, y)) == LevelMap.ROCK:
				map.set_kind(at + Vector2i(x, y), LevelMap.FLOOR)
	return at


static func _farthest(map: LevelMap) -> Vector2i:
	var best := map.start_cell
	var best_steps := -1
	for y in map.h:
		for x in map.w:
			var steps: int = map.flow[y * map.w + x]
			if steps > best_steps:
				best_steps = steps
				best = Vector2i(x, y)
	return best


static func _collect_spawns(map: LevelMap) -> void:
	map.spawn_cells.clear()
	for y in map.h:
		for x in map.w:
			var c := Vector2i(x, y)
			if map.is_floor(c) and map.flow[y * map.w + x] > 11 and (c - map.exit_cell).length() > 3.0:
				map.spawn_cells.append(c)


## Everything that is not rock: lamps, crates, kegs, rails, ore, gas.
static func _furnish(map: LevelMap, depth: Dictionary, rng: RandomNumberGenerator) -> void:
	var floors: Array[Vector2i] = []
	var north_faces: Array[Vector2i] = []
	for y in map.h:
		for x in map.w:
			var c := Vector2i(x, y)
			if map.is_floor(c):
				if (c - map.start_cell).length() > 4.0 and (c - map.exit_cell).length() > 3.0:
					floors.append(c)
			elif map.is_floor(c + Vector2i.DOWN) and map.kind(c) == LevelMap.ROCK:
				north_faces.append(c)
	# Lamps along the north faces, spaced out: places where the dark lets up.
	north_faces.shuffle()
	var lamp_goal := int(float(floors.size()) * float(depth.get("lamps", 0.012)))
	for c in north_faces:
		if map.lamps.size() >= lamp_goal:
			break
		var near := false
		for other in map.lamps:
			if (other - c).length() < 11.0:
				near = true
				break
		if not near:
			map.lamps.append(c)
	floors.shuffle()
	# A few of everything, against the walls where they can be.
	var counts := {
		"crate": int(floors.size() * float(depth.get("crates", 0.022))),
		"keg": int(floors.size() * float(depth.get("kegs", 0.012))),
		"ore": int(floors.size() * float(depth.get("ore", 0.012))),
	}
	var index := 0
	for what: String in counts:
		var left: int = counts[what]
		while left > 0 and index < floors.size():
			var c: Vector2i = floors[index]
			index += 1
			var walls := 0
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if map.is_wall(c + d):
					walls += 1
			if walls == 0 and rng.randf() < 0.7:
				continue
			if walls >= 2:
				continue
			map.places.append([what, c])
			left -= 1
			# Crates come in stacks.
			if what == "crate" and rng.randf() < 0.45:
				var other: Vector2i = c + _random_dir(rng)
				if map.is_floor(other) and (other - map.start_cell).length() > 4.0:
					map.places.append(["crate", other])
	# Rails down the long runs.
	_lay_rails(map, rng, int(depth.get("rails", 2)))
	# Firedamp seeps from a few spots.
	var gas_goal := int(depth.get("gas", 1))
	var tries := 0
	while gas_goal > 0 and tries < 40 and index < floors.size():
		tries += 1
		var c: Vector2i = floors[index]
		index += 1
		if map.flow[c.y * map.w + c.x] < 10:
			continue
		map.gas_cells.append(c)
		gas_goal -= 1


static func _lay_rails(map: LevelMap, rng: RandomNumberGenerator, runs: int) -> void:
	for run in runs:
		var best: Array[Vector2i] = []
		for attempt in 30:
			var c := Vector2i(rng.randi_range(MARGIN, map.w - MARGIN), rng.randi_range(MARGIN, map.h - MARGIN))
			if not map.is_floor(c):
				continue
			var dir := Vector2i.RIGHT if rng.randf() < 0.65 else Vector2i.DOWN
			var line: Array[Vector2i] = [c]
			for sign_dir: int in [1, -1]:
				var at := c + dir * sign_dir
				while map.is_floor(at) and line.size() < 26:
					if sign_dir > 0:
						line.append(at)
					else:
						line.push_front(at)
					at += dir * sign_dir
			if line.size() > best.size():
				best = line
		if best.size() >= 5:
			var horizontal := best[0].y == best[best.size() - 1].y
			for c in best:
				map.overlays[c] = MapView.OVERLAY_RAIL_H if horizontal else MapView.OVERLAY_RAIL_V
			map.places.append(["cart", best[best.size() / 2], horizontal, best[0], best[best.size() - 1]])


## A sealed room with a chest in it, behind a cracked wall.
static func _secret(map: LevelMap, inner: Rect2i, rng: RandomNumberGenerator) -> void:
	for attempt in 200:
		var c := Vector2i(rng.randi_range(inner.position.x + 2, inner.end.x - 3), rng.randi_range(inner.position.y + 2, inner.end.y - 4))
		# Solid all around, 3 by 3 with a wall of 1 on each side, with floor just south of its south wall.
		var solid := true
		for x in range(-2, 3):
			for y in range(-2, 3):
				if not map.is_wall(c + Vector2i(x, y)):
					solid = false
		if not solid:
			continue
		var door := c + Vector2i(0, 2)
		if not map.is_floor(door + Vector2i.DOWN):
			continue
		for x in range(-1, 2):
			for y in range(-1, 2):
				map.set_kind(c + Vector2i(x, y), LevelMap.FLOOR)
		map.cracked[door] = true
		map.places.append(["chest", c])
		return
