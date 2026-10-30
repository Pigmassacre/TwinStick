extends Enemy
## A beetle with a shell of coal. Arrows skip off it from the front: get behind
## it, or give it something heavier. It charges in straight lines and takes a
## while to stop.

var charge := Vector2.ZERO


func init() -> void:
	timer = 1.5
	anim = "idle"


func think(dt: float) -> void:
	match state:
		0:
			walk_to_player(dt, 0.7)
			timer -= dt
			if timer <= 0.0 and sees_player() and to_player().length() < 170.0:
				state = 1
				timer = 0.55
				charge = dir_to_player()
				facing = sign(charge.x) if charge.x != 0.0 else facing
				Audio.play("beetle", -6.0)
		1:
			# Pawing the ground.
			timer -= dt
			charge = charge.lerp(dir_to_player(), dt * 3.0).normalized()
			facing = sign(charge.x) if charge.x != 0.0 else facing
			sprite.set_flash(Color(1.0, 0.4, 0.2), 0.4 if int(timer * 14.0) % 2 == 0 else 0.0)
			if timer <= 0.0:
				sprite.set_flash(Color.WHITE, 0.0)
				state = 2
				timer = 1.1
		2:
			timer -= dt
			var before := pos
			go(charge, dt, 4.2)
			if randf() < dt * 30.0:
				world.fx.chips(pos, 1.0, 1, Color("34323c"), 40.0, 0.6)
			if pos.distance_to(before) < 0.5 or timer <= 0.0:
				state = 0
				timer = randf_range(1.2, 2.0)
				if pos.distance_to(before) < 0.5:
					stun(0.5)
					world.cam.kick(0.12)
					Audio.play("clang", -9.0, 0.7)


func _taken(amount: float, from: Vector2, kind: String) -> float:
	if kind != "arrow":
		return amount
	# From its front, it mostly doesn't notice. `from` is the way the arrow was going.
	var front := Vector2(facing, 0.0) if state != 2 else charge
	if from.dot(front) < 0.2:
		world.hint("shell", pos, "Get behind it, or blow it up")
		world.fx.sparks(pos, 6.0, 3, Color(0.8, 0.8, 0.9), 70.0, 0.2)
		Audio.play("glance", -10.0, randf_range(0.8, 1.0))
		return amount * float(def.armour)
	return amount * 1.5
