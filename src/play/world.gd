class_name World
extends Node3D
## One level of the mine, and everything in it. Runs at a fixed 60 steps a second.

signal level_cleared
signal exit_reached
signal player_dead
signal boss_appeared(boss: Enemy)
signal boss_dead(boss: Enemy)
signal hud_changed
signal said(text: String, at: Vector2, color: Color)
signal scored(amount: int, at: Vector2)

var run: Run
var level: Dictionary
var depth: Dictionary
var map: LevelMap
var view: MapView
var cam: GameCamera
var player: Player
var shots: Shots
var fx: Fx
var lights: LightPool
var gas: Gas
var enemies: Array[Enemy] = []
var props: Array[Prop] = []
var carts: Array[Prop] = []
var pickups: Array[Pickup] = []
var wisps: Array[Wisp] = []
var lamp_nodes := {}
var rng := RandomNumberGenerator.new()
var time := 0.0
var boss: Enemy
var exit_open := false
var finished := false
var shaft: SpriteQuad
var _cage: SpriteQuad
var _exit_frame: SpriteQuad
var _env: WorldEnvironment
var _freeze := 0.0
var _flow_clock := 0.0
var _clear_clock := -1.0
var _restless := false
var _second_shift_left := 0.0
var _first_count := 0
var _killed := 0
var streak := 1
var streak_time := 0.0
var _walls_changed := false
var _ambient := Color.BLACK
var _ambient_scale := 1.0
var paused_for_intro := false
## Just for show, behind the title.
var attract := false
var _finale := false
var _perf_frames := 0
var _perf_sim := 0.0
var _perf_sim_peak := 0.0
var _perf_frame := 0.0
var _perf_frame_peak := 0.0
var _finale_row := 0
var _finale_clock := 0.0


func setup(the_run: Run) -> void:
	run = the_run
	level = run.level()
	depth = run.depth()
	rng.seed = hash([run.seed_value, run.level_index])
	seed(rng.randi())
	if level.boss:
		map = LevelGen.arena(depth.arena, depth, rng, int(depth.arena_pillars))
	else:
		map = LevelGen.dig(depth, int(level.stage), rng)


func _ready() -> void:
	if Game.autoplay:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ambient = depth.ambient
	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0235, 0.0196, 0.0314)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _ambient
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.environment = env
	add_child(_env)
	view = MapView.new()
	add_child(view)
	view.setup(map, depth.id, rng.randi())
	cam = GameCamera.new()
	cam.world = self
	cam.bounds = Rect2(Vector2(LevelGen.MARGIN - 3, LevelGen.MARGIN - 4) * Iso.TILE, Vector2(map.w - (LevelGen.MARGIN - 3) * 2, map.h - (LevelGen.MARGIN - 4) * 2) * Iso.TILE)
	add_child(cam)
	lights = LightPool.new()
	add_child(lights)
	fx = Fx.new()
	fx.world = self
	add_child(fx)
	shots = Shots.new()
	shots.world = self
	add_child(shots)
	gas = Gas.new()
	gas.world = self
	add_child(gas)
	gas.set_color(depth.gas_color)
	_place_props()
	_place_lamps()
	_place_cage()
	player = Player.new()
	add_child(player)
	player.setup(self, Iso.cell_center(map.start_cell) + Vector2(0.0, 2.0))
	player.invulnerable = 1.0
	cam.jump_to(player.pos)
	cam.bounds = cam.bounds
	for i in run.count("ghost"):
		var w := Wisp.new()
		add_child(w)
		w.setup(self, TAU * i / maxf(run.count("ghost"), 1.0))
		wisps.append(w)
	map.flow_from(Iso.cell_of(player.pos))
	if attract:
		_attract_setup()
	elif level.boss:
		_arrive_boss()
	else:
		_populate()
	for c in map.gas_cells:
		gas.sources.append(c)
		gas.puff(Iso.cell_center(c), 1.0, 2)
	# Let it settle into its clouds before anyone sees it.
	for i in 24:
		gas.step(0.25)
	Audio.heat = 0.0


## Behind the title: the ranger, the lamp, and a good many eyes out in the dark.
func _attract_setup() -> void:
	player.controls_locked = true
	player.hard_hat_up = false
	var eyes := 0
	var guard := 0
	while eyes < 9 and guard < 300:
		guard += 1
		var c := Vector2i(rng.randi_range(0, map.w - 1), rng.randi_range(0, map.h - 1))
		var d := Iso.cell_center(c).distance_to(player.pos)
		if map.is_floor(c) and d > 130.0 and d < 330.0:
			var e := spawn_enemy(["rat", "miner", "wraith", "bat", "foreman"][eyes % 5], Iso.cell_center(c))
			e.counted = false
			eyes += 1


func _place_props() -> void:
	for p: Array in map.places:
		var kind: String = p[0]
		var cell: Vector2i = p[1]
		var prop := Prop.new()
		add_child(prop)
		prop.setup(self, kind, cell)
		if kind == "cart":
			prop.setup_cart(p[3], p[4], p[2])
			carts.append(prop)
		props.append(prop)


func _place_lamps() -> void:
	for c in map.lamps:
		var lamp := SpriteQuad.make("wall_lamp", true)
		add_child(lamp)
		var p := Vector2((c.x + 0.5) * Iso.TILE, (c.y + 1) * Iso.TILE)
		lamp.position = Iso.snapped(p, 7.0) + Vector3(0.0, 0.0, 1.0)
		var light := OmniLight3D.new()
		light.light_color = depth.wall_lamp
		light.light_energy = 0.42
		light.omni_range = 130.0
		light.omni_attenuation = 0.0
		light.light_specular = 0.0
		light.position = Iso.at(p + Vector2(0.0, 10.0), 16.0)
		add_child(light)
		lamp_nodes[c] = [lamp, light]


func _place_cage() -> void:
	shaft = SpriteQuad.make("shaft", false)
	shaft.material_override = SpriteQuad.material_for("shaft", true)
	shaft.mesh = _flat_mesh(48.0, 36.0)
	shaft.position = Iso.at(Iso.cell_center(map.exit_cell)) + Vector3(0.0, 0.3, 0.0)
	shaft.visible = false
	add_child(shaft)
	_cage = SpriteQuad.make("cage", false)
	_cage.position = Iso.snapped(Iso.cell_center(map.start_cell) + Vector2(0.0, -6.0))
	_cage.play("open", 0.0)
	add_child(_cage)
	_exit_frame = SpriteQuad.make("cage", false)
	_exit_frame.position = Iso.snapped(Iso.cell_center(map.exit_cell) + Vector2(0.0, -10.0))
	_exit_frame.play("closed", 0.0)
	_exit_frame.visible = not level.boss
	add_child(_exit_frame)


func _flat_mesh(w: float, h: float) -> QuadMesh:
	var m := QuadMesh.new()
	m.orientation = PlaneMesh.FACE_Y
	m.size = Vector2(w, h / Iso.SIN)
	return m


## Fills the level from its budget: a few of what lives at this depth, in clusters, away from the start.
func _populate() -> void:
	var budget := run.budget()
	var pool: Dictionary = depth.pool.duplicate()
	for unlock: Array in depth.unlocks:
		if int(level.stage) >= int(unlock[0]):
			pool[unlock[1]] = int(pool.get(unlock[1], 0)) + int(unlock[2])
	var ids := pool.keys()
	var spawns := map.spawn_cells.duplicate()
	if spawns.is_empty():
		return
	var main_budget := budget * (1.0 - Balance.SECOND_SHIFT_SIZE * 0.5)
	_second_shift_left = budget - main_budget
	var guard := 0
	while main_budget > 0.0 and guard < 200:
		guard += 1
		var id := _pick(ids, pool)
		var cost: float = Enemies.DEFS[id].cost
		if cost > main_budget + 1.0:
			continue
		var cluster := 1
		if cost <= 1.0:
			cluster = rng.randi_range(3, 5)
		elif cost <= 2.0:
			cluster = rng.randi_range(1, 3)
		var at: Vector2i = spawns[rng.randi() % spawns.size()]
		for i in cluster:
			main_budget -= cost
			var offset := Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
			var p := Iso.cell_center(at) + offset
			if map.box_blocked(p, 6.0):
				p = Iso.cell_center(at)
			spawn_enemy(id, p)
	_first_count = enemies.size()


func _pick(ids: Array, pool: Dictionary) -> String:
	var total := 0
	for id: String in ids:
		total += int(pool[id])
	var r := rng.randi_range(1, total)
	for id: String in ids:
		r -= int(pool[id])
		if r <= 0:
			return id
	return ids[0]


func _arrive_boss() -> void:
	var at := Iso.cell_center(Vector2i(map.w / 2, LevelGen.MARGIN + 4))
	if level.depth == 4:
		at = Iso.cell_center(Vector2i(map.w / 2, LevelGen.MARGIN + 5))
	boss = spawn_enemy(depth.boss, at)
	boss.awake = false
	player.invulnerable = Boss.INTRO + 0.5
	boss_appeared.emit(boss)
	# Something to work with: a few kegs round the edge, a crate of powder.
	var kegs := 0
	var guard := 0
	while kegs < 4 and guard < 60:
		guard += 1
		var c := Vector2i(rng.randi_range(LevelGen.MARGIN + 1, map.w - LevelGen.MARGIN - 2), rng.randi_range(LevelGen.MARGIN + 1, map.h - LevelGen.MARGIN - 2))
		if not map.is_floor(c) or map.props.has(c) or (c - map.start_cell).length() < 5.0 or Iso.cell_center(c).distance_to(at) < 60.0:
			continue
		var prop := Prop.new()
		add_child(prop)
		prop.setup(self, "crate" if kegs == 0 else "keg", c)
		props.append(prop)
		kegs += 1


func spawn_enemy(id: String, at: Vector2) -> Enemy:
	var script: Script = load("res://src/play/enemies/%s.gd" % Enemies.DEFS[id].script)
	var e: Enemy = script.new()
	add_child(e)
	e.setup(self, id, at)
	enemies.append(e)
	return e


func _physics_process(dt: float) -> void:
	if finished and player == null:
		return
	if paused_for_intro:
		fx.step(dt)
		lights.step(dt)
		return
	if _freeze > 0.0:
		_freeze -= dt
		return
	time += dt
	if attract:
		_attract_step(dt)
		return
	run.time += dt
	_flow_clock -= dt
	if _flow_clock <= 0.0:
		_flow_clock = Balance.FLOW_INTERVAL
		var c := Iso.cell_of(player.pos)
		if c != map.flow_origin:
			map.flow_from(c)
	player.step(dt)
	_camera_follow()
	for w in wisps:
		w.step(dt)
	var i := enemies.size() - 1
	while i >= 0:
		var e := enemies[i]
		if e.alive:
			e.step(dt)
		i -= 1
	_reap_enemies()
	_separate()
	shots.step(dt)
	_reap_enemies()
	for p in carts:
		p.step(dt)
	i = props.size() - 1
	while i >= 0:
		if props[i].kind == "chest":
			props[i].step(dt)
		i -= 1
	i = pickups.size() - 1
	while i >= 0:
		var p := pickups[i]
		p.step(dt)
		if not p.alive:
			pickups.remove_at(i)
			p.queue_free()
		i -= 1
	gas.step(dt)
	_reap_enemies()
	fx.step(dt)
	lights.step(dt)
	_sync_visuals(dt)
	if _walls_changed:
		_walls_changed = false
		view.flush()
	if _finale and not finished:
		_finale_tick(dt)
	_streak_tick(dt)
	_shift_tick(dt)
	_check_clear(dt)
	_check_exit()
	_music_tick(dt)
	if Game.autoplay:
		_perf_tick()
		if int(time / 10.0) != int((time - dt) / 10.0):
			_debug_report()


## For testing: what the simulation and the whole frame are costing.
func _perf_tick() -> void:
	var sim := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var frame := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_perf_frames += 1
	_perf_sim += sim
	_perf_sim_peak = maxf(_perf_sim_peak, sim)
	_perf_frame += frame
	_perf_frame_peak = maxf(_perf_frame_peak, frame)


## For testing: how a level is going, every ten seconds.
func _debug_report() -> void:
	if _perf_frames > 0:
		var rid := get_viewport().get_viewport_rid()
		print("  perf: %.0f fps; sim %.2f ms avg, %.2f peak; frame %.2f ms avg, %.2f peak; render cpu %.2f gpu %.2f ms; %d draw calls, %d enemies, %d shots" % [Performance.get_monitor(Performance.TIME_FPS), _perf_sim / _perf_frames, _perf_sim_peak, _perf_frame / _perf_frames, _perf_frame_peak,
			RenderingServer.viewport_get_measured_render_time_cpu(rid), RenderingServer.viewport_get_measured_render_time_gpu(rid), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), enemies.size(), shots.list.size()])
	_perf_frames = 0
	_perf_sim = 0.0
	_perf_sim_peak = 0.0
	_perf_frame = 0.0
	_perf_frame_peak = 0.0
	var msg := PackedStringArray()
	for e in enemies:
		msg.append("%s@%d,%d %s steps=%d" % [e.id, int(e.pos.x / 16), int(e.pos.y / 16), "awake" if e.awake else "asleep", map.flow_at(e.pos)])
	print("  t=%.0f player %d,%d exit_open=%s left=%d: %s" % [time, int(player.pos.x / 16), int(player.pos.y / 16), exit_open, enemies.size(), " | ".join(msg.slice(0, 5))])


## Everything that will be drawn once a fight starts, drawn once now behind the title,
## so no shader has to be compiled in the middle of a fight.
func warm_up() -> void:
	var at := player.pos
	fx.play("explosion", at, 2.0, "idle", true, 0.05)
	fx.play("warning", at, 2.0, "idle", true, 0.05)
	fx.sparks(at, 2.0, 2, Color(0.1, 0.1, 0.1), 2.0, 0.05)
	shots.enemy(at, Vector2.RIGHT, 1.0, Shots.SMALL, 1.0, 0.1)
	gas.set_fire(Iso.cell_of(at), 0.1)
	gas.add(Iso.cell_of(at), 0.2)


func _attract_step(dt: float) -> void:
	player.step(dt)
	shots.step(dt)
	player.sync_visual(dt)
	gas.step(dt)
	fx.step(dt)
	lights.step(dt)
	for e in enemies:
		e.anim_time += dt
		e.sync_visual(dt)
		e.sprite.play(e.anim, e.anim_time)
	for p in props:
		p.cast_long_shadow(player.pos, 160.0)
	# Now and then something moves out there.
	if randf() < dt * 0.4:
		fx.sparks(player.pos + Vector2(randf_range(-100, 100), randf_range(-60, 60)), 30.0, 1, Color(1.0, 0.7, 0.3), 12.0, 1.6)


## The dead leave the list before they're freed: nothing is to find a freed enemy in it.
func _reap_enemies() -> void:
	var i := enemies.size() - 1
	while i >= 0:
		var e := enemies[i]
		if not e.alive:
			enemies.remove_at(i)
			e.queue_free()
		i -= 1


func _sync_visuals(dt: float) -> void:
	player.sync_visual(dt)
	for w in wisps:
		w.sync_visual(dt)
	var lamp_at := player.pos
	var reach: float = player.lamp_reach() * 0.62
	for e in enemies:
		e.sync_visual(dt)
		if not e.def.get("boss", false):
			e.cast_long_shadow(lamp_at, reach)
	for p in pickups:
		p.sync_visual(dt)
	for p in carts:
		p.sync_visual(dt)
	for p in props:
		if p.flash_time > 0.0:
			p.sync_visual(dt)
		p.cast_long_shadow(lamp_at, reach)
	if boss:
		boss.cast_long_shadow(lamp_at, reach * 1.3)


func _camera_follow() -> void:
	# The first look at what's at the bottom of the depth.
	if boss and not boss.awake:
		player.controls_locked = true
		cam.target = boss.pos + Vector2(0.0, -8.0)
		return
	if boss and player.controls_locked and not finished:
		player.controls_locked = false
	var look := Vector2.ZERO
	if not player.dead:
		if Inputs.device == Inputs.Device.MOUSE and not Game.autoplay:
			var mouse := get_viewport().get_mouse_position()
			look = (cam.to_floor(mouse) - player.pos).limit_length(190.0) * 0.28
		else:
			look = player.aim * (26.0 if player.firing else 10.0)
	cam.target = player.pos + look + Vector2(0.0, -6.0)


## Keeps a crowd from piling up on one spot.
func _separate() -> void:
	var n := enemies.size()
	for i in n:
		var a := enemies[i]
		if a.flying or not a.awake:
			continue
		for k in range(i + 1, n):
			var b := enemies[k]
			if b.flying or not b.awake:
				continue
			var d := a.pos - b.pos
			var reach: float = a.radius + b.radius
			if absf(d.x) >= reach or absf(d.y) >= reach:
				continue
			var len2 := d.length_squared()
			if len2 >= reach * reach or len2 < 0.001:
				continue
			var push := d / sqrt(len2) * (reach - sqrt(len2)) * 0.35
			if not a.def.get("heavy", false):
				a.pos = map.move(a.pos, push, a.radius * 0.8)
			if not b.def.get("heavy", false):
				b.pos = map.move(b.pos, -push, b.radius * 0.8)


func _streak_tick(dt: float) -> void:
	if streak_time > 0.0:
		streak_time -= dt
		if streak_time <= 0.0:
			streak = 1
			hud_changed.emit()


func streak_break() -> void:
	streak = 1
	streak_time = 0.0


func add_score(amount: int, at := Vector2.INF) -> void:
	run.score += amount * streak
	if at != Vector2.INF:
		scored.emit(amount * streak, at)
	hud_changed.emit()


## Waves and restlessness: nothing lets a level go quiet for long.
func _shift_tick(_dt: float) -> void:
	if level.boss or exit_open or _first_count == 0:
		return
	if _second_shift_left > 0.0 and float(_killed) >= float(_first_count) * Balance.SECOND_SHIFT_AT:
		_second_shift()
	if not _restless and time > Balance.RESTLESS_AFTER:
		_restless = true
		for e in enemies:
			e.wake()


## The second shift: up out of the floor, out of sight of the ranger.
func _second_shift() -> void:
	var left := _second_shift_left
	_second_shift_left = 0.0
	var pool: Dictionary = depth.pool.duplicate()
	var ids := pool.keys()
	var cells: Array[Vector2i] = []
	for c in map.spawn_cells:
		var d := Iso.cell_center(c).distance_to(player.pos)
		if d > 130.0 and d < 330.0:
			cells.append(c)
	if cells.is_empty():
		return
	Audio.play("rumble", -2.0)
	say_at(player.pos, "The second shift", Color("ffb347"))
	cam.kick(0.3)
	var guard := 0
	while left > 0.0 and guard < 60:
		guard += 1
		var id := _pick(ids, pool)
		var cost: float = Enemies.DEFS[id].cost
		left -= cost
		var c: Vector2i = cells[rng.randi() % cells.size()]
		var e := spawn_enemy(id, Iso.cell_center(c) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
		e.wake()
		fx.chips(e.pos, 2.0, 5, Color("5c3a24"), 50.0, 1.0)


func _check_clear(dt: float) -> void:
	if exit_open or finished:
		return
	for e in enemies:
		if e.counted and not e.minion:
			return
	if _second_shift_left > 0.0:
		_second_shift()
		return
	# A breath, then the bell.
	if _clear_clock < 0.0:
		_clear_clock = 0.7
	_clear_clock -= dt
	if _clear_clock <= 0.0:
		_open_exit()


func _open_exit() -> void:
	exit_open = true
	# What's left (a nest's rats) goes back into the dark.
	for e in enemies:
		if not e.counted or e.minion:
			e.die("burn")
	shots.clear_enemy_shots()
	if not level.boss:
		add_score(Balance.STAGE_BONUS)
	if run.has("oil"):
		player.heal(1)
		say_at(player.pos, "+1 wick", Color("9ff0d8"))
	shaft.visible = true
	_exit_frame.play("open", 0.0)
	_exit_frame.visible = true
	lights.flash(Iso.cell_center(map.exit_cell), 10.0, Color(1.0, 0.85, 0.5), 0.9, 180.0, 1.4)
	Audio.play("bell", 0.0)
	level_cleared.emit()


func _check_exit() -> void:
	if not exit_open or finished or player.dead:
		return
	if player.pos.distance_to(Iso.cell_center(map.exit_cell)) < 20.0:
		finished = true
		player.controls_locked = true
		player.vel = Vector2.ZERO
		Audio.play("cage_down", -2.0)
		exit_reached.emit()


func _music_tick(_dt: float) -> void:
	var awake_count := 0
	for e in enemies:
		if e.awake and e.pos.distance_squared_to(player.pos) < 260.0 * 260.0:
			awake_count += 1
	var want := clampf(awake_count / 7.0, 0.0, 1.0)
	if boss:
		want = 1.0
	if exit_open:
		want = 0.0
	Audio.heat = want


# --- what happens ---------------------------------------------------------------

func freeze_for(seconds: float) -> void:
	_freeze = maxf(_freeze, seconds)


func say_at(at: Vector2, text: String, color := Color.WHITE) -> void:
	said.emit(text, at, color)


## Says something the first time it comes up in a shift.
func hint(id: String, at: Vector2, text: String) -> void:
	if not run.hints.has(id):
		run.hints[id] = true
		say_at(at, text, UI.ACCENT)


func hud_refresh() -> void:
	hud_changed.emit()


func nearest_enemy(from: Vector2, within: float) -> Enemy:
	var best: Enemy = null
	var best_d := within * within
	for e in enemies:
		if not e.alive or e.untouchable():
			continue
		var d := e.pos.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best


func wake_near(at: Vector2, reach: float) -> void:
	for e in enemies:
		if e.pos.distance_squared_to(at) < reach * reach:
			e.wake()


func drop(kind: String, at: Vector2) -> void:
	var p := Pickup.new()
	add_child(p)
	p.setup(self, kind, at)
	p.sync_visual(0.0)
	pickups.append(p)


func crate_loot(at: Vector2) -> void:
	var r := rng.randf()
	var scrounger := 2.0 if run.has("scrounge") else 1.0
	if r < 0.28 * scrounger:
		drop("powder", at)
	elif r < 0.28 * scrounger + 0.05:
		drop("oil", at)
	else:
		for i in rng.randi_range(1, 3):
			drop("nugget", at)


func enemy_died(e: Enemy, kind: String) -> void:
	_killed += 1
	run.kills += 1
	if e.counted and not e.minion:
		streak = mini(streak + 1, Balance.STREAK_MAX)
		run.best_streak = maxi(run.best_streak, streak)
		streak_time = Balance.STREAK_TIME
	add_score(int(e.def.score), e.pos)
	fx.blood(e.pos, 9, e.def.blood)
	fx.chips(e.pos, 6.0, 4, e.def.blood, 70.0, 1.5)
	Audio.play("kill", -7.0, randf_range(0.9, 1.15))
	if e.def.get("boss", false):
		_boss_died(e)
		return
	var scrounge := 2.0 if run.has("scrounge") else 1.0
	if rng.randf() < Balance.NUGGET_DROP:
		drop("nugget", e.pos)
	if rng.randf() < Balance.POWDER_DROP * scrounge:
		drop("powder", e.pos)
	if rng.randf() < Balance.OIL_DROP and run.wicks < run.max_wicks:
		drop("oil", e.pos)
	if kind == "blast" and run.has("chain") and e.id != "sapper":
		explode(e.pos, 22.0, 5.0, true, false, false)


func _boss_died(e: Enemy) -> void:
	boss_dead.emit(e)
	freeze_for(0.25)
	cam.kick(1.0)
	shots.clear_enemy_shots()
	for other in enemies:
		if other != e:
			other.die("burn")
	for i in 16:
		drop("nugget", e.pos)
	drop("oil", e.pos)
	drop("oil", e.pos)
	drop("powder", e.pos)
	drop("powder", e.pos)
	boss = null


func remove_prop(p: Prop) -> void:
	props.erase(p)
	carts.erase(p)
	p.queue_free()


func shot_hit_wall(s: Shots.Shot) -> void:
	if s.explosive:
		detonate(s)
		return
	fx.sparks(s.pos, s.h, 2, Color(1.0, 0.85, 0.5), 50.0, 0.18)
	if s.friendly:
		fx.stuck_arrow(s.pos - s.vel.normalized() * 2.0, s.h, s.vel.normalized())
		if s.fire:
			gas.ignite_near(s.pos, 12.0)
		Audio.play("thud", -13.0, randf_range(0.9, 1.2))


func shot_landed(s: Shots.Shot) -> void:
	match s.on_land:
		"gas":
			gas.puff(s.pos, 0.75, 1)
			fx.chips(s.pos, 1.0, 5, Color("6aa03a"), 40.0, 0.6)
			Audio.play("squelch", -9.0, randf_range(1.0, 1.25))
			if player.can_be_hit() and s.pos.distance_to(player.pos) < 12.0:
				player.hurt(1)
		"fire":
			gas.set_fire(Iso.cell_of(s.pos), 2.4)
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				gas.set_fire(Iso.cell_of(s.pos) + d, 1.6)
			gas.ignite_near(s.pos, 16.0)
			fx.sparks(s.pos, 2.0, 8, Color(1.0, 0.6, 0.2), 80.0, 0.4)
			Audio.play("ember", -4.0, 0.8)
			if player.can_be_hit() and s.pos.distance_to(player.pos) < 14.0:
				player.hurt(1)
		"blast":
			explode(s.pos, 32.0, 8.0, false, false)
		"ring":
			shots.ring(s.pos, 8, 80.0, Shots.DROP, randf() * TAU)
			Audio.play("splash", -6.0)
		"rock":
			fx.chips(s.pos, 1.0, 8, Color(0.4, 0.34, 0.3), 70.0, 1.2)
			fx.smoke(s.pos, 3.0, 3, Color(0.24, 0.2, 0.2), 3.0)
			Audio.play("crumble", -10.0, randf_range(1.0, 1.3))
			if player.can_be_hit() and s.pos.distance_to(player.pos) < 13.0:
				player.hurt(1)
		"rat":
			var rat := spawn_enemy("rat", s.pos)
			rat.wake()
			rat.minion = true
	s.alive = false


func detonate(s: Shots.Shot) -> void:
	explode(s.pos, s.blast_radius, s.blast_damage, true, true)
	if run.has("cluster"):
		for i in 3:
			var offset := Vector2.from_angle(TAU * i / 3.0 + randf()) * s.blast_radius * 0.95
			var near := s.pos + offset
			if not map.wall_at(near):
				_later(0.09 * (i + 1), explode.bind(near, s.blast_radius * 0.55, s.blast_damage * 0.5, true, true))


func _later(seconds: float, what: Callable) -> void:
	get_tree().create_timer(seconds, false, true).timeout.connect(func() -> void:
		# What it was to happen to may have gone in the meantime.
		if what.is_valid() and not finished:
			what.call()
	)


## A blast. `friendly` ones don't take a wick off the ranger (they do shove).
func explode(at: Vector2, reach: float, damage: float, friendly: bool, breaks_walls := true, big_noise := true) -> void:
	var scale_by := reach / 34.0
	fx.play("explosion", at, 6.0, "idle", true, scale_by)
	fx.sparks(at, 6.0, int(26 * scale_by), Color(1.0, 0.7, 0.25), 150.0 * scale_by, 0.6)
	fx.smoke(at, 8.0, int(10 * scale_by), Color(0.24, 0.2, 0.2), reach * 0.4)
	lights.flash(at, 22.0, Color(1.0, 0.72, 0.4), 1.6, reach * 6.0, 0.4)
	cam.kick(0.5 * clampf(scale_by, 0.4, 1.3))
	if big_noise:
		freeze_for(0.03)
		Audio.play("boom", -3.0, randf_range(0.9, 1.1))
	else:
		Audio.play("boom", -9.0, randf_range(1.2, 1.4))
	# And the noise of it wakes what's asleep for a long way round.
	wake_near(at, 150.0)
	for e in enemies.duplicate():
		if e.alive and not e.untouchable() and e.pos.distance_to(at) <= reach + e.radius:
			e.hurt(damage, (e.pos - at).normalized(), "blast")
	var to_player_d := player.pos.distance_to(at)
	if to_player_d <= reach * 0.85 + player.radius:
		if not friendly:
			player.hurt(1, (player.pos - at).normalized())
		elif to_player_d > 1.0 and player.roll_time <= 0.0:
			player.pos = map.move(player.pos, (player.pos - at).normalized() * 7.0, player.radius)
	for cell: Vector2i in map.props.keys():
		if map.props.has(cell) and Iso.cell_center(cell).distance_to(at) <= reach + 6.0:
			var prop: Prop = map.props[cell]
			if prop.kind == "keg":
				_later(0.08, prop.destroy)
			else:
				prop.hit(damage)
	for cart in carts:
		if cart.pos.distance_to(at) < reach:
			var axis := Vector2.RIGHT if cart.horizontal else Vector2.DOWN
			cart.speed = clampf(cart.speed + sign((cart.pos - at).dot(axis)) * 200.0, -240.0, 240.0)
	gas.ignite_near(at, reach)
	if breaks_walls:
		_break_walls(at, reach)


func _break_walls(at: Vector2, reach: float) -> void:
	var r: float = minf(reach, Balance.WALL_BREAK_RADIUS * (reach / Balance.BLAST_RADIUS))
	var c := Iso.cell_of(at)
	var cells := ceili(r / Iso.TILE) + 1
	for x in range(-cells, cells + 1):
		for y in range(-cells, cells + 1):
			var n := c + Vector2i(x, y)
			if map.kind(n) == LevelMap.ROCK and Iso.cell_center(n).distance_to(at) <= r + 6.0:
				_blow_out(n)


func _blow_out(c: Vector2i) -> void:
	map.set_kind(c, LevelMap.FLOOR)
	map.cracked.erase(c)
	map.overlays[c] = -1
	run.walls_blown += 1
	view.touch(c)
	_walls_changed = true
	var at := Iso.cell_center(c)
	fx.chips(at, 8.0, 12, Color(0.45, 0.33, 0.27), 110.0, 3.0, 1.0)
	fx.smoke(at, 6.0, 5, Color(0.22, 0.18, 0.18), 7.0)
	# A wall lamp comes down with its wall.
	if lamp_nodes.has(c):
		var pair: Array = lamp_nodes[c]
		pair[0].queue_free()
		pair[1].queue_free()
		lamp_nodes.erase(c)
		map.lamps.erase(c)
	map.flow_origin = Vector2i(-999, -999)
	if rng.randf() < 0.08:
		drop("nugget", at)


## A cell of firedamp catching.
func gas_burst(at: Vector2, how_much: float) -> void:
	fx.sparks(at, 6.0, 4, Color(1.0, 0.8, 0.35), 90.0, 0.4)
	lights.flash(at, 14.0, Color(1.0, 0.75, 0.35), 0.9, 110.0, 0.35)
	if randf() < 0.35:
		cam.kick(0.12)
		Audio.play("whoomp", -5.0, randf_range(0.85, 1.2))
	var reach := 15.0
	for e in enemies:
		if e.alive and e.height < 12.0 and not e.untouchable() and e.pos.distance_to(at) < reach:
			e.hurt(5.0 * (0.5 + how_much), (e.pos - at).normalized(), "blast")
			e.set_burning(1.5)
	if player.can_be_hit() and player.pos.distance_to(at) < reach - 2.0:
		player.hurt(1, (player.pos - at).normalized())
	for cell: Vector2i in map.props.keys():
		if map.props.has(cell) and Iso.cell_center(cell).distance_to(at) < reach:
			var prop: Prop = map.props[cell]
			if prop.kind == "keg":
				_later(0.05, prop.destroy)


## A warning on the floor: something is going to land here, in `seconds`.
func warn(at: Vector2, seconds: float) -> void:
	fx.play("warning", at, 0.0, "idle", true, 1.0, 0.0, seconds)


## A rock coming down from the roof at `at`, in `seconds`.
func falling_rock(at: Vector2, seconds: float) -> void:
	warn(at, seconds)
	var s := shots.enemy(at, Vector2.RIGHT, 0.0, Shots.COAL, 1.0, seconds + 1.0)
	s.lobbed = true
	s.h = 0.5 * 320.0 * seconds * seconds
	s.vh = 0.0
	s.vel = Vector2.ZERO
	s.turns = false
	s.on_land = "rock"


## The end of it all: it's burning from the far end, and the cage is at the near one.
func start_finale() -> void:
	_finale = true
	_finale_row = LevelGen.MARGIN
	_finale_clock = 1.2
	map.exit_cell = map.start_cell
	exit_open = true
	shaft.position = Iso.at(Iso.cell_center(map.exit_cell)) + Vector3(0.0, 0.3, 0.0)
	shaft.visible = true
	_exit_frame.visible = false
	level_cleared.emit()
	Audio.play("rumble", 0.0)
	Audio.play_music("mine", 0.5)


func _finale_tick(dt: float) -> void:
	_finale_clock -= dt
	if _finale_clock > 0.0:
		return
	_finale_clock = 0.42
	cam.kick(0.3)
	Audio.play("whoomp", -2.0, randf_range(0.7, 1.0))
	for x in map.w:
		var c := Vector2i(x, _finale_row)
		if map.is_floor(c):
			gas.set_fire(c, 30.0)
			if x % 3 == 0:
				fx.sparks(Iso.cell_center(c), 6.0, 3, Color(1.0, 0.7, 0.3), 90.0, 0.5)
	_finale_row += 1


func player_died() -> void:
	Audio.heat = 0.0
	streak_break()
	_later(1.6, func() -> void: player_dead.emit())
