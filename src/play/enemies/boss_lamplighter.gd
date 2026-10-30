extends Boss
## The Pale Lamplighter. Goes round the mine putting out the lamps. Yours is the
## last, and he only has to reach up with the pole. What he carries gives out dark.

const SNUFF_TIME := 6.0

var snuff_left := 0.0
var _clock := 0.0
var _spin := 0.0
var _count := 0
var _blink := 0.0


func init() -> void:
	height = 2.0
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(0.8, 0.45, 1.0)
	lantern.light_energy = 0.5
	lantern.omni_range = 90.0
	lantern.omni_attenuation = 0.0
	lantern.light_specular = 0.0
	lantern.position = Vector3(8.0, 44.0 / Iso.COS, 1.0)
	add_child(lantern)


func walk(dt: float) -> void:
	height = 2.0 + sin(anim_time * 2.0) * 1.5
	keep_range(dt, 90.0, 170.0, 0.9)


func choose_attack() -> String:
	var options := ["orbs", "blink", "rays"]
	if snuff_left <= 0.0:
		options.append("snuff")
	if phase >= 2:
		options.append("gloams")
	return pick(options)


func begin_attack(which: String) -> void:
	_clock = 0.0
	match which:
		"snuff":
			Audio.play("dark", -1.0)
			world.say_at(pos, "It's getting dark", UI.DIM)
		"orbs":
			_count = 3 + phase
		"blink":
			_blink = 0.0
			Audio.play("wraith", -3.0, 0.8)
		"rays":
			_spin = randf() * TAU
			Audio.play("banish", -4.0, 0.8)
		"gloams":
			Audio.play("wraith", -1.0, 0.6)


func do_attack(which: String, dt: float) -> bool:
	_clock -= dt
	match which:
		"snuff":
			if attack_time > 0.7:
				snuff_left = SNUFF_TIME + phase
				return true
		"orbs":
			face_player()
			if _clock <= 0.0:
				_clock = 0.42
				_count -= 1
				var dir := dir_to_player()
				for bend: float in [-0.9, 0.0, 0.9]:
					var s := world.shots.enemy(pos, dir.rotated(bend * 0.6), 74.0, Shots.ORB)
					s.curve = -bend * 0.55
					s.h = 18.0
				Audio.play("wraith", -9.0, randf_range(1.0, 1.3))
			return _count <= 0
		"blink":
			# Gone, and then somewhere else.
			_blink += dt
			if _blink < 0.35:
				sprite.set_dissolve(_blink / 0.35)
				return false
			if _blink < 0.4:
				pos = floor_spot()
			var back := (_blink - 0.4) / 0.35
			sprite.set_dissolve(1.0 - clampf(back, 0.0, 1.0))
			if back >= 1.0:
				sprite.set_dissolve(0.0)
				world.shots.ring(pos, 10 + phase * 2, 66.0, Shots.ORB, randf() * TAU)
				Audio.play("wraith", -7.0, 1.2)
				return true
		"rays":
			face_player()
			if _clock <= 0.0:
				_clock = 0.16
				_spin += 0.21
				for arm in 3:
					var s := world.shots.enemy(pos, Vector2.from_angle(_spin + TAU * arm / 3.0), 84.0, Shots.ORB)
					s.h = 18.0
			return attack_time > 3.0
		"gloams":
			if attack_time > 0.5:
				for i in phase:
					summon("wraith", edge_spot())
				return true
	return false


func step(dt: float) -> void:
	super.step(dt)
	if dying:
		world.player.lamp_dimmed = move_toward(world.player.lamp_dimmed, 0.0, dt)
		return
	# While he has it, the ranger's lamp sinks to almost nothing.
	snuff_left = maxf(snuff_left - dt, 0.0)
	world.player.lamp_dimmed = move_toward(world.player.lamp_dimmed, 1.0 if snuff_left > 0.0 else 0.0, dt * 1.2)


## He's only quite there in the light.
func _taken(amount: float, _from: Vector2, _kind: String) -> float:
	return amount * (0.6 if snuff_left > 0.0 else 1.0)


func on_dying() -> void:
	world.player.lamp_dimmed = 0.0
