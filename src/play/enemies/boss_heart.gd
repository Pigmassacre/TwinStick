extends Boss
## The Firedamp. The seam itself, breathing gas into the workings. It's too thick
## to shoot through until it's on fire: flood the room, get well back, light it.
## Then, for just so long, it's open.

const OPEN_TIME := 6.5
const VENT_EVERY := 0.28

var open_left := 0.0
var _vent_clock := 0.0
var _clock := 0.0
var _spin := 0.0
var _count := 0
var _beat := 0.0
var _pulse_light: OmniLight3D


func init() -> void:
	_pulse_light = OmniLight3D.new()
	_pulse_light.light_color = Color(0.7, 1.0, 0.35)
	_pulse_light.light_energy = 0.5
	_pulse_light.omni_range = 220.0
	_pulse_light.omni_attenuation = 0.0
	_pulse_light.light_specular = 0.0
	_pulse_light.position = Vector3(0.0, 40.0 / Iso.COS, 16.0)
	add_child(_pulse_light)
	world.gas.sources.clear()


func walk(_dt: float) -> void:
	pass


func _contact() -> void:
	super._contact()


func choose_attack() -> String:
	var options := ["ring", "lob", "spiral"]
	if phase >= 2:
		options.append("spawn")
	if phase >= 3:
		options.append("rays")
	return pick(options)


func begin_attack(which: String) -> void:
	_clock = 0.0
	match which:
		"ring":
			_count = 2 + phase
			Audio.play("heartbeat", 0.0, 0.7)
		"lob":
			_count = 3 + phase
			Audio.play("spit", -2.0, 0.6)
		"spiral":
			_spin = randf() * TAU
			Audio.play("banish", -4.0, 0.7)
		"spawn":
			Audio.play("squelch", 0.0, 0.6)
		"rays":
			_spin = randf() * TAU
			Audio.play("dark", -4.0)


func do_attack(which: String, dt: float) -> bool:
	_clock -= dt
	match which:
		"ring":
			if _clock <= 0.0:
				_clock = 0.65
				_count -= 1
				world.shots.ring(pos, 20, 66.0, Shots.GAS, _count * 0.15)
				Audio.play("heartbeat", -2.0, 0.8)
				world.cam.kick(0.2)
			return _count <= 0
		"lob":
			if _clock <= 0.0:
				_clock = 0.24
				_count -= 1
				var to: Vector2 = world.player.pos + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 60.0)
				world.shots.lob(pos + Vector2(randf_range(-20, 20), 0.0), to, 0.9, Shots.SPIT, "gas", 70.0)
				Audio.play("spit", -8.0, randf_range(0.6, 0.9))
			return _count <= 0
		"spiral":
			if _clock <= 0.0:
				_clock = 0.09
				_spin += 0.27
				for arm in 2:
					world.shots.enemy(pos, Vector2.from_angle(_spin + PI * arm), 76.0, Shots.BOSS_ORB)
			return attack_time > 2.6
		"spawn":
			if attack_time > 0.4:
				var kinds := ["sapper", "blister", "sapper"]
				for i in phase:
					summon(kinds[randi() % kinds.size()], edge_spot())
				return true
		"rays":
			if _clock <= 0.0:
				_clock = 0.12
				_spin += 0.13
				for arm in 5:
					world.shots.enemy(pos, Vector2.from_angle(_spin + TAU * arm / 5.0), 88.0, Shots.GAS)
			return attack_time > 3.0
	return false


func step(dt: float) -> void:
	super.step(dt)
	if dying or not awake:
		return
	# It breathes: the room slowly fills, from its vents.
	_vent_clock -= dt
	if _vent_clock <= 0.0 and open_left <= 0.0:
		_vent_clock = VENT_EVERY
		var c := Iso.cell_of(pos + Vector2(randf_range(-40.0, 40.0), randf_range(14.0, 36.0)))
		world.gas.add(c, 0.7)
	_beat += dt * (1.0 + phase * 0.3)
	var pump := pow(maxf(sin(_beat * 3.4), 0.0), 6.0)
	_pulse_light.light_energy = 0.35 + pump * 0.5
	if int(_beat * 3.4 / TAU) != int((_beat - dt * (1.0 + phase * 0.3)) * 3.4 / TAU):
		Audio.play("heartbeat", -8.0, 0.55)
	# Burning gas against it: it opens.
	var burning := false
	for x in range(-3, 4):
		for y in range(0, 4):
			var c: Vector2i = Iso.cell_of(pos) + Vector2i(x, y)
			if world.gas.fire.has(c):
				burning = true
	if burning and open_left <= 0.0:
		open_left = OPEN_TIME - phase * 0.5
		Audio.play("roar", 0.0, 0.7)
		world.cam.kick(0.6)
		world.say_at(pos + Vector2(0.0, 12.0), "It's open!", UI.GAS)
		world.gas.amount.clear()
	if open_left > 0.0:
		open_left -= dt
		sprite.set_flash(Color(1.0, 0.9, 0.5), 0.25 if int(open_left * 6.0) % 2 == 0 else 0.0)
		if open_left <= 0.0:
			sprite.set_flash(Color.WHITE, 0.0)


## Closed, it's barely touched by anything but fire. Open, anything will do.
func _taken(amount: float, _from: Vector2, kind: String) -> float:
	if open_left > 0.0:
		return amount * 1.6
	if phase >= 3:
		return amount * 0.5
	world.hint("heart", world.player.pos, "It's too thick to hurt. Light the gas around it, from far away")
	if kind == "arrow":
		world.fx.sparks(pos + Vector2(0.0, 6.0), 20.0, 1, Color(0.7, 1.0, 0.4), 50.0, 0.2)
		return amount * 0.08
	return amount * 0.35


func on_dying() -> void:
	world.gas.amount.clear()
	world.gas.fire.clear()


func _finish() -> void:
	super._finish()
	world.start_finale()
