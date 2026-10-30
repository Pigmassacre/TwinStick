extends Enemy
## Swims under the floor of the flooded gallery as a ripple. Comes up near you,
## spits a ring of black water, and goes back down.

const UNDER := 0
const RISING := 1
const UP := 2
const SINKING := 3

var ripple: SpriteQuad


func init() -> void:
	state = UNDER
	timer = randf_range(1.0, 2.5)
	sprite.visible = false
	shadow.visible = false
	ripple = SpriteQuad.make("ripple", true)
	add_child(ripple)
	anim = "idle"


func untouchable() -> bool:
	return state == UNDER


func _sleep(dt: float) -> void:
	ripple.play("idle", anim_time)
	super._sleep(dt)


func think(dt: float) -> void:
	timer -= dt
	ripple.play("idle", anim_time)
	match state:
		UNDER:
			var dist := to_player().length()
			if dist > 54.0:
				walk_to_player(dt, 1.3)
			else:
				go(dir_to_player().orthogonal(), dt, 1.0)
			if timer <= 0.0 and sees_player() and dist < 180.0:
				state = RISING
				timer = 0.32
				sprite.visible = true
				shadow.visible = true
				sprite.set_dissolve(0.7)
				Audio.play("splash", -9.0, randf_range(0.9, 1.2))
				world.fx.sparks(pos, 2.0, 5, Color("9ff0d8"), 50.0, 0.3)
		RISING:
			sprite.set_dissolve(maxf(timer / 0.32, 0.0))
			if timer <= 0.0:
				sprite.set_dissolve(0.0)
				state = UP
				timer = 0.85
				face_player()
				world.shots.ring(pos, 8, 72.0, Shots.DROP, randf() * TAU)
				Audio.play("spit", -7.0, 0.8)
		UP:
			if timer <= 0.0:
				state = SINKING
				timer = 0.3
		SINKING:
			sprite.set_dissolve(1.0 - maxf(timer / 0.3, 0.0))
			if timer <= 0.0:
				state = UNDER
				timer = randf_range(1.2, 2.4)
				sprite.visible = false
				shadow.visible = false
				sprite.set_dissolve(0.0)


func _contact() -> void:
	if state == UP:
		super._contact()
