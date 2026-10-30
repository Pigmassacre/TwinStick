extends Boss
## The Drowned Shift. It's only ever half here: it goes under, comes up beneath
## you, spits rings of black water and sends what's left of the gallery after you.

var under := false
var ripple: SpriteQuad
var _clock := 0.0
var _spin := 0.0
var _count := 0
var _target := Vector2.ZERO


func init() -> void:
	ripple = SpriteQuad.make("ripple", true)
	ripple.scale = Vector3(2.5, 1.5, 1.0)
	ripple.visible = false
	add_child(ripple)


func untouchable() -> bool:
	return dying or under


func walk(dt: float) -> void:
	keep_range(dt, 80.0, 150.0, 0.8)


func choose_attack() -> String:
	var options := ["dive", "dive", "spiral", "wave"]
	if phase >= 2:
		options.append("shift")
	return pick(options)


func begin_attack(which: String) -> void:
	_clock = 0.0
	match which:
		"dive":
			Audio.play("splash", -1.0, 0.7)
			world.fx.sparks(pos, 2.0, 18, Color("9ff0d8"), 100.0, 0.5)
			_count = 1 + phase
			_target = world.player.pos
		"spiral":
			_spin = randf() * TAU
			Audio.play("banish", -5.0)
		"wave":
			_count = 2 + phase
			Audio.play("splash", -3.0, 0.5)
		"shift":
			Audio.play("wraith", -2.0)


func do_attack(which: String, dt: float) -> bool:
	_clock -= dt
	match which:
		"dive":
			return _dive(dt)
		"spiral":
			face_player()
			if _clock <= 0.0:
				_clock = 0.1
				_spin += 0.34
				for arm in 2 + phase:
					world.shots.enemy(pos, Vector2.from_angle(_spin + TAU * arm / (2.0 + phase)), 72.0, Shots.DROP)
				if int(attack_time * 10.0) % 3 == 0:
					Audio.play("shard", -14.0, randf_range(0.8, 1.0))
			return attack_time > 2.8
		"wave":
			if _clock <= 0.0:
				_clock = 1.05
				_count -= 1
				_wave()
			return _count <= 0
		"shift":
			if attack_time > 0.5:
				for i in phase:
					summon("drownling", edge_spot())
				return true
	return false


## Under the floor, following; then up, right there.
func _dive(dt: float) -> bool:
	# Between dives it's up, and can be hit.
	under = attack_time >= 0.4
	shadow.visible = not under
	sprite.set_dissolve(clampf(attack_time / 0.4, 0.0, 1.0))
	ripple.visible = under
	ripple.play("idle", anim_time)
	if attack_time < 0.4:
		return false
	pos = pos.move_toward(_target, 170.0 * dt)
	_target = _target.move_toward(world.player.pos, 120.0 * dt)
	if pos.distance_to(_target) < 8.0 or attack_time > 2.5:
		_surface()
		_count -= 1
		if _count > 0:
			attack_time = -0.9
			return false
		return true
	return false


func _surface() -> void:
	world.shots.ring(pos, 12 + phase * 3, 92.0, Shots.DROP, randf() * TAU)
	world.fx.sparks(pos, 2.0, 24, Color("9ff0d8"), 130.0, 0.6)
	world.cam.kick(0.5)
	Audio.play("splash", 0.0, 0.8)
	if world.player.can_be_hit() and pos.distance_to(world.player.pos) < 24.0:
		world.player.hurt(1, dir_to_player())
	if _count <= 1:
		under = false
		sprite.set_dissolve(0.0)
		ripple.visible = false
		shadow.visible = true
	_target = world.player.pos


## A wall of water across the arena, with a gap in it.
func _wave() -> void:
	var map: LevelMap = world.map
	var from_north := world.player.pos.y > pos.y
	var y: float = (LevelGen.MARGIN + 1) * Iso.TILE if from_north else (map.h - LevelGen.MARGIN - 1) * Iso.TILE
	var x0 := float(LevelGen.MARGIN * Iso.TILE)
	var x1 := float((map.w - LevelGen.MARGIN) * Iso.TILE)
	var gap := randf_range(x0 + 30.0, x1 - 30.0)
	var x := x0
	while x < x1:
		if absf(x - gap) > 22.0:
			world.shots.enemy(Vector2(x, y), Vector2.DOWN if from_north else Vector2.UP, 62.0, Shots.DROP, 1.0, 6.0)
		x += 11.0
	Audio.play("splash", -3.0, 0.6)
