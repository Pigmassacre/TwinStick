extends Boss
## Old Bess. Goes for you across the arena like a loaded cart, and brings the roof
## down when she misses. Rats run at her whistle.

var charge_dir := Vector2.RIGHT
var hit_wall := false
var rats_out: Array = []
var _burst := 0.0
var _bursts := 0


func walk(dt: float) -> void:
	walk_to_player(dt)
	if randf() < dt * 0.6:
		Audio.play("rat", -6.0, randf_range(0.4, 0.6))


func choose_attack() -> String:
	rats_out = rats_out.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.alive)
	var options := ["charge", "charge", "spray"]
	if rats_out.size() < 4 + phase:
		options.append("rats")
	if phase >= 2:
		options.append("ring")
	return pick(options)


func begin_attack(which: String) -> void:
	match which:
		"charge":
			charge_dir = dir_to_player()
			hit_wall = false
			Audio.play("roar", -5.0, 1.2)
		"rats":
			Audio.play("whistle", -4.0, 0.7)
			world.say_at(pos, "Rats!", UI.ACCENT)
		"spray":
			_bursts = 2 + phase
			_burst = 0.0
		"ring":
			_bursts = 3
			_burst = 0.0


func do_attack(which: String, dt: float) -> bool:
	match which:
		"charge":
			return _charge(dt)
		"rats":
			if attack_time > 0.35:
				for i in 3 + phase:
					rats_out.append(summon("rat", edge_spot()))
				return true
		"spray":
			face_player()
			_burst -= dt
			if _burst <= 0.0:
				_burst = 0.42
				_bursts -= 1
				world.shots.fan(pos, dir_to_player(), 5 + phase, 1.1, 96.0, Shots.SMALL)
				Audio.play("spit", -5.0, 0.7)
			return _bursts <= 0
		"ring":
			_burst -= dt
			if _burst <= 0.0:
				_burst = 0.5
				_bursts -= 1
				world.shots.ring(pos, 14, 78.0, Shots.SMALL, _bursts * 0.2)
				Audio.play("rat", -3.0, 0.5)
			return _bursts <= 0
	return false


func _charge(dt: float) -> bool:
	if attack_time < 0.7:
		# Scraping the floor, getting ready.
		charge_dir = charge_dir.lerp(dir_to_player(), dt * 3.0).normalized()
		facing = sign(charge_dir.x) if charge_dir.x != 0.0 else facing
		sprite.set_flash(Color(1.0, 0.3, 0.2), 0.5 if int(attack_time * 12.0) % 2 == 0 else 0.0)
		if randf() < dt * 25.0:
			world.fx.chips(pos - charge_dir * radius, 1.0, 1, Color("5c3a24"), 50.0, 0.7)
		return false
	sprite.set_flash(Color.WHITE, 0.0)
	if hit_wall:
		# Dazed, and the roof coming down.
		if attack_time > 2.1:
			return true
		return false
	var before := pos
	vel = charge_dir * 300.0
	pos = world.map.move(pos, vel * dt, radius * 0.7)
	if randf() < dt * 40.0:
		world.fx.chips(pos, 1.0, 1, Color("5c3a24"), 60.0, 0.6)
	if pos.distance_to(before) < 2.0 or attack_time > 1.8:
		hit_wall = true
		attack_time = 0.8
		world.cam.kick(0.8)
		Audio.play("quake", -2.0)
		stun_time = 0.5
		for i in 4 + phase * 2:
			var to := world.player.pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 90.0) if i < 2 else floor_spot()
			world.falling_rock(to, randf_range(0.6, 1.3))
	return false
