extends Boss
## Cinder Jack. Plates of coal over a burning heart: arrows don't trouble the
## plates. It takes a blast, or a few, to knock them off, and then you can get at it.

const PLATE_HP := 2

var plates := 3
var plate_hits := 0
var regrown := false
var _lane_step := 0
var _lane_dir := Vector2.RIGHT
var _lane_at := Vector2.ZERO
var _clock := 0.0
var _count := 0


func init() -> void:
	anim = "p3"
	set_meta("glowing", true)


func _show(_dt: float) -> void:
	anim = "p%d" % plates
	sprite.play(anim, anim_time)


func walk(dt: float) -> void:
	walk_to_player(dt)
	if int(anim_time * 2.2) != int((anim_time - dt) * 2.2):
		Audio.play("stomp", -11.0, randf_range(0.8, 1.0))
		world.cam.kick(0.08)
	if plates == 0 and randf() < dt * 10.0:
		world.fx.sparks(pos, 16.0, 1, Color(1.0, 0.6, 0.2), 40.0, 0.4)


func choose_attack() -> String:
	var options := ["stomp", "coals", "lane"]
	if phase >= 2:
		options.append("embers")
	return pick(options)


func begin_attack(which: String) -> void:
	_clock = 0.0
	match which:
		"coals":
			_count = 3 + phase
			Audio.play("swing", -3.0, 0.6)
		"lane":
			_lane_dir = dir_to_player()
			_lane_at = pos
			_lane_step = 0
			Audio.play("ember", -2.0, 0.6)
		"stomp":
			sprite.set_flash(Color(1.0, 0.5, 0.2), 0.3)
			_count = 1 + phase


func do_attack(which: String, dt: float) -> bool:
	_clock -= dt
	match which:
		"stomp":
			if attack_time > 0.5 and _clock <= 0.0:
				sprite.set_flash(Color.WHITE, 0.0)
				_clock = 0.55
				_count -= 1
				world.shots.ring(pos, 18, 74.0, Shots.HOT, _count * 0.17)
				world.fx.chips(pos, 1.0, 12, Color("34323c"), 100.0, 1.0)
				world.cam.kick(0.5)
				Audio.play("stomp", -1.0, 0.7)
				Audio.play("quake", -6.0)
			return _count <= 0
		"coals":
			if _clock <= 0.0:
				_clock = 0.3
				_count -= 1
				var to: Vector2 = world.player.pos + world.player.vel * 0.7 + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 34.0)
				world.warn(to, 0.85)
				world.shots.lob(pos, to, 0.85, Shots.COAL, "fire", 60.0)
				Audio.play("ember", -5.0, randf_range(0.7, 1.0))
			return _count <= 0
		"lane":
			# A line of fire along the floor, running out from its feet.
			if _clock <= 0.0:
				_clock = 0.06
				_lane_step += 1
				_lane_at += _lane_dir * Iso.TILE * 0.8
				if world.map.wall_at(_lane_at) or _lane_step > 20:
					return true
				world.gas.set_fire(Iso.cell_of(_lane_at), 3.0)
				if _lane_step % 4 == 0:
					Audio.play("ember", -8.0, randf_range(0.8, 1.1))
			return false
		"embers":
			if attack_time > 0.4:
				for i in phase:
					summon("ember", pos + Vector2.from_angle(randf() * TAU) * 20.0)
				return true
	return false


## Arrows bounce off the plates; blasts are what get them off.
func _taken(amount: float, _from: Vector2, kind: String) -> float:
	if plates > 0:
		if kind == "blast":
			plate_hits += 1
			flash(Color(1.0, 0.7, 0.3), 0.1)
			if plate_hits >= PLATE_HP:
				plate_hits = 0
				plates -= 1
				_plate_off()
			return amount * 0.5
		world.hint("plates", pos, "It takes a blast to break those plates")
		world.fx.sparks(pos + Vector2(0.0, 2.0), 18.0, 2, Color(0.8, 0.8, 0.9), 70.0, 0.2)
		Audio.play("glance", -11.0, randf_range(0.7, 1.0))
		return amount * 0.12
	return amount * 1.5


func _plate_off() -> void:
	Audio.play("clang", 0.0, 0.6)
	Audio.play("crumble", -2.0)
	world.cam.kick(0.4)
	world.fx.chips(pos, 20.0, 18, Color("5a5864"), 130.0, 2.5, 1.0)
	world.fx.sparks(pos, 20.0, 12, Color(1.0, 0.6, 0.2), 120.0, 0.5)
	world.drop("powder", pos)
	if plates == 0:
		world.say_at(pos, "Its heart is showing!", UI.FIRE)
		world.drop("powder", pos)


func _process(_delta: float) -> void:
	# At half its health, the plates grow back, once.
	if not regrown and alive and not dying and hp < max_hp * 0.42 and plates == 0:
		regrown = true
		plates = 2
		world.say_at(pos, "It's hardening!", UI.DIM)
		Audio.play("crumble", 0.0, 0.8)
