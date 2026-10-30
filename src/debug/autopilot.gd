class_name Autopilot
extends RefCounted
## Plays the game by itself (`--autoplay`), for testing without a player: goes
## for what's nearest, keeps out of reach, rolls away from what's coming,
## shoots what it can see, and walks to the shaft when it opens.

var player: Player
var move := Vector2.ZERO
var aim := Vector2.RIGHT
var fire := false
var roll := false
var swap := false
var _wander := Vector2.ZERO
var _wander_time := 0.0
var _stuck_time := 0.0
var _last_pos := Vector2.ZERO
var _swap_clock := 0.0


func think(dt: float) -> void:
	var world: World = player.world
	roll = false
	swap = false
	fire = false
	var target: Enemy = world.nearest_enemy(player.pos, 1000.0)
	var goal := Vector2.ZERO
	var has_goal := false
	if world.exit_open:
		goal = Iso.cell_center(world.map.exit_cell)
		has_goal = true
	elif target:
		goal = target.pos
		has_goal = true
	move = Vector2.ZERO
	if has_goal:
		var dist := goal.distance_to(player.pos)
		var in_sight := target != null and world.map.line_clear(player.pos, target.pos)
		if world.exit_open or not in_sight or dist > 110.0:
			move = _path_to(goal)
		elif dist < 60.0:
			move = (player.pos - goal).normalized()
		else:
			move = (player.pos - goal).normalized().orthogonal()
		if target and in_sight and target.pos.distance_to(player.pos) < 240.0 and not target.untouchable():
			aim = (target.pos - player.pos).normalized()
			fire = true
	# Out of reach of what's on top of it.
	if target and target.pos.distance_to(player.pos) < 26.0 and player.roll_cooldown <= 0.0 and not target.untouchable():
		move = (player.pos - target.pos).normalized()
		roll = true
	# Away from what's flying at it.
	var danger := Vector2.ZERO
	for s: Shots.Shot in world.shots.list:
		if s.friendly:
			continue
		var d := player.pos - s.pos
		if d.length() < 50.0 and s.vel.dot(d) > 0.0:
			danger += s.vel.orthogonal().normalized() * (1.0 if d.cross(s.vel) > 0.0 else -1.0)
	if danger != Vector2.ZERO:
		move = (move + danger.normalized() * 2.0).normalized()
		if player.roll_cooldown <= 0.0 and randf() < 0.1:
			roll = true
	if world.gas.burning_at(player.pos + move * 16.0):
		move = -move
	# Stuck: try somewhere else for a moment.
	if player.pos.distance_to(_last_pos) < 0.4:
		_stuck_time += dt
	else:
		_stuck_time = 0.0
	_last_pos = player.pos
	if _stuck_time > 0.5:
		_wander = Vector2.from_angle(randf() * TAU)
		_wander_time = 0.5
		_stuck_time = 0.0
	if _wander_time > 0.0:
		_wander_time -= dt
		move = _wander
	# Switch to blow things up now and then.
	_swap_clock -= dt
	if _swap_clock <= 0.0:
		_swap_clock = randf_range(2.5, 6.0)
		var armoured: bool = target != null and (target.def.get("reflects", false) or target.def.has("armour") or target.def.get("boss", false))
		var want_demolition: bool = world.run.powder > 2 and (armoured or randf() < 0.2)
		if want_demolition != (player.stance == Player.DEMOLITION):
			swap = true


func _path_to(goal: Vector2) -> Vector2:
	var world: World = player.world
	# The world's flow field goes to the ranger, so it's walked backwards for
	# anything else, in a straight line when it can be.
	if world.map.line_clear(player.pos, goal):
		return (goal - player.pos).normalized()
	var c := Iso.cell_of(player.pos)
	var path := _bfs(c, Iso.cell_of(goal))
	if path != Vector2i(-1, -1):
		return (Iso.cell_center(path) - player.pos).normalized()
	return (goal - player.pos).normalized()


## The first step of the way from `a` to `b`.
func _bfs(a: Vector2i, b: Vector2i) -> Vector2i:
	var map: LevelMap = player.world.map
	var came := {a: a}
	var queue: Array[Vector2i] = [a]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == b:
			var step := c
			while came[step] != a:
				step = came[step]
			return step
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not came.has(n) and not map.is_solid(n):
				came[n] = c
				queue.append(n)
	return Vector2i(-1, -1)
