class_name LightPool
extends Node3D
## The lights that come and go: blasts, arrows in flight, burning gas. A fixed
## set of them is kept lit-and-hidden, so nothing has to be set up mid-fight.

const COUNT := 16

class Glow:
	var light: OmniLight3D
	var time := 0.0
	var duration := 0.0
	var energy := 0.0
	var flicker := false
	## Following something (a Shot), rather than dying away where it was.
	var follow: Object = null

var _glows: Array[Glow] = []


func _ready() -> void:
	for i in COUNT:
		var g := Glow.new()
		g.light = OmniLight3D.new()
		g.light.visible = false
		g.light.shadow_enabled = false
		g.light.light_specular = 0.0
		g.light.omni_attenuation = 0.0
		add_child(g.light)
		_glows.append(g)


## A light where `p` is, `h` up, dying away over `seconds`.
func flash(p: Vector2, h: float, color: Color, energy: float, reach: float, seconds: float) -> void:
	var g := _free_glow()
	if g == null:
		return
	g.follow = null
	g.time = seconds
	g.duration = seconds
	# Those who'd rather not have the flashes get a softer light.
	g.energy = energy if Game.settings.flashes else energy * 0.45
	g.light.position = Iso.at(p, h)
	g.light.light_color = color
	g.light.light_energy = energy
	g.light.omni_range = reach
	g.light.visible = true


## A little light that goes along with `shot` (which has `pos` and `h`), for as long as it's `alive`.
func attach(shot: Object, color: Color, energy: float, reach: float) -> void:
	var g := _free_glow()
	if g == null:
		return
	g.follow = shot
	g.time = 1.0
	g.duration = 1.0
	g.energy = energy
	g.light.light_color = color
	g.light.light_energy = energy
	g.light.omni_range = reach
	g.light.visible = true
	g.light.position = Iso.at(shot.pos, shot.h)


func _free_glow() -> Glow:
	var oldest: Glow = null
	for g in _glows:
		if not g.light.visible:
			return g
		if g.follow == null and (oldest == null or g.time < oldest.time):
			oldest = g
	return oldest


func step(dt: float) -> void:
	for g in _glows:
		if not g.light.visible:
			continue
		if g.follow != null:
			if g.follow.alive:
				g.light.position = Iso.at(g.follow.pos, g.follow.h)
				continue
			# It has hit something: its light dies quickly there.
			g.follow = null
			g.time = 0.14
			g.duration = 0.14
		g.time -= dt
		if g.time <= 0.0:
			g.light.visible = false
			continue
		var t := g.time / g.duration
		g.light.light_energy = g.energy * t * t
