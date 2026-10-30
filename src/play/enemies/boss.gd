class_name Boss
extends Enemy
## The thing at the bottom of each depth. Stands there a moment to be looked at,
## then goes through its attacks, one after the other. Doesn't die all at once.

const INTRO := 1.6

var attack := ""
var attack_time := 0.0
var rest := 1.0
var dying := false
var dying_time := 0.0
var last_attack := ""
## 1 to 3: how far gone it is. Comes with the health.
var phase := 1


func _sleep(dt: float) -> void:
	timer += dt
	if timer > INTRO:
		wake()
		Audio.play("roar", -2.0)
		world.cam.kick(0.45)


func step(dt: float) -> void:
	if dying:
		_dying_step(dt)
		return
	super.step(dt)


func think(dt: float) -> void:
	var share := hp / max_hp
	phase = 1 if share > 0.66 else (2 if share > 0.33 else 3)
	if attack == "":
		rest -= dt
		walk(dt)
		if rest <= 0.0:
			attack = choose_attack()
			last_attack = attack
			attack_time = 0.0
			begin_attack(attack)
	else:
		attack_time += dt
		if do_attack(attack, dt):
			attack = ""
			rest = rest_time()


## Overridden: what it does between attacks.
func walk(_dt: float) -> void:
	pass


## Overridden: the next one, usually not the last one.
func choose_attack() -> String:
	return ""


func begin_attack(_which: String) -> void:
	pass


## Overridden: carries on with the attack; true when it's over.
func do_attack(_which: String, _dt: float) -> bool:
	return true


func rest_time() -> float:
	return randf_range(0.9, 1.5) / (1.0 + (phase - 1) * 0.25)


func pick(options: Array) -> String:
	var open := options.filter(func(o: String) -> bool: return o != last_attack)
	return open[randi() % open.size()] if not open.is_empty() else options[0]


## Arrows that don't count, a blast that does.
func die(_kind := "arrow") -> void:
	if dying or not alive:
		return
	dying = true
	world.shots.clear_enemy_shots()
	Audio.play("boss_die", 0.0)
	flash(Color.WHITE, 0.2)
	on_dying()


## Overridden: as it starts to die.
func on_dying() -> void:
	pass


func untouchable() -> bool:
	return dying


func _dying_step(dt: float) -> void:
	dying_time += dt
	anim_time += dt * 0.3
	_show(dt)
	position = Iso.snapped(pos + Vector2(randf_range(-2.0, 2.0), 0.0), height)
	if int(dying_time * 7.0) != int((dying_time - dt) * 7.0):
		var at := pos + Vector2(randf_range(-radius, radius), randf_range(-radius * 0.6, radius * 0.6))
		world.fx.play("explosion", at, randf_range(4.0, 26.0), "idle", true, randf_range(0.4, 0.8))
		world.fx.sparks(at, 10.0, 12, Color(1.0, 0.8, 0.4), 120.0, 0.5)
		world.fx.blood(at, 8, def.blood)
		world.cam.kick(0.25)
		Audio.play("boom", -6.0, randf_range(1.1, 1.4))
		flash(Color.WHITE, 0.05)
	if dying_time > 2.0:
		world.fx.play("explosion", pos, 12.0, "idle", true, 2.2)
		world.lights.flash(pos, 30.0, Color(1.0, 0.8, 0.5), 2.0, 340.0, 0.8)
		Audio.play("big_boom", 0.0)
		world.cam.kick(1.0)
		_finish()


func _finish() -> void:
	alive = false
	visible = false
	world.enemy_died(self, "blast")


func summon(id: String, at: Vector2) -> Enemy:
	var e: Enemy = world.spawn_enemy(id, at)
	e.minion = true
	e.counted = false
	e.wake()
	world.fx.smoke(at, 3.0, 5, Color(0.3, 0.26, 0.24), 5.0)
	return e


## Somewhere along the edge of the arena, away from the ranger.
func edge_spot() -> Vector2:
	for attempt in 12:
		var c := Vector2i(randi_range(LevelGen.MARGIN + 1, world.map.w - LevelGen.MARGIN - 2), randi_range(LevelGen.MARGIN + 1, world.map.h - LevelGen.MARGIN - 2))
		if randf() < 0.5:
			c.x = LevelGen.MARGIN + 1 if randf() < 0.5 else world.map.w - LevelGen.MARGIN - 2
		else:
			c.y = LevelGen.MARGIN + 1 if randf() < 0.5 else world.map.h - LevelGen.MARGIN - 2
		var p := Iso.cell_center(c)
		if world.map.is_floor(c) and p.distance_to(world.player.pos) > 70.0:
			return p
	return pos


## A random bit of the arena's floor.
func floor_spot() -> Vector2:
	for attempt in 16:
		var c := Vector2i(randi_range(LevelGen.MARGIN + 1, world.map.w - LevelGen.MARGIN - 2), randi_range(LevelGen.MARGIN + 1, world.map.h - LevelGen.MARGIN - 2))
		if world.map.is_floor(c) and not world.map.props.has(c):
			return Iso.cell_center(c)
	return pos
