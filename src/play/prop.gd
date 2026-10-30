class_name Prop
extends Actor
## What stands around in the mine: crates, powder kegs, ore, carts on rails, a
## sealed chest. Most fill their cell, and have to be blown up or shot to pieces.

var kind := "crate"
var hp := 3.0
var cell := Vector2i.ZERO
var alive := true
var settled := true
# A cart runs along rails between these.
var rail_a := Vector2.ZERO
var rail_b := Vector2.ZERO
var horizontal := true
var speed := 0.0
var opened := false


func setup(the_world: World, what: String, at: Vector2i) -> void:
	world = the_world
	kind = what
	cell = at
	pos = Iso.cell_center(at) + Vector2(0.0, 7.0)
	radius = 7.0
	match kind:
		"crate":
			make_sprite("crate")
			hp = 4.0
		"keg":
			make_sprite("keg")
			hp = 2.0
		"ore":
			make_sprite("ore")
			hp = 10.0
		"chest":
			make_sprite("chest")
			sprite.play("closed", 0.0)
			hp = 999.0
		"cart":
			make_sprite("cart")
			hp = 9999.0
	if kind != "cart":
		world.map.props[cell] = self
		shadow.visible = false
	sync_visual(0.0)


func setup_cart(a: Vector2i, b: Vector2i, on_horizontal: bool) -> void:
	rail_a = Iso.cell_center(a)
	rail_b = Iso.cell_center(b)
	horizontal = on_horizontal
	pos = Iso.cell_center(cell)
	settled = false


func step(dt: float) -> void:
	if kind == "chest" and not opened and world.player.pos.distance_to(pos) < 20.0:
		_open_chest()
	if kind != "cart":
		return
	anim_time += dt
	if absf(speed) > 1.0:
		var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
		var next := pos + axis * speed * dt
		var v_min := minf(rail_a.x, rail_b.x) if horizontal else minf(rail_a.y, rail_b.y)
		var v_max := maxf(rail_a.x, rail_b.x) if horizontal else maxf(rail_a.y, rail_b.y)
		var along := next.x if horizontal else next.y
		if along < v_min or along > v_max or world.map.is_solid(Iso.cell_of(next)):
			speed = -speed * 0.4
			Audio.play("cart_hit", -4.0)
			world.cam.kick(0.15)
		else:
			pos = next
		speed = move_toward(speed, 0.0, dt * 26.0)
		if absf(speed) > 30.0:
			# What's in the way of a loaded cart gets run over.
			for e: Enemy in world.enemies:
				if e.height < 6.0 and not e.untouchable() and e.pos.distance_to(pos) < 11.0:
					e.hurt(14.0, (e.pos - pos).normalized(), "cart")
			if world.player.can_be_hit() and world.player.pos.distance_to(pos) < 9.0:
				world.player.hurt(1, (world.player.pos - pos).normalized())
		if absf(speed) > 50.0 and randf() < dt * 20.0:
			world.fx.sparks(pos + Vector2(randf_range(-7, 7), 2.0), 1.0, 1, Color(1.0, 0.8, 0.4), 40.0, 0.25)


func struck(s: Shots.Shot) -> void:
	if kind == "cart":
		var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
		speed += sign(s.vel.dot(axis)) * (70.0 if not s.explosive else 180.0)
		speed = clampf(speed, -220.0, 220.0)
		Audio.play("cart_hit", -8.0, 1.3)
		return
	if kind == "chest":
		Audio.play("clang", -8.0, 1.4)
		return
	hit(s.damage, s.fire)


func hit(damage: float, burning := false) -> void:
	if not alive:
		return
	hp -= damage
	flash()
	if kind == "ore":
		Audio.play("ore_hit", -7.0, randf_range(0.9, 1.2))
		world.fx.sparks(pos, 6.0, 2, Color(1.0, 0.85, 0.4), 60.0, 0.2)
		if randf() < 0.3:
			world.drop("nugget", pos)
	else:
		Audio.play("crate_hit", -9.0, randf_range(0.9, 1.15))
		world.fx.chips(pos, 6.0, 2, Color("8a5c36"), 50.0, 1.0)
	if hp <= 0.0 or (kind == "keg" and burning):
		destroy()


func destroy() -> void:
	if not alive:
		return
	alive = false
	world.map.props.erase(cell)
	match kind:
		"crate":
			Audio.play("crate_break", -3.0, randf_range(0.9, 1.1))
			world.fx.chips(pos, 7.0, 14, Color("8a5c36"), 90.0, 3.0, 1.0)
			world.crate_loot(pos)
		"keg":
			world.explode(pos, 44.0, 16.0, false, true)
		"ore":
			Audio.play("crate_break", -3.0, 0.7)
			world.fx.chips(pos, 6.0, 12, Color("5a5864"), 80.0, 2.5, 1.0)
			for i in 6:
				world.drop("nugget", pos)
	world.remove_prop(self)


func _open_chest() -> void:
	opened = true
	hp = 0.0
	sprite.play("open", 0.0)
	Audio.play("chest", -1.0)
	world.say_at(pos, "A cache!", Color("ffe27a"))
	world.lights.flash(pos, 12.0, Color(1.0, 0.85, 0.4), 0.7, 110.0, 0.9)
	world.fx.sparks(pos, 8.0, 14, Color(1.0, 0.9, 0.5), 80.0, 0.5)
	for i in 8:
		world.drop("nugget", pos)
	for i in 2:
		world.drop("powder", pos)
	world.drop("oil", pos)
	world.add_score(200)
