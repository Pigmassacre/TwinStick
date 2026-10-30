class_name Player
extends Actor
## The ranger. Two stances, as the original's art had it: Aim, a fast arrow that
## goes through things; and Demolition, a slow one with a stick of dynamite on it.

enum { AIM, DEMOLITION }

signal stance_changed

var stance := AIM
var aim := Vector2.RIGHT
var firing := false
var facing_left := false
var fire_cooldown := 0.0
var loose_time := 0.0
var attack_time := -1.0
var roll_time := 0.0
var roll_cooldown := 0.0
var roll_dir := Vector2.RIGHT
var invulnerable := 0.0
var hard_hat_up := false
var powder_clock := 0.0
var quickdraw := false
var dead := false
var controls_locked := false
## Dimmed by a snuffer: how much of the lamp is left, for how long.
var snuffed := 0.0
var lamp: OmniLight3D
var lamp_power := 1.0
## The boss that puts lamps out sets this: 0 lit, 1 out.
var lamp_dimmed := 0.0
var flicker_time := 0.0
var trail_time := 0.0
var autopilot: Autopilot
var ghost: SpriteQuad
var _dust_clock := 0.0


func setup(the_world: World, at: Vector2) -> void:
	world = the_world
	pos = at
	radius = Balance.RADIUS
	make_sprite("ranger")
	ghost = SpriteQuad.make_ghost("ranger")
	add_child(ghost)
	hard_hat_up = world.run.has("miner")
	lamp = OmniLight3D.new()
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.06
	lamp.shadow_normal_bias = 1.0
	lamp.light_specular = 0.0
	lamp.omni_attenuation = 0.0
	lamp.light_color = world.depth.lamp
	lamp.position = Vector3(0.0, Balance.LAMP_HEIGHT / Iso.COS, 2.0)
	add_child(lamp)
	if Game.autoplay and not world.attract:
		autopilot = Autopilot.new()
		autopilot.player = self


func can_be_hit() -> bool:
	return not dead and invulnerable <= 0.0 and roll_time <= 0.0


func step(dt: float) -> void:
	if dead:
		_animate(dt)
		return
	var run := world.run
	fire_cooldown -= dt
	loose_time -= dt
	roll_cooldown -= dt
	invulnerable -= dt
	snuffed = maxf(snuffed - dt, 0.0)
	# The powder comes back by itself, slowly.
	powder_clock += dt * (2.0 if world.level.boss else 1.0)
	if powder_clock >= Balance.POWDER_REGEN:
		powder_clock = 0.0
		if run.powder < run.max_powder():
			run.powder += 1
			world.hud_refresh()
	var move := Vector2.ZERO
	var want_roll := false
	var want_swap := false
	firing = false
	if not controls_locked:
		if autopilot:
			autopilot.think(dt)
			move = autopilot.move
			aim = autopilot.aim
			firing = autopilot.fire
			want_roll = autopilot.roll
			want_swap = autopilot.swap
		else:
			move = Inputs.move_vector()
			_read_aim()
			want_roll = Input.is_action_just_pressed("roll") or _touch_pressed("roll")
			want_swap = Input.is_action_just_pressed("stance") or _touch_pressed("stance")
	if want_swap:
		swap_stance()
	if roll_time > 0.0:
		roll_time -= dt
		pos = world.map.move(pos, roll_dir * Balance.ROLL_SPEED * dt, radius)
		trail_time -= dt
		if trail_time <= 0.0:
			trail_time = 0.03
			world.fx.chips(pos, 2.0, 1, Color("941919"), 8.0, 0.25, 2.0)
		vel = Vector2.ZERO
	else:
		var speed := Balance.MOVE_SPEED * (Balance.DEMOLITION_MOVE if stance == DEMOLITION else 1.0)
		vel = move * speed
		pos = world.map.move(pos, vel * dt, radius)
		if want_roll and roll_cooldown <= 0.0:
			_start_roll(move)
	if firing and fire_cooldown <= 0.0 and roll_time <= 0.0:
		_shoot()
	_animate(dt)
	_update_lamp(dt)


var _touch_was := {"roll": false, "stance": false}

func _touch_pressed(what: String) -> bool:
	var now: bool = Inputs.touch_roll if what == "roll" else Inputs.touch_stance
	var was: bool = _touch_was[what]
	_touch_was[what] = now
	return now and not was


func _read_aim() -> void:
	match Inputs.device:
		Inputs.Device.MOUSE:
			var cam: GameCamera = world.cam
			var target := cam.to_floor(world.get_viewport().get_mouse_position(), Balance.ARROW_HEIGHT)
			var to := target - pos
			if to.length() > 2.0:
				aim = to.normalized()
			firing = Input.is_action_pressed("fire")
		Inputs.Device.PAD:
			var stick := Inputs.pad_aim()
			if stick != Vector2.ZERO:
				aim = _assisted(stick)
				firing = true
			elif Input.is_action_pressed("fire"):
				aim = _assisted(Inputs.last_pad_aim)
				firing = true
		Inputs.Device.KEYBOARD:
			var keys := Inputs.key_aim()
			if keys != Vector2.ZERO:
				aim = _assisted(keys)
				firing = true
		Inputs.Device.TOUCH:
			if Inputs.touch_aim.length() > 0.3:
				aim = _assisted(Inputs.touch_aim.normalized())
				firing = true


## A little help to those without a mouse: arrows bend to what's nearly in line.
func _assisted(dir: Vector2) -> Vector2:
	if not Game.settings.aim_assist:
		return dir
	var best: Enemy = null
	var best_score := 0.32
	for e: Enemy in world.enemies:
		if not e.alive or e.untouchable():
			continue
		var to := e.pos - pos
		var dist := to.length()
		if dist > 210.0 or dist < 1.0:
			continue
		var off := absf(dir.angle_to(to))
		if off < best_score and world.map.line_clear(pos, e.pos):
			best_score = off
			best = e
	return (best.pos - pos).normalized() if best else dir


func swap_stance() -> void:
	stance = DEMOLITION if stance == AIM else AIM
	if world.run.has("swap"):
		quickdraw = true
		fire_cooldown = 0.0
	Audio.play("stance", -3.0, 1.0 if stance == AIM else 0.8)
	stance_changed.emit()
	world.hud_refresh()


func _start_roll(move: Vector2) -> void:
	roll_dir = move.normalized() if move.length() > 0.1 else aim
	roll_time = Balance.ROLL_TIME
	roll_cooldown = world.run.roll_cooldown()
	Audio.play("roll", -4.0, randf_range(0.95, 1.1))
	world.fx.smoke(pos, 2.0, 5, Color(0.3, 0.26, 0.24), 3.0)
	if world.run.has("flare"):
		world.fx.sparks(pos, 8.0, 14, Color(1.0, 1.0, 0.8), 160.0, 0.25)
		world.lights.flash(pos, 16.0, Color(1.0, 1.0, 0.8), 1.0, 120.0, 0.25)
		Audio.play("flare", -6.0)
		for e: Enemy in world.enemies:
			if e.pos.distance_to(pos) < 70.0:
				e.stun(1.0)


func _shoot() -> void:
	if stance == AIM:
		_shoot_arrows()
	else:
		_shoot_charge()


## Where shots start. In the ranger's own space, so what's right up close still gets hit.
func _muzzle() -> Vector2:
	return pos + aim * 1.0


func _shoot_arrows() -> void:
	var run := world.run
	fire_cooldown = run.arrow_cooldown()
	loose_time = 0.07
	var count := 1 + run.count("twin")
	var damage := run.arrow_damage()
	if run.has("nerve") and run.wicks <= 1:
		damage *= 2.0
	if quickdraw:
		damage *= 3.0
		quickdraw = false
		world.fx.sparks(_muzzle(), Balance.ARROW_HEIGHT, 8, Color(1.0, 0.95, 0.6), 100.0, 0.2, aim, 0.8)
	for i in count:
		var t := 0.0 if count == 1 else float(i) / (count - 1) - 0.5
		var dir := aim.rotated(t * Balance.TWIN_FAN * (count - 1) + randf_range(-Balance.ARROW_SPREAD, Balance.ARROW_SPREAD))
		_arrow(dir, damage, i == 0)
	if run.has("back"):
		_arrow(-aim, damage, false)
	Audio.play("bow", -7.0, randf_range(0.94, 1.08))


func _arrow(dir: Vector2, damage: float, with_light: bool) -> void:
	var run := world.run
	if with_light:
		world.fx.sparks(_muzzle(), Balance.ARROW_HEIGHT, 1, Color(1.0, 0.9, 0.6), 60.0, 0.1, dir, 0.5)
	var s := Shots.Shot.new()
	s.friendly = true
	s.pos = _muzzle()
	s.vel = dir * Balance.ARROW_SPEED
	s.h = Balance.ARROW_HEIGHT
	s.life = Balance.ARROW_LIFE
	s.damage = damage
	s.frame = Shots.ARROW
	s.pierce = 1 + run.count("pierce")
	s.bounces = run.count("bounce")
	s.homing = 3.2 if run.has("homing") else 0.0
	s.fire = run.has("fire")
	if s.fire:
		s.frame = Shots.FIRE_ARROW
	elif run.has("heavy"):
		s.frame = Shots.HEAVY_ARROW
	world.shots.list.append(s)
	if with_light:
		var color := Color(1.0, 0.55, 0.25) if s.fire else Color(1.0, 0.9, 0.7)
		world.lights.attach(s, color, 0.34, 60.0)


func _shoot_charge() -> void:
	var run := world.run
	if run.powder <= 0:
		Audio.play("dry", -2.0)
		world.say_at(pos, "No powder")
		fire_cooldown = 0.3
		swap_stance()
		return
	run.powder -= 1
	world.hud_refresh()
	fire_cooldown = Balance.CHARGE_COOLDOWN * pow(0.9, run.count("quick"))
	attack_time = 0.0
	var s := Shots.Shot.new()
	s.friendly = true
	s.pos = _muzzle()
	s.vel = aim * Balance.CHARGE_SPEED
	s.h = Balance.ARROW_HEIGHT
	s.life = Balance.CHARGE_LIFE
	# With a mouse, it goes off at the crosshair.
	if not autopilot and Inputs.device == Inputs.Device.MOUSE:
		var target: Vector2 = world.cam.to_floor(world.get_viewport().get_mouse_position(), Balance.ARROW_HEIGHT)
		s.life = minf(s.life, maxf(pos.distance_to(target) / Balance.CHARGE_SPEED, 0.08))
	s.frame = Shots.CHARGE
	s.explosive = true
	s.blast_radius = run.blast_radius()
	s.blast_damage = run.blast_damage()
	if quickdraw:
		s.blast_damage *= 3.0
		quickdraw = false
	world.shots.list.append(s)
	world.lights.attach(s, Color(1.0, 0.6, 0.3), 0.5, 80.0)
	Audio.play("bow_heavy", -4.0, randf_range(0.95, 1.05))
	world.cam.kick(0.12)


func hurt(amount: int, from := Vector2.ZERO) -> void:
	if not can_be_hit() or Game.autoplay_invincible:
		return
	var run := world.run
	if hard_hat_up:
		hard_hat_up = false
		invulnerable = 0.8
		Audio.play("clang", -2.0)
		world.fx.sparks(pos, 14.0, 12, Color(1.0, 0.9, 0.5), 110.0, 0.3)
		world.say_at(pos, "Hard hat!")
		world.hud_refresh()
		return
	run.wicks -= amount
	run.hits_taken += 1
	invulnerable = Balance.INVULNERABLE_AFTER_HIT
	flash(Color(1.0, 0.25, 0.2), 0.14)
	world.cam.kick(0.55)
	world.freeze_for(0.07)
	world.fx.blood(pos, 8, Color("941919"), from)
	world.streak_break()
	_shove_back()
	Audio.play("hurt", 0.0, randf_range(0.95, 1.05))
	if from != Vector2.ZERO:
		pos = world.map.move(pos, from * 9.0, radius)
	if run.wicks <= 0:
		if run.has("second") and not run.second_wind_used:
			run.second_wind_used = true
			run.wicks = 1
			invulnerable = 2.0
			world.say_at(pos, "Second wind!")
			world.explode(pos, 60.0, 14.0, true, false)
			world.shots.clear_enemy_shots()
		else:
			_die()
	world.hud_refresh()


## The lamp flares as it's hit, and what's right on top of the ranger is thrown off.
func _shove_back() -> void:
	world.lights.flash(pos, 18.0, Color(1.0, 0.8, 0.5), 0.7, 90.0, 0.2)
	world.fx.sparks(pos, 12.0, 10, Color(1.0, 0.8, 0.5), 110.0, 0.25)
	for e: Enemy in world.enemies:
		if not e.alive or e.untouchable():
			continue
		var d := e.pos - pos
		if d.length() < Balance.HIT_SHOVE_REACH:
			if not e.def.get("heavy", false):
				e.knock += d.normalized() * Balance.HIT_SHOVE
			e.stun(Balance.HIT_STUN)


func _die() -> void:
	dead = true
	run_wicks_out()
	world.player_died()


func run_wicks_out() -> void:
	vel = Vector2.ZERO
	Audio.play("lamp_out", 0.0)


func heal(amount: int) -> void:
	var run := world.run
	run.wicks = mini(run.wicks + amount, run.max_wicks)
	world.hud_refresh()


func _animate(dt: float) -> void:
	anim_time += dt
	if absf(aim.x) > 0.15 and (firing or vel.length() < 1.0):
		facing_left = aim.x < 0.0
	elif absf(vel.x) > 1.0:
		facing_left = vel.x < 0.0
	sprite.set_flip(facing_left)
	var moving := vel.length() > 2.0
	if dead:
		sprite.play("idle", 0.0)
		sprite.set_tint(Color(0.5, 0.5, 0.55))
	elif roll_time > 0.0:
		# Low and fast, the cloak out behind: the run, squashed and flickering.
		sprite.play("run", anim_time * 2.0)
	elif attack_time >= 0.0:
		attack_time += dt
		if attack_time >= sprite.anim_length("attack"):
			attack_time = -1.0
		sprite.play("attack", attack_time)
	elif firing:
		if moving:
			sprite.play("run_loose" if loose_time > 0.0 else "run_draw", anim_time)
		else:
			sprite.play("loose" if loose_time > 0.0 else "draw", 0.0)
	elif moving:
		sprite.play("run", anim_time)
	else:
		sprite.play("idle", anim_time)
	# Blink while nothing can touch it.
	if invulnerable > 0.0 and not dead:
		sprite.visible = int(invulnerable * 16.0) % 2 == 0
	else:
		sprite.visible = true
	var roll_squash := 0.65 if roll_time > 0.0 else 1.0
	sprite.scale.y = roll_squash
	ghost.show_frame(sprite.frame)
	ghost.set_flip(facing_left)
	ghost.scale.y = roll_squash
	# Dust at its heels.
	if moving and not dead and roll_time <= 0.0:
		_dust_clock -= dt
		if _dust_clock <= 0.0:
			_dust_clock = 0.21
			world.fx.chips(pos + Vector2(randf_range(-3.0, 3.0), 0.0), 0.5, 1, world.depth.get("dust", Color(0.4, 0.3, 0.26)), 14.0, 0.45)


## The lamp: as bright as the wicks left in it. A shaking flame.
func _update_lamp(dt: float) -> void:
	var run := world.run
	var share := float(maxi(run.wicks - 1, 0)) / maxf(run.max_wicks - 1.0, 1.0)
	var reach := lerpf(Balance.LAMP_RANGE_LAST, Balance.LAMP_RANGE_FULL, share) * run.lamp_scale()
	flicker_time += dt
	var shake := sin(flicker_time * 11.0) * 0.5 + sin(flicker_time * 23.7) * 0.3 + sin(flicker_time * 3.1) * 0.2
	# The last wick gutters.
	var gutter := 0.09 if run.wicks <= 1 else 0.035
	var power := 1.0 + shake * gutter
	if snuffed > 0.0:
		power *= 0.45
		reach *= 0.55
	reach *= 1.0 - lamp_dimmed * 0.82
	power *= 1.0 - lamp_dimmed * 0.5
	if dead:
		lamp_power = move_toward(lamp_power, 0.0, dt * 0.7)
	lamp.omni_range = reach * (0.3 + lamp_power * 0.7)
	lamp.light_energy = Balance.LAMP_ENERGY * power * lamp_power


func lamp_reach() -> float:
	return lamp.omni_range
