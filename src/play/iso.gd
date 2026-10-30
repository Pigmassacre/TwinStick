class_name Iso
## The game is played on a flat plane of pixels (x to the right, y down the
## screen, h up off the floor), and drawn in real 3D: lit, shadowed, under the
## original game's camera, 53 degrees down (its sin is 0.8, its cos 0.6).
##
## The plane is stretched into the world just so that a pixel of floor, of a
## wall's face and of an upright sprite each land on exactly one pixel of the
## screen: the screen's y is y - h, whatever is being drawn.

const SIN := 0.8
const COS := 0.6
const TILE := 16
const PITCH := -53.13010235415598


## Where the point `p` on the floor, `h` pixels up, is in the 3D world.
static func at(p: Vector2, h := 0.0) -> Vector3:
	return Vector3(p.x, h / COS, p.y / SIN)


## The same, with a whole number of pixels, so the sprites sit on the pixel grid.
static func snapped(p: Vector2, h := 0.0) -> Vector3:
	return Vector3(round(p.x), round(h) / COS, round(p.y) / SIN)


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * TILE, (c.y + 0.5) * TILE)
