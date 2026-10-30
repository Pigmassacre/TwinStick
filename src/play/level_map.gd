class_name LevelMap
extends RefCounted
## The mine as a grid of cells: what is solid, what can be blown up, what lies
## on the floor. Everything that moves asks this where it can go.

enum { ROCK, FLOOR, BEDROCK }

var w := 0
var h := 0
var cells := PackedByteArray()
## Rails and such on the floor: cell -> overlay index (MapView.OVERLAY_*).
var overlays := {}
## A wall with a crack in it: there is something behind it.
var cracked := {}
## Solid things standing in a cell (crates, kegs): cell -> Prop.
var props := {}
## Where the level starts and ends (the cage arrives, the shaft opens).
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
## What the generator would like placed: [kind, cell].
var places: Array = []
## Cells of floor enemies may start on, far enough from the start.
var spawn_cells: Array[Vector2i] = []
## Wall cells with a lamp on their face.
var lamps: Array[Vector2i] = []
## Cells firedamp seeps from.
var gas_cells: Array[Vector2i] = []
## The way to the player: each cell's steps from them (filled by flow_from).
var flow := PackedInt32Array()
var flow_origin := Vector2i(-999, -999)
var _queue := PackedInt32Array()


func _init(width: int, height: int, fill := ROCK) -> void:
	w = width
	h = height
	cells.resize(w * h)
	cells.fill(fill)
	flow.resize(w * h)
	_queue.resize(w * h)


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func kind(c: Vector2i) -> int:
	return cells[c.y * w + c.x] if inside(c) else BEDROCK


func set_kind(c: Vector2i, value: int) -> void:
	if inside(c):
		cells[c.y * w + c.x] = value


func is_floor(c: Vector2i) -> bool:
	return kind(c) == FLOOR


## Rock and bedrock: walls, whatever stands in the cell.
func is_wall(c: Vector2i) -> bool:
	return kind(c) != FLOOR


## Can't be walked through.
func is_solid(c: Vector2i) -> bool:
	return kind(c) != FLOOR or props.has(c)


func solid_at(p: Vector2) -> bool:
	return is_solid(Vector2i(floori(p.x / Iso.TILE), floori(p.y / Iso.TILE)))


func wall_at(p: Vector2) -> bool:
	return is_wall(Vector2i(floori(p.x / Iso.TILE), floori(p.y / Iso.TILE)))


## Whether a box `r` from `p` each way hits anything solid.
func box_blocked(p: Vector2, r: float) -> bool:
	var x0 := floori((p.x - r) / Iso.TILE)
	var x1 := floori((p.x + r) / Iso.TILE)
	var y0 := floori((p.y - r) / Iso.TILE)
	var y1 := floori((p.y + r) / Iso.TILE)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if is_solid(Vector2i(x, y)):
				return true
	return false


## Moves a box `r` from `p` each way by `delta`, sliding along what it hits.
func move(p: Vector2, delta: Vector2, r: float) -> Vector2:
	var out := p
	# Long steps are cut up, so nothing tunnels through a wall.
	var steps := maxi(1, ceili(delta.length() / (Iso.TILE * 0.5)))
	var step := delta / steps
	for i in steps:
		var nx := Vector2(out.x + step.x, out.y)
		if not box_blocked(nx, r):
			out = nx
		var ny := Vector2(out.x, out.y + step.y)
		if not box_blocked(ny, r):
			out = ny
	return out


## Whether a straight line from `a` to `b` meets no wall (props don't stop it).
func line_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var dist := d.length()
	if dist < 1.0:
		return true
	var steps := ceili(dist / 6.0)
	for i in range(1, steps):
		if wall_at(a + d * (float(i) / steps)):
			return false
	return not wall_at(b)


## Lays the way to `origin` over the map: flow[] says how many steps each cell is from it.
func flow_from(origin: Vector2i) -> void:
	flow_origin = origin
	flow.fill(-1)
	if not inside(origin):
		return
	var head := 0
	var tail := 0
	var first := origin.y * w + origin.x
	flow[first] = 0
	_queue[tail] = first
	tail += 1
	var cell_kinds := cells
	var cell_flow := flow
	var queue := _queue
	while head < tail:
		var i: int = queue[head]
		head += 1
		var next: int = cell_flow[i] + 1
		for n: int in [i - 1, i + 1, i - w, i + w]:
			if n < 0 or n >= cell_kinds.size() or cell_flow[n] != -1:
				continue
			if cell_kinds[n] != FLOOR or props.has(Vector2i(n % w, n / w)):
				continue
			cell_flow[n] = next
			queue[tail] = n
			tail += 1


## How far `p` is from the player, in steps along the floor (-1: no way there).
func flow_at(p: Vector2) -> int:
	var c := Iso.cell_of(p)
	return flow[c.y * w + c.x] if inside(c) else -1


## The way to walk from `p` to get to the player.
func flow_dir(p: Vector2) -> Vector2:
	var c := Iso.cell_of(p)
	if not inside(c):
		return Vector2.ZERO
	var best: int = flow[c.y * w + c.x]
	if best == -1:
		best = 1 << 30
	var dir := Vector2.ZERO
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var n := Vector2i(c.x + x, c.y + y)
			if not inside(n):
				continue
			var value: int = flow[n.y * w + n.x]
			if value < 0 or value >= best:
				continue
			# Not across a corner.
			if x != 0 and y != 0 and (is_solid(Vector2i(c.x + x, c.y)) or is_solid(Vector2i(c.x, c.y + y))):
				continue
			if is_solid(n):
				continue
			best = value
			dir = Vector2(x, y)
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	# Toward the middle of the next cell, not its corner.
	return (Iso.cell_center(c + Vector2i(dir)) - p).normalized()
