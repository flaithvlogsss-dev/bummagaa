@tool
class_name PropBuilders
extends RefCounted
## PropBuilders — the extended prop catalogue for LowPolyProp (vehicles, street furniture,
## playground, camp, interiors, the radio tower, flat decals).
##
## Each build_<kind>() adds primitive parts through the owning prop (merged into one mesh,
## per-part WorldTextures materials), plus collision and lights. `size` scales stretchable
## kinds, `color` (alpha > 0) overrides the main colour, `lit` switches lamps and screens.

var p: LowPolyProp


func _init(prop: LowPolyProp) -> void:
	p = prop


# Short helpers ------------------------------------------------------------------------------------

func use(m: String) -> void:
	p._use(m)


func bx(s: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, snow: float = 1.0, emit: float = 0.0) -> void:
	p._box(s, pos, col, rot, snow, emit)


func cy(r: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, top: float = -1.0, seg: int = 8, snow: float = 1.0, emit: float = 0.0) -> void:
	p._cyl(r, h, pos, col, rot, top, seg, snow, emit)


func sph(r: float, pos: Vector3, col: Color, sc: Vector3 = Vector3.ONE) -> void:
	p._sphere(r, r * 2.0, pos, col, sc)


func col(s: Vector3, pos: Vector3) -> void:
	p._col(s, pos)


func c(default: Color) -> Color:
	return p._c(default)


func wheel(pos: Vector3, r: float = 0.36, w: float = 0.26) -> void:
	use("plastic")
	cy(r, w, pos, Color(0.07, 0.07, 0.08), Vector3(90, 0, 0), -1.0, 10, 0.2)
	use("metal")
	cy(r * 0.45, w + 0.02, pos, Color(0.4, 0.42, 0.45), Vector3(90, 0, 0), -1.0, 6, 0.0)


# --- Vehicles --------------------------------------------------------------------------------------

func build_sedan() -> void:
	_sedan(c(Color(0.42, 0.18, 0.16)))


func build_car() -> void:
	build_sedan()


func _sedan(body: Color) -> void:
	use("paint")
	bx(Vector3(4.3, 0.62, 1.82), Vector3(0, 0.62, 0), body, Vector3.ZERO, 0.4)
	bx(Vector3(1.1, 0.25, 1.78), Vector3(1.55, 0.98, 0), body.darkened(0.05), Vector3(0, 0, -8), 0.8)
	bx(Vector3(2.3, 0.62, 1.7), Vector3(-0.3, 1.24, 0), body.darkened(0.12))
	use("glass")
	bx(Vector3(2.34, 0.4, 1.72), Vector3(-0.3, 1.24, 0), Color(0.12, 0.15, 0.2), Vector3.ZERO, 0.0)
	bx(Vector3(0.06, 0.42, 1.5), Vector3(0.87, 1.2, 0), Color(0.14, 0.18, 0.24), Vector3(0, 0, -30), 0.0)
	use("plastic")
	bx(Vector3(0.12, 0.2, 1.86), Vector3(2.16, 0.45, 0), Color(0.15, 0.15, 0.17), Vector3.ZERO, 0.2)
	bx(Vector3(0.12, 0.2, 1.86), Vector3(-2.16, 0.45, 0), Color(0.15, 0.15, 0.17), Vector3.ZERO, 0.2)
	bx(Vector3(0.05, 0.14, 0.36), Vector3(2.19, 0.72, 0.62), Color(0.9, 0.86, 0.6), Vector3.ZERO, 0.0, 0.3)
	bx(Vector3(0.05, 0.14, 0.36), Vector3(2.19, 0.72, -0.62), Color(0.9, 0.86, 0.6), Vector3.ZERO, 0.0, 0.3)
	bx(Vector3(0.05, 0.12, 0.3), Vector3(-2.19, 0.74, 0.64), Color(0.6, 0.08, 0.06), Vector3.ZERO, 0.0)
	bx(Vector3(0.05, 0.12, 0.3), Vector3(-2.19, 0.74, -0.64), Color(0.6, 0.08, 0.06), Vector3.ZERO, 0.0)
	bx(Vector3(0.02, 0.5, 0.02), Vector3(0.3, 0.7, 0.92), body.darkened(0.4), Vector3.ZERO, 0.0)
	for x in [-1.35, 1.35]:
		for z in [-0.88, 0.88]:
			wheel(Vector3(x, 0.36, z))
	col(Vector3(4.3, 1.6, 1.85), Vector3(0, 0.8, 0))


func build_police_car() -> void:
	_sedan(c(Color(0.9, 0.9, 0.9)))
	use("paint")
	bx(Vector3(4.32, 0.18, 1.84), Vector3(0, 0.66, 0), Color(0.12, 0.26, 0.62), Vector3.ZERO, 0.0)
	use("plastic")
	bx(Vector3(0.9, 0.14, 0.3), Vector3(-0.3, 1.62, 0), Color(0.15, 0.15, 0.17))
	var on := p.lit
	bx(Vector3(0.3, 0.12, 0.26), Vector3(-0.56, 1.72, 0), Color(0.2, 0.35, 1.0), Vector3.ZERO, 0.0, 3.0 if on else 0.2)
	bx(Vector3(0.3, 0.12, 0.26), Vector3(-0.04, 1.72, 0), Color(1.0, 0.15, 0.12), Vector3.ZERO, 0.0, 3.0 if on else 0.2)
	if on:
		p._omni(Vector3(-0.3, 2.0, 0), Color(0.5, 0.4, 1.0), 1.2, 7.0)
		p.flicker = true
		p.set_process(not Engine.is_editor_hint())


func build_van() -> void:
	_van(c(Color(0.78, 0.78, 0.76)))


func build_ambulance() -> void:
	# Mara's ambulance: white van, red band and crosses, a dead light bar.
	_van(c(Color(0.88, 0.88, 0.86)))
	use("paint")
	bx(Vector3(4.82, 0.22, 2.02), Vector3(-0.3, 1.0, 0), Color(0.72, 0.12, 0.1), Vector3.ZERO, 0.0)
	for z in [-1.02, 1.02]:
		bx(Vector3(0.5, 0.14, 0.02), Vector3(-1.2, 1.65, z), Color(0.75, 0.1, 0.08), Vector3.ZERO, 0.0)
		bx(Vector3(0.14, 0.5, 0.02), Vector3(-1.2, 1.65, z), Color(0.75, 0.1, 0.08), Vector3.ZERO, 0.0)
	use("plastic")
	bx(Vector3(0.3, 0.14, 1.2), Vector3(1.3, 2.25, 0), Color(0.15, 0.2, 0.55), Vector3.ZERO, 0.4, 0.3)
	# Rear doors hang open.
	use("paint")
	bx(Vector3(0.06, 1.7, 0.95), Vector3(-2.9, 1.2, 1.35), Color(0.84, 0.84, 0.82), Vector3(0, -70, 0), 0.3)


func _van(body: Color) -> void:
	use("paint")
	bx(Vector3(4.8, 1.9, 2.0), Vector3(-0.3, 1.2, 0), body)
	bx(Vector3(0.9, 1.1, 1.96), Vector3(2.35, 0.8, 0), body.darkened(0.05), Vector3(0, 0, -14), 0.6)
	use("glass")
	bx(Vector3(0.06, 0.7, 1.7), Vector3(2.0, 1.65, 0), Color(0.12, 0.15, 0.2), Vector3(0, 0, -22), 0.0)
	bx(Vector3(0.8, 0.5, 2.02), Vector3(1.4, 1.55, 0), Color(0.12, 0.15, 0.2), Vector3.ZERO, 0.0)
	use("metal")
	bx(Vector3(3.2, 0.06, 1.6), Vector3(-0.6, 2.2, 0), Color(0.25, 0.26, 0.28))
	bx(Vector3(0.03, 1.5, 0.03), Vector3(-0.4, 1.2, 1.01), body.darkened(0.4), Vector3.ZERO, 0.0)
	for x in [-1.9, 1.6]:
		for z in [-0.92, 0.92]:
			wheel(Vector3(x, 0.4, z), 0.4)
	col(Vector3(5.4, 2.3, 2.05), Vector3(-0.1, 1.15, 0))


func build_truck() -> void:
	var cab := c(Color(0.24, 0.36, 0.52))
	use("paint")
	bx(Vector3(2.1, 2.2, 2.3), Vector3(3.2, 1.5, 0), cab)
	bx(Vector3(0.7, 1.0, 2.3), Vector3(4.5, 0.9, 0), cab.darkened(0.1))
	use("glass")
	bx(Vector3(0.06, 0.8, 2.0), Vector3(4.27, 2.05, 0), Color(0.12, 0.15, 0.2), Vector3(0, 0, -10), 0.0)
	use("container")
	bx(Vector3(5.6, 2.8, 2.45), Vector3(-0.9, 1.95, 0), Color(0.62, 0.6, 0.55))
	use("metal")
	bx(Vector3(7.8, 0.3, 1.2), Vector3(0.5, 0.55, 0), Color(0.15, 0.15, 0.17), Vector3.ZERO, 0.0)
	for x in [-2.6, -1.4, 3.2]:
		for z in [-1.0, 1.0]:
			wheel(Vector3(x, 0.5, z), 0.5, 0.34)
	col(Vector3(8.2, 3.4, 2.5), Vector3(0.3, 1.7, 0))


func build_bus() -> void:
	var body := c(Color(0.66, 0.54, 0.2))
	use("paint")
	bx(Vector3(10.4, 2.4, 2.55), Vector3(0, 1.55, 0), body)
	bx(Vector3(10.44, 0.25, 2.58), Vector3(0, 0.6, 0), body.darkened(0.3), Vector3.ZERO, 0.0)
	use("glass")
	for i in 6:
		bx(Vector3(1.35, 0.85, 2.6), Vector3(-4.0 + i * 1.6, 2.05, 0), Color(0.1, 0.13, 0.17), Vector3.ZERO, 0.0)
	bx(Vector3(0.06, 1.3, 2.3), Vector3(5.2, 1.9, 0), Color(0.12, 0.15, 0.2), Vector3.ZERO, 0.0)
	use("plastic")
	bx(Vector3(0.06, 0.28, 1.4), Vector3(5.23, 2.85, 0), Color(0.08, 0.08, 0.08), Vector3.ZERO, 0.0, 0.0)
	bx(Vector3(0.9, 1.9, 0.06), Vector3(3.9, 1.3, 1.29), Color(0.12, 0.14, 0.16), Vector3.ZERO, 0.0)
	for x in [-3.4, 3.2]:
		for z in [-1.1, 1.1]:
			wheel(Vector3(x, 0.5, z), 0.5, 0.3)
	col(Vector3(10.4, 2.9, 2.6), Vector3(0, 1.45, 0))


# --- Street furniture ---------------------------------------------------------------------------------

func build_power_pole() -> void:
	use("planks")
	var wood := c(Color(0.3, 0.22, 0.15))
	cy(0.14, 8.0, Vector3(0, 4.0, 0), wood, Vector3.ZERO, 0.11, 6)
	bx(Vector3(2.2, 0.14, 0.14), Vector3(0, 7.4, 0), wood)
	use("plastic")
	for x in [-0.9, -0.3, 0.3, 0.9]:
		cy(0.05, 0.18, Vector3(x, 7.56, 0), Color(0.55, 0.6, 0.58), Vector3.ZERO, -1.0, 5, 0.0)
	use("metal")
	bx(Vector3(0.5, 0.6, 0.35), Vector3(0, 6.2, 0.22), Color(0.4, 0.42, 0.44))
	col(Vector3(0.4, 8.0, 0.4), Vector3(0, 4.0, 0))


## Sagging wires along +X for size.x * 10 metres (place between two poles).
func build_wires() -> void:
	use("plain")
	var length := p.size.x * 10.0
	var n := 8
	for w in 3:
		var z := -0.6 + w * 0.6
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var y0 := 7.55 - sin(PI * t0) * 0.9
			var y1 := 7.55 - sin(PI * t1) * 0.9
			var a := Vector3(-length * 0.5 + length * t0, y0, z)
			var b := Vector3(-length * 0.5 + length * t1, y1, z)
			var mid := (a + b) * 0.5
			var ang := rad_to_deg(atan2(b.y - a.y, b.x - a.x))
			bx(Vector3(a.distance_to(b), 0.03, 0.03), mid, Color(0.06, 0.06, 0.07), Vector3(0, 0, ang), 0.3)


func build_street_sign() -> void:
	use("metal")
	cy(0.05, 2.6, Vector3(0, 1.3, 0), Color(0.35, 0.37, 0.4), Vector3.ZERO, -1.0, 6)
	use("paint")
	bx(Vector3(0.9, 0.5, 0.04), Vector3(0, 2.5, 0.05), c(Color(0.15, 0.3, 0.62)), Vector3.ZERO, 0.4)
	bx(Vector3(0.7, 0.08, 0.02), Vector3(0, 2.55, 0.08), Color(0.9, 0.9, 0.88), Vector3.ZERO, 0.0)
	bx(Vector3(0.5, 0.06, 0.02), Vector3(0, 2.42, 0.08), Color(0.9, 0.9, 0.88), Vector3.ZERO, 0.0)
	col(Vector3(0.2, 2.8, 0.2), Vector3(0, 1.4, 0))


func build_traffic_light() -> void:
	use("metal")
	cy(0.08, 4.0, Vector3(0, 2.0, 0), Color(0.2, 0.22, 0.24), Vector3.ZERO, -1.0, 6)
	bx(Vector3(0.4, 1.1, 0.35), Vector3(0, 3.7, 0.2), Color(0.12, 0.12, 0.13))
	var on := p.lit
	bx(Vector3(0.22, 0.22, 0.04), Vector3(0, 4.05, 0.39), Color(0.3, 0.05, 0.04), Vector3.ZERO, 0.0)
	bx(Vector3(0.22, 0.22, 0.04), Vector3(0, 3.7, 0.39), Color(1.0, 0.7, 0.15) if on else Color(0.3, 0.22, 0.05), Vector3.ZERO, 0.0, 3.0 if on else 0.0)
	bx(Vector3(0.22, 0.22, 0.04), Vector3(0, 3.35, 0.39), Color(0.05, 0.25, 0.1), Vector3.ZERO, 0.0)
	if on:
		p._omni(Vector3(0, 3.7, 0.8), Color(1.0, 0.7, 0.2), 0.6, 4.0)
		p.flicker = true
		p.set_process(not Engine.is_editor_hint())
	col(Vector3(0.3, 4.2, 0.3), Vector3(0, 2.1, 0))


func build_billboard() -> void:
	use("metal")
	for x in [-2.2, 2.2]:
		bx(Vector3(0.2, 4.0, 0.2), Vector3(x, 2.0, 0), Color(0.25, 0.27, 0.3))
	use("paint")
	var face := c(Color(0.75, 0.3, 0.2))
	bx(Vector3(6.2, 3.0, 0.2), Vector3(0, 5.4, 0), Color(0.15, 0.16, 0.18))
	bx(Vector3(5.9, 2.7, 0.05), Vector3(0, 5.4, 0.12), face, Vector3.ZERO, 0.0)
	bx(Vector3(3.6, 0.5, 0.02), Vector3(-0.8, 6.1, 0.16), Color(0.95, 0.92, 0.85), Vector3.ZERO, 0.0)
	bx(Vector3(2.4, 0.3, 0.02), Vector3(-1.4, 5.4, 0.16), Color(0.95, 0.92, 0.85), Vector3.ZERO, 0.0)
	bx(Vector3(1.4, 1.4, 0.02), Vector3(1.8, 5.2, 0.16), face.lightened(0.35), Vector3.ZERO, 0.0)
	# Torn corner.
	bx(Vector3(1.2, 0.9, 0.03), Vector3(2.4, 4.4, 0.14), Color(0.55, 0.52, 0.48), Vector3(0, 0, 25), 0.0)
	col(Vector3(6.2, 7.0, 0.5), Vector3(0, 3.5, 0))


func build_bus_stop() -> void:
	use("metal")
	for x in [-1.6, 1.6]:
		bx(Vector3(0.1, 2.5, 0.1), Vector3(x, 1.25, -0.6), Color(0.3, 0.32, 0.35))
		bx(Vector3(0.1, 2.5, 0.1), Vector3(x, 1.25, 0.6), Color(0.3, 0.32, 0.35))
	bx(Vector3(3.6, 0.12, 1.6), Vector3(0, 2.55, 0), Color(0.25, 0.28, 0.32))
	use("glass")
	bx(Vector3(3.2, 1.9, 0.05), Vector3(0, 1.3, -0.62), Color(0.35, 0.42, 0.48), Vector3.ZERO, 0.0)
	use("planks")
	bx(Vector3(2.6, 0.08, 0.4), Vector3(0, 0.5, -0.35), Color(0.4, 0.3, 0.2))
	use("paint")
	bx(Vector3(0.6, 0.8, 0.05), Vector3(1.9, 2.1, 0.62), c(Color(0.9, 0.9, 0.85)), Vector3.ZERO, 0.0)
	col(Vector3(3.6, 2.6, 0.3), Vector3(0, 1.3, -0.62))


func build_phone_booth() -> void:
	use("paint")
	var frame_c := c(Color(0.62, 0.14, 0.12))
	bx(Vector3(1.0, 2.3, 1.0), Vector3(0, 1.15, 0), frame_c)
	use("glass")
	bx(Vector3(0.8, 1.7, 1.02), Vector3(0, 1.2, 0), Color(0.3, 0.38, 0.44), Vector3.ZERO, 0.0)
	bx(Vector3(1.02, 1.7, 0.8), Vector3(0, 1.2, 0), Color(0.3, 0.38, 0.44), Vector3.ZERO, 0.0)
	use("plastic")
	bx(Vector3(0.3, 0.4, 0.15), Vector3(0, 1.4, -0.4), Color(0.15, 0.15, 0.16), Vector3.ZERO, 0.0)
	bx(Vector3(0.1, 0.08, 0.04), Vector3(0.05, 1.5, -0.32), Color(0.4, 1.0, 0.5) if p.lit else Color(0.1, 0.2, 0.1), Vector3.ZERO, 0.0, 2.0 if p.lit else 0.0)
	# The receiver hangs on its cord.
	bx(Vector3(0.06, 0.25, 0.06), Vector3(0.1, 0.95, -0.3), Color(0.12, 0.12, 0.13), Vector3(0, 0, 10), 0.0)
	col(Vector3(1.0, 2.3, 1.0), Vector3(0, 1.15, 0))


func build_ac_unit() -> void:
	use("metal")
	bx(Vector3(0.9, 0.6, 0.45), Vector3(0, 0.3, 0.22), c(Color(0.7, 0.72, 0.72)))
	cy(0.2, 0.04, Vector3(0.12, 0.3, 0.46), Color(0.3, 0.32, 0.34), Vector3(90, 0, 0), -1.0, 8, 0.0)
	bx(Vector3(0.95, 0.04, 0.5), Vector3(0, -0.02, 0.22), Color(0.3, 0.3, 0.32))


func build_vent() -> void:
	use("metal")
	cy(0.25, 0.8, Vector3(0, 0.4, 0), c(Color(0.5, 0.52, 0.55)), Vector3.ZERO, -1.0, 8)
	cy(0.4, 0.06, Vector3(0, 0.95, 0), Color(0.42, 0.44, 0.47), Vector3.ZERO, 0.1, 8)
	col(Vector3(0.5, 1.0, 0.5), Vector3(0, 0.5, 0))


func build_drainpipe() -> void:
	use("metal")
	var h := p.size.y * 8.0
	var m := c(Color(0.45, 0.47, 0.5))
	cy(0.08, h, Vector3(0, h * 0.5, 0.1), m, Vector3.ZERO, -1.0, 6)
	bx(Vector3(0.16, 0.16, 0.3), Vector3(0, 0.1, 0.25), m.darkened(0.1))
	bx(Vector3(0.3, 0.16, 0.2), Vector3(0, h, 0.12), m)
	# Icicle at the outlet.
	cy(0.05, 0.4, Vector3(0, -0.05, 0.38), Color(0.8, 0.9, 1.0), Vector3(180, 0, 0), 0.0, 5, 0.0)


func build_pipe() -> void:
	use("rust")
	var length := p.size.x * 4.0
	cy(0.18, length, Vector3(0, 0.3, 0), c(Color(0.45, 0.35, 0.28)), Vector3(0, 0, 90), -1.0, 8)
	for x in [-length * 0.4, length * 0.4]:
		bx(Vector3(0.1, 0.3, 0.3), Vector3(x, 0.15, 0), Color(0.3, 0.3, 0.32))
	col(Vector3(length, 0.5, 0.4), Vector3(0, 0.3, 0))


func build_bike() -> void:
	use("metal")
	var frame_c := c(Color(0.2, 0.45, 0.35))
	for x in [-0.55, 0.55]:
		cy(0.33, 0.04, Vector3(x, 0.33, 0), Color(0.08, 0.08, 0.09), Vector3(90, 0, 0), -1.0, 10, 0.3)
	bx(Vector3(0.9, 0.05, 0.05), Vector3(0, 0.55, 0), frame_c, Vector3(0, 0, 8))
	bx(Vector3(0.05, 0.5, 0.05), Vector3(-0.1, 0.5, 0), frame_c, Vector3(0, 0, -20))
	bx(Vector3(0.05, 0.45, 0.05), Vector3(0.5, 0.58, 0), frame_c, Vector3(0, 0, 20))
	bx(Vector3(0.05, 0.05, 0.45), Vector3(0.58, 0.82, 0), Color(0.15, 0.15, 0.16))
	bx(Vector3(0.22, 0.05, 0.1), Vector3(-0.2, 0.78, 0), Color(0.1, 0.1, 0.1))
	col(Vector3(1.4, 0.9, 0.3), Vector3(0, 0.45, 0))


func build_trash_bags() -> void:
	use("plastic")
	var b := c(Color(0.1, 0.11, 0.12))
	sph(0.4, Vector3(0, 0.3, 0), b, Vector3(1, 0.8, 1))
	sph(0.35, Vector3(0.55, 0.26, 0.2), b.lightened(0.05), Vector3(1, 0.8, 1))
	sph(0.32, Vector3(0.2, 0.62, 0.1), b, Vector3(1, 0.8, 1))
	col(Vector3(1.2, 0.8, 0.9), Vector3(0.25, 0.4, 0.1))


func build_cart() -> void:
	use("metal")
	var m := c(Color(0.6, 0.62, 0.66))
	bx(Vector3(0.9, 0.05, 0.55), Vector3(0, 0.45, 0), m)
	bx(Vector3(0.9, 0.45, 0.03), Vector3(0, 0.68, 0.27), m, Vector3.ZERO, 0.0)
	bx(Vector3(0.9, 0.45, 0.03), Vector3(0, 0.68, -0.27), m, Vector3.ZERO, 0.0)
	bx(Vector3(0.03, 0.45, 0.55), Vector3(-0.45, 0.68, 0), m, Vector3.ZERO, 0.0)
	bx(Vector3(0.03, 0.08, 0.55), Vector3(0.6, 0.95, 0), Color(0.7, 0.2, 0.15))
	for x in [-0.35, 0.35]:
		for z in [-0.22, 0.22]:
			cy(0.07, 0.04, Vector3(x, 0.07, z), Color(0.1, 0.1, 0.1), Vector3(90, 0, 0), -1.0, 6, 0.0)
	use("paint")
	for i in 3:
		cy(0.08, 0.14, Vector3(-0.2 + i * 0.2, 0.55, 0.05 * i), Color(0.7, 0.55, 0.3).lerp(Color(0.8, 0.3, 0.2), i * 0.4), Vector3.ZERO, -1.0, 6, 0.3)
	col(Vector3(1.2, 1.0, 0.6), Vector3(0, 0.5, 0))


func build_cone() -> void:
	use("plastic")
	cy(0.2, 0.7, Vector3(0, 0.35, 0), c(Color(0.95, 0.45, 0.12)), Vector3.ZERO, 0.03, 8)
	cy(0.16, 0.1, Vector3(0, 0.4, 0), Color(0.92, 0.92, 0.9), Vector3.ZERO, 0.1, 8)
	bx(Vector3(0.45, 0.05, 0.45), Vector3(0, 0.025, 0), Color(0.2, 0.2, 0.2))


func build_snowman() -> void:
	use("snow")
	var s := Color(0.86, 0.9, 0.95)
	sph(0.55, Vector3(0, 0.5, 0), s)
	sph(0.4, Vector3(0, 1.25, 0), s)
	sph(0.28, Vector3(0, 1.82, 0), s)
	use("plastic")
	if p.lit:
		# Someone gave it a gas mask.
		bx(Vector3(0.32, 0.26, 0.12), Vector3(0, 1.8, 0.24), Color(0.18, 0.22, 0.18))
		cy(0.07, 0.1, Vector3(-0.08, 1.86, 0.31), Color(0.5, 0.7, 0.8), Vector3(90, 0, 0), -1.0, 6, 0.0)
		cy(0.07, 0.1, Vector3(0.08, 1.86, 0.31), Color(0.5, 0.7, 0.8), Vector3(90, 0, 0), -1.0, 6, 0.0)
		cy(0.08, 0.16, Vector3(0, 1.66, 0.34), Color(0.3, 0.32, 0.28), Vector3(90, 0, 0), -1.0, 6, 0.0)
	else:
		cy(0.04, 0.3, Vector3(0, 1.82, 0.36), Color(0.95, 0.5, 0.15), Vector3(90, 0, 0), 0.0, 5, 0.0)
	bx(Vector3(0.9, 0.08, 0.12), Vector3(0, 1.62, 0), c(Color(0.7, 0.15, 0.15)), Vector3(0, 30, 0), 0.0)
	use("planks")
	bx(Vector3(0.05, 0.7, 0.05), Vector3(0.55, 1.35, 0), Color(0.3, 0.2, 0.12), Vector3(0, 0, -50), 0.0)
	col(Vector3(1.0, 2.0, 1.0), Vector3(0, 1.0, 0))


func build_tent() -> void:
	use("fabric")
	var f := c(Color(0.3, 0.42, 0.34))
	var m := PrismMesh.new()
	m.size = Vector3(2.2 * p.size.x, 1.3, 2.4)
	p._part(m, Vector3(0, 0.65, 0), f, Vector3.ZERO, 0.4)
	bx(Vector3(0.9, 0.9, 0.04), Vector3(0, 0.45, 1.21), f.darkened(0.35), Vector3.ZERO, 0.0)
	use("plain")
	for z in [-1.3, 1.3]:
		bx(Vector3(0.03, 0.2, 0.03), Vector3(1.2, 0.1, z), Color(0.5, 0.5, 0.5), Vector3(0, 0, 30), 0.0)
	col(Vector3(2.2 * p.size.x, 1.3, 2.4), Vector3(0, 0.65, 0))


func build_sled() -> void:
	use("planks")
	var w := c(Color(0.62, 0.3, 0.18))
	bx(Vector3(0.9, 0.05, 0.4), Vector3(0, 0.2, 0), w)
	use("metal")
	for z in [-0.17, 0.17]:
		bx(Vector3(1.0, 0.04, 0.03), Vector3(0, 0.03, z), Color(0.5, 0.52, 0.55), Vector3.ZERO, 0.3)
		bx(Vector3(0.03, 0.18, 0.03), Vector3(-0.3, 0.11, z), Color(0.5, 0.52, 0.55), Vector3.ZERO, 0.3)
		bx(Vector3(0.03, 0.18, 0.03), Vector3(0.3, 0.11, z), Color(0.5, 0.52, 0.55), Vector3.ZERO, 0.3)
	use("plastic")
	bx(Vector3(0.02, 0.02, 1.0), Vector3(0.5, 0.2, 0.5), Color(0.8, 0.8, 0.2), Vector3(0, 40, 0), 0.0)


func build_swing() -> void:
	use("metal")
	var m := c(Color(0.25, 0.4, 0.6))
	for z in [-0.9, 0.9]:
		bx(Vector3(0.08, 2.4, 0.08), Vector3(-0.8, 1.2, z), m, Vector3(0, 0, -15))
		bx(Vector3(0.08, 2.4, 0.08), Vector3(0.8, 1.2, z), m, Vector3(0, 0, 15))
	bx(Vector3(0.1, 0.1, 2.0), Vector3(0, 2.3, 0), m)
	bx(Vector3(0.02, 1.7, 0.02), Vector3(0, 1.45, -0.2), Color(0.3, 0.3, 0.3), Vector3.ZERO, 0.0)
	bx(Vector3(0.02, 1.7, 0.02), Vector3(0, 1.45, 0.2), Color(0.3, 0.3, 0.3), Vector3.ZERO, 0.0)
	use("planks")
	bx(Vector3(0.3, 0.05, 0.5), Vector3(0, 0.6, 0), Color(0.6, 0.3, 0.15))
	col(Vector3(2.0, 2.4, 2.0), Vector3(0, 1.2, 0))


func build_slide() -> void:
	use("metal")
	var m := c(Color(0.8, 0.3, 0.2))
	bx(Vector3(0.9, 1.6, 0.9), Vector3(-1.2, 0.8, 0), Color(0.3, 0.45, 0.6))
	bx(Vector3(2.6, 0.08, 0.7), Vector3(0.1, 0.85, 0), m, Vector3(0, 0, -34))
	bx(Vector3(0.2, 1.6, 0.8), Vector3(-1.75, 0.8, 0), Color(0.3, 0.3, 0.32), Vector3(0, 0, 10))
	col(Vector3(3.2, 1.6, 0.9), Vector3(-0.3, 0.8, 0))


func build_fountain() -> void:
	use("concrete")
	var st := c(Color(0.5, 0.5, 0.52))
	cy(2.4, 0.6, Vector3(0, 0.3, 0), st, Vector3.ZERO, -1.0, 12)
	use("ice")
	cy(2.1, 0.62, Vector3(0, 0.32, 0), Color(0.72, 0.82, 0.9), Vector3.ZERO, -1.0, 12, 0.2)
	use("concrete")
	cy(0.4, 1.8, Vector3(0, 0.9, 0), st, Vector3.ZERO, 0.3, 8)
	cy(0.9, 0.2, Vector3(0, 1.6, 0), st, Vector3.ZERO, -1.0, 10)
	use("ice")
	for i in 6:
		var a := TAU * i / 6.0
		cy(0.06, 0.5, Vector3(cos(a) * 0.8, 1.3, sin(a) * 0.8), Color(0.8, 0.9, 1.0), Vector3(180, 0, 0), 0.0, 5, 0.0)
	col(Vector3(4.6, 1.0, 4.6), Vector3(0, 0.5, 0))


func build_planter() -> void:
	use("concrete")
	bx(Vector3(1.4 * p.size.x, 0.6, 1.0), Vector3(0, 0.3, 0), c(Color(0.52, 0.52, 0.54)))
	use("plain")
	for i in 3:
		bx(Vector3(0.04, 0.6, 0.04), Vector3(-0.4 + i * 0.4, 0.9, 0.1 * i), Color(0.25, 0.18, 0.12), Vector3(0, 0, -20 + i * 20), 0.3)
	col(Vector3(1.4 * p.size.x, 0.6, 1.0), Vector3(0, 0.3, 0))


func build_loudspeaker() -> void:
	use("metal")
	cy(0.08, 5.0, Vector3(0, 2.5, 0), Color(0.3, 0.32, 0.35), Vector3.ZERO, -1.0, 6)
	for a in [-35.0, 35.0]:
		cy(0.28, 0.6, Vector3(sin(deg_to_rad(a)) * 0.3, 4.7, cos(deg_to_rad(a)) * 0.3), c(Color(0.55, 0.57, 0.5)), Vector3(90, a, 0), 0.08, 8)
	# Cut cable.
	bx(Vector3(0.03, 1.2, 0.03), Vector3(0.12, 3.9, 0), Color(0.08, 0.08, 0.08), Vector3(0, 0, 25), 0.0)
	col(Vector3(0.3, 5.0, 0.3), Vector3(0, 2.5, 0))


func build_kennel() -> void:
	use("planks")
	var w := c(Color(0.45, 0.32, 0.2))
	bx(Vector3(1.0, 0.8, 1.2), Vector3(0, 0.4, 0), w)
	var m := PrismMesh.new()
	m.size = Vector3(1.2, 0.5, 1.3)
	use("roof")
	p._part(m, Vector3(0, 1.05, 0), Color(0.3, 0.24, 0.2))
	bx(Vector3(0.5, 0.5, 0.04), Vector3(0, 0.3, 0.61), Color(0.05, 0.05, 0.06), Vector3.ZERO, 0.0)
	use("metal")
	for i in 5:
		bx(Vector3(0.1, 0.03, 0.05), Vector3(0.1 * i, 0.04, 0.8 + i * 0.18), Color(0.45, 0.46, 0.48), Vector3(0, i * 30, 0), 0.0)
	bx(Vector3(0.25, 0.04, 0.25), Vector3(0.5, 0.03, 1.7), Color(0.55, 0.15, 0.12), Vector3.ZERO, 0.0)
	col(Vector3(1.0, 1.2, 1.2), Vector3(0, 0.6, 0))


func build_laundry_line() -> void:
	use("metal")
	var length := p.size.x * 4.0
	for x in [-length * 0.5, length * 0.5]:
		bx(Vector3(0.06, 2.0, 0.06), Vector3(x, 1.0, 0), Color(0.4, 0.4, 0.42))
	bx(Vector3(length, 0.02, 0.02), Vector3(0, 1.9, 0), Color(0.6, 0.6, 0.6), Vector3.ZERO, 0.0)
	use("fabric")
	var cols := [Color(0.7, 0.2, 0.2), Color(0.85, 0.85, 0.8), Color(0.25, 0.35, 0.6), Color(0.6, 0.55, 0.3)]
	for i in 4:
		# Frozen stiff: hanging perfectly flat.
		bx(Vector3(0.6, 0.8, 0.03), Vector3(-length * 0.35 + i * length * 0.23, 1.45, 0), cols[i], Vector3.ZERO, 0.6)


func build_garage_door() -> void:
	use("container")
	var w := 3.0 * p.size.x
	bx(Vector3(w, 2.6, 0.1), Vector3(0, 1.3, 0), c(Color(0.5, 0.52, 0.55)), Vector3.ZERO, 0.4)
	use("metal")
	bx(Vector3(0.4, 0.08, 0.06), Vector3(0, 0.4, 0.07), Color(0.2, 0.2, 0.22), Vector3.ZERO, 0.0)
	col(Vector3(w, 2.6, 0.2), Vector3(0, 1.3, 0))


func build_tires() -> void:
	use("plastic")
	for i in int(maxf(1.0, p.size.y * 4.0)):
		cy(0.38, 0.25, Vector3(0, 0.13 + i * 0.25, 0), Color(0.07, 0.07, 0.08), Vector3.ZERO, -1.0, 10, 0.3)
	col(Vector3(0.8, p.size.y * 1.0, 0.8), Vector3(0, p.size.y * 0.5, 0))


func build_barrel() -> void:
	use("rust")
	var b := c(Color(0.25, 0.35, 0.5))
	cy(0.32, 0.9, Vector3(0, 0.45, 0), b, Vector3.ZERO, -1.0, 10)
	cy(0.33, 0.05, Vector3(0, 0.3, 0), b.darkened(0.3), Vector3.ZERO, -1.0, 10, 0.0)
	cy(0.33, 0.05, Vector3(0, 0.62, 0), b.darkened(0.3), Vector3.ZERO, -1.0, 10, 0.0)
	col(Vector3(0.65, 0.9, 0.65), Vector3(0, 0.45, 0))


func build_boxes() -> void:
	use("cardboard")
	var b := c(Color(0.62, 0.48, 0.3))
	bx(Vector3(0.6, 0.45, 0.5), Vector3(0, 0.225, 0), b, Vector3.ZERO, 0.5)
	bx(Vector3(0.5, 0.4, 0.45), Vector3(0.05, 0.65, 0.02), b.lightened(0.08), Vector3(0, 15, 0), 0.5)
	bx(Vector3(0.45, 0.35, 0.4), Vector3(0.6, 0.175, 0.1), b.darkened(0.08), Vector3(0, -10, 0), 0.5)
	col(Vector3(1.1, 0.9, 0.6), Vector3(0.25, 0.45, 0))


func build_suitcase() -> void:
	use("fabric")
	var b := c(Color(0.3, 0.2, 0.35))
	bx(Vector3(0.7, 0.22, 0.5), Vector3(0, 0.11, 0), b, Vector3(0, 12, 0), 0.4)
	use("plastic")
	bx(Vector3(0.2, 0.04, 0.04), Vector3(0.36, 0.14, 0), Color(0.1, 0.1, 0.1), Vector3(0, 12, 0), 0.0)


func build_corpse() -> void:
	# A frozen body under a thin layer of snow: coat, legs, one hand out.
	use("fabric")
	var coat := c(Color(0.25, 0.28, 0.3))
	bx(Vector3(0.55, 0.3, 0.9), Vector3(0, 0.15, 0), coat, Vector3(0, 8, 0), 1.0)
	bx(Vector3(0.2, 0.2, 0.8), Vector3(-0.13, 0.1, 0.8), Color(0.18, 0.18, 0.22), Vector3(0, 12, 0), 1.0)
	bx(Vector3(0.2, 0.2, 0.8), Vector3(0.14, 0.1, 0.78), Color(0.18, 0.18, 0.22), Vector3(0, 4, 0), 1.0)
	use("plain")
	sph(0.16, Vector3(0.02, 0.15, -0.58), Color(0.62, 0.55, 0.5), Vector3(1, 0.9, 1))
	bx(Vector3(0.1, 0.08, 0.3), Vector3(0.42, 0.06, -0.2), Color(0.7, 0.6, 0.55), Vector3(0, -40, 0), 0.4)


func build_window_boarded() -> void:
	use("glass")
	bx(Vector3(1.0 * p.size.x, 1.2 * p.size.y, 0.08), Vector3.ZERO, Color(0.06, 0.07, 0.09), Vector3.ZERO, 0.0)
	use("planks")
	var w := Color(0.48, 0.36, 0.24)
	bx(Vector3(1.25 * p.size.x, 0.18, 0.05), Vector3(0, 0.3, 0.06), w, Vector3(0, 0, 8), 0.4)
	bx(Vector3(1.25 * p.size.x, 0.18, 0.05), Vector3(0, -0.25, 0.06), w.darkened(0.1), Vector3(0, 0, -6), 0.4)
	bx(Vector3(1.2 * p.size.x, 0.16, 0.05), Vector3(0, 0.02, 0.08), w, Vector3(0, 0, 40), 0.4)


func build_balcony() -> void:
	use("concrete")
	var w := 2.6 * p.size.x
	bx(Vector3(w, 0.18, 1.1), Vector3(0, 0, 0.55), c(Color(0.55, 0.55, 0.56)))
	use("metal")
	bx(Vector3(w, 0.05, 0.05), Vector3(0, 1.0, 1.08), Color(0.22, 0.22, 0.24))
	for i in int(w / 0.3) + 1:
		bx(Vector3(0.03, 0.9, 0.03), Vector3(-w * 0.5 + i * 0.3, 0.5, 1.08), Color(0.22, 0.22, 0.24), Vector3.ZERO, 0.0)
	for x in [-w * 0.5, w * 0.5]:
		bx(Vector3(0.05, 1.0, 1.1), Vector3(x, 0.5, 0.55), Color(0.22, 0.22, 0.24), Vector3.ZERO, 0.0)


func build_canopy() -> void:
	use("metal")
	var w := 3.0 * p.size.x
	bx(Vector3(w, 0.12, 1.4), Vector3(0, 2.7, 0.7), c(Color(0.3, 0.32, 0.36)), Vector3(-6, 0, 0))
	for x in [-w * 0.45, w * 0.45]:
		bx(Vector3(0.06, 0.06, 1.4), Vector3(x, 2.6, 0.7), Color(0.2, 0.2, 0.22), Vector3(-6, 0, 0), 0.0)


func build_fire_escape() -> void:
	# Zig-zag steel stairs on a facade (visual only), `size.y` floors.
	use("metal")
	var m := c(Color(0.22, 0.2, 0.2))
	var floors := int(maxf(1.0, p.size.y * 3.0))
	for f in floors:
		var y := 3.0 + f * 3.0
		bx(Vector3(2.4, 0.08, 1.0), Vector3(0, y, 0.5), m)
		bx(Vector3(2.4, 0.04, 0.04), Vector3(0, y + 0.9, 1.0), m, Vector3.ZERO, 0.0)
		var dir := 1.0 if f % 2 == 0 else -1.0
		bx(Vector3(0.9, 0.06, 3.2), Vector3(dir * 0.7, y - 1.5, 0.5), m, Vector3(0, 90, 43), 0.4)
	bx(Vector3(0.06, 2.4, 0.06), Vector3(1.15, 1.8, 0.95), m, Vector3.ZERO, 0.0)
	bx(Vector3(0.06, 2.4, 0.06), Vector3(0.85, 1.8, 0.95), m, Vector3.ZERO, 0.0)


func build_radio_tower() -> void:
	# Lattice mast: four legs with cross braces, a platform and a red beacon.
	use("metal")
	var h := p.size.y * 16.0
	var m := c(Color(0.55, 0.22, 0.18))
	var base := 1.4
	var top := 0.35
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := Vector3(sx * base, 0, sz * base)
			var b := Vector3(sx * top, h, sz * top)
			var mid := (a + b) * 0.5
			var tilt := rad_to_deg(atan2(base - top, h))
			bx(Vector3(0.12, a.distance_to(b), 0.12), mid, m, Vector3(-sz * tilt, 0, sx * tilt), 0.3)
	var levels := int(h / 2.0)
	for i in levels:
		var y := 0.8 + i * 2.0
		var r := lerpf(base, top, y / h)
		bx(Vector3(r * 2.0, 0.07, 0.07), Vector3(0, y, r), m.lightened(0.15), Vector3.ZERO, 0.3)
		bx(Vector3(r * 2.0, 0.07, 0.07), Vector3(0, y, -r), m.lightened(0.15), Vector3.ZERO, 0.3)
		bx(Vector3(0.07, 0.07, r * 2.0), Vector3(r, y, 0), m.lightened(0.15), Vector3.ZERO, 0.3)
		bx(Vector3(0.07, 0.07, r * 2.0), Vector3(-r, y, 0), m.lightened(0.15), Vector3.ZERO, 0.3)
	bx(Vector3(1.6, 0.1, 1.6), Vector3(0, h * 0.62, 0), Color(0.3, 0.3, 0.32))
	cy(0.05, 2.5, Vector3(0, h + 1.2, 0), Color(0.5, 0.5, 0.52), Vector3.ZERO, -1.0, 5)
	bx(Vector3(0.2, 0.2, 0.2), Vector3(0, h + 2.5, 0), Color(1.0, 0.15, 0.1), Vector3.ZERO, 0.0, 4.0 if p.lit else 0.3)
	for i in 3:
		bx(Vector3(0.5, 0.9, 0.12), Vector3(0.45, h - 1.0 - i * 0.2, 0), Color(0.75, 0.75, 0.78), Vector3(0, i * 120, 0), 0.4)
	col(Vector3(base * 2.0, h, base * 2.0), Vector3(0, h * 0.5, 0))


func build_stairs() -> void:
	# A walkable ramp with visual steps going up along -Z: size.x width, size.y rise, size.z run.
	use("concrete")
	var w := p.size.x
	var rise := p.size.y
	var run := p.size.z
	var st := c(Color(0.5, 0.5, 0.52))
	var steps := int(maxf(2.0, rise / 0.2))
	for i in steps:
		var y := (i + 1) * rise / steps
		bx(Vector3(w, rise / steps, run / steps), Vector3(0, y - rise / steps * 0.5, run * 0.5 - (i + 0.5) * run / steps), st.darkened(0.03 * (i % 2)))
	if p.has_collision:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var slope := sqrt(rise * rise + run * run)
		box.size = Vector3(w, 0.1, slope)
		cs.shape = box
		cs.position = Vector3(0, rise * 0.5, 0)
		cs.rotation = Vector3(atan2(rise, run), 0, 0)
		cs.set_meta("_prop_part", true)
		p.add_child(cs, false, Node.INTERNAL_MODE_FRONT)


# --- Interiors ------------------------------------------------------------------------------------------

func build_fridge() -> void:
	use("paint")
	var w := c(Color(0.85, 0.85, 0.82))
	bx(Vector3(0.7, 1.8, 0.65), Vector3(0, 0.9, 0), w, Vector3.ZERO, 0.0)
	bx(Vector3(0.66, 0.02, 0.02), Vector3(0, 1.25, 0.33), w.darkened(0.3), Vector3.ZERO, 0.0)
	use("metal")
	bx(Vector3(0.04, 0.35, 0.04), Vector3(0.25, 1.5, 0.35), Color(0.6, 0.6, 0.62), Vector3.ZERO, 0.0)
	bx(Vector3(0.04, 0.35, 0.04), Vector3(0.25, 0.9, 0.35), Color(0.6, 0.6, 0.62), Vector3.ZERO, 0.0)
	col(Vector3(0.7, 1.8, 0.65), Vector3(0, 0.9, 0))


func build_sofa() -> void:
	use("fabric")
	var f := c(Color(0.35, 0.3, 0.45))
	bx(Vector3(2.0, 0.45, 0.85), Vector3(0, 0.25, 0), f, Vector3.ZERO, 0.0)
	bx(Vector3(2.0, 0.55, 0.2), Vector3(0, 0.7, -0.33), f.darkened(0.1), Vector3.ZERO, 0.0)
	bx(Vector3(0.2, 0.3, 0.85), Vector3(-0.95, 0.6, 0), f.darkened(0.1), Vector3.ZERO, 0.0)
	bx(Vector3(0.2, 0.3, 0.85), Vector3(0.95, 0.6, 0), f.darkened(0.1), Vector3.ZERO, 0.0)
	bx(Vector3(0.7, 0.14, 0.5), Vector3(0.4, 0.54, 0.05), Color(0.6, 0.55, 0.4), Vector3(0, 10, 0), 0.0)
	col(Vector3(2.0, 0.9, 0.85), Vector3(0, 0.45, 0))


func build_tv() -> void:
	use("plastic")
	bx(Vector3(1.0, 0.5, 0.45), Vector3(0, 0.25, 0), Color(0.3, 0.22, 0.15), Vector3.ZERO, 0.0)
	bx(Vector3(0.8, 0.6, 0.5), Vector3(0, 0.8, 0), c(Color(0.15, 0.15, 0.16)), Vector3.ZERO, 0.0)
	use("glass")
	bx(Vector3(0.62, 0.46, 0.02), Vector3(0, 0.82, 0.26), Color(0.6, 0.7, 0.75) if p.lit else Color(0.08, 0.1, 0.12), Vector3.ZERO, 0.0, 1.5 if p.lit else 0.0)
	col(Vector3(1.0, 1.1, 0.5), Vector3(0, 0.55, 0))


func build_bookshelf() -> void:
	use("planks")
	var w := c(Color(0.36, 0.26, 0.18))
	bx(Vector3(1.2, 2.0, 0.35), Vector3(0, 1.0, 0), w.darkened(0.2), Vector3.ZERO, 0.0)
	use("paint")
	var cols := [Color(0.6, 0.2, 0.15), Color(0.2, 0.35, 0.5), Color(0.55, 0.5, 0.3), Color(0.25, 0.45, 0.3), Color(0.5, 0.45, 0.42)]
	for r in 4:
		var x := -0.5
		var i := r
		while x < 0.45:
			var bw := 0.06 + (i % 3) * 0.03
			bx(Vector3(bw, 0.3 - (i % 2) * 0.05, 0.25), Vector3(x + bw * 0.5, 0.3 + r * 0.48, 0.03), cols[i % cols.size()], Vector3(0, 0, 8.0 if i % 7 == 3 else 0.0), 0.0)
			x += bw + 0.01
			i += 1
	col(Vector3(1.2, 2.0, 0.35), Vector3(0, 1.0, 0))


func build_rack() -> void:
	# Radio / electronics rack with blinking lamps.
	use("metal")
	bx(Vector3(0.8, 2.0, 0.7), Vector3(0, 1.0, 0), c(Color(0.25, 0.27, 0.3)), Vector3.ZERO, 0.0)
	use("plastic")
	for i in 5:
		bx(Vector3(0.7, 0.28, 0.04), Vector3(0, 0.3 + i * 0.36, 0.36), Color(0.14, 0.15, 0.17), Vector3.ZERO, 0.0)
		var lamp: Color = [Color(0.2, 1.0, 0.3), Color(1.0, 0.7, 0.2), Color(1.0, 0.2, 0.2)][i % 3]
		bx(Vector3(0.05, 0.05, 0.02), Vector3(-0.25, 0.35 + i * 0.36, 0.39), lamp, Vector3.ZERO, 0.0, 3.0 if p.lit else 0.2)
		bx(Vector3(0.2, 0.08, 0.02), Vector3(0.15, 0.3 + i * 0.36, 0.39), Color(0.4, 0.42, 0.45), Vector3.ZERO, 0.0)
	col(Vector3(0.8, 2.0, 0.7), Vector3(0, 1.0, 0))


func build_tape_recorder() -> void:
	use("plastic")
	bx(Vector3(0.6, 0.18, 0.35), Vector3(0, 0.09, 0), c(Color(0.2, 0.2, 0.22)), Vector3.ZERO, 0.0)
	use("metal")
	for x in [-0.14, 0.14]:
		cy(0.08, 0.03, Vector3(x, 0.19, -0.02), Color(0.6, 0.6, 0.62), Vector3.ZERO, -1.0, 8, 0.0)
	bx(Vector3(0.4, 0.03, 0.06), Vector3(0, 0.19, 0.13), Color(0.3, 0.3, 0.32), Vector3.ZERO, 0.0)


func build_desk() -> void:
	use("planks")
	var w := c(Color(0.4, 0.3, 0.22))
	bx(Vector3(1.6, 0.06, 0.8), Vector3(0, 0.76, 0), w, Vector3.ZERO, 0.0)
	bx(Vector3(0.5, 0.73, 0.75), Vector3(0.52, 0.37, 0), w.darkened(0.15), Vector3.ZERO, 0.0)
	bx(Vector3(0.06, 0.73, 0.75), Vector3(-0.77, 0.37, 0), w.darkened(0.15), Vector3.ZERO, 0.0)
	use("cardboard")
	bx(Vector3(0.35, 0.02, 0.25), Vector3(-0.3, 0.8, 0.1), Color(0.9, 0.88, 0.8), Vector3(0, 12, 0), 0.0)
	bx(Vector3(0.3, 0.02, 0.22), Vector3(-0.1, 0.81, -0.1), Color(0.85, 0.83, 0.76), Vector3(0, -8, 0), 0.0)
	col(Vector3(1.6, 0.8, 0.8), Vector3(0, 0.4, 0))


func build_lockers() -> void:
	use("metal")
	var m := c(Color(0.4, 0.46, 0.44))
	for i in 3:
		bx(Vector3(0.45, 1.9, 0.5), Vector3(-0.47 + i * 0.47, 0.95, 0), m.darkened(0.05 * (i % 2)), Vector3.ZERO, 0.0)
		bx(Vector3(0.25, 0.04, 0.02), Vector3(-0.47 + i * 0.47, 1.6, 0.26), m.darkened(0.4), Vector3.ZERO, 0.0)
	col(Vector3(1.4, 1.9, 0.5), Vector3(0, 0.95, 0))


func build_radiator() -> void:
	use("metal")
	var m := c(Color(0.75, 0.75, 0.72))
	for i in 8:
		bx(Vector3(0.07, 0.6, 0.12), Vector3(-0.3 + i * 0.085, 0.45, 0), m, Vector3.ZERO, 0.0)
	bx(Vector3(0.72, 0.04, 0.1), Vector3(0, 0.76, 0), m.darkened(0.1), Vector3.ZERO, 0.0)


func build_mailboxes() -> void:
	use("metal")
	var m := c(Color(0.35, 0.42, 0.5))
	bx(Vector3(1.4, 1.0, 0.25), Vector3(0, 1.3, 0), m.darkened(0.2), Vector3.ZERO, 0.0)
	for r in 3:
		for k in 4:
			bx(Vector3(0.3, 0.28, 0.02), Vector3(-0.5 + k * 0.33, 1.0 + r * 0.31, 0.13), m, Vector3.ZERO, 0.0)
	use("cardboard")
	bx(Vector3(0.22, 0.05, 0.08), Vector3(0.16, 1.34, 0.16), Color(0.9, 0.88, 0.82), Vector3(0, 0, 10), 0.0)
	bx(Vector3(0.2, 0.05, 0.08), Vector3(0.16, 1.3, 0.16), Color(0.85, 0.8, 0.7), Vector3(0, 0, -6), 0.0)


func build_bunk_bed() -> void:
	use("metal")
	var m := c(Color(0.3, 0.34, 0.3))
	for x in [-0.5, 0.5]:
		for z in [-0.95, 0.95]:
			bx(Vector3(0.06, 1.9, 0.06), Vector3(x, 0.95, z), m, Vector3.ZERO, 0.0)
	use("fabric")
	for y in [0.45, 1.45]:
		bx(Vector3(0.95, 0.18, 1.9), Vector3(0, y, 0), Color(0.36, 0.4, 0.32), Vector3.ZERO, 0.0)
		bx(Vector3(0.7, 0.12, 0.35), Vector3(0, y + 0.13, -0.7), Color(0.85, 0.85, 0.8), Vector3.ZERO, 0.0)
	bx(Vector3(0.96, 0.08, 1.2), Vector3(0, 1.58, 0.3), Color(0.55, 0.25, 0.2), Vector3.ZERO, 0.0)
	col(Vector3(1.0, 1.9, 2.0), Vector3(0, 0.95, 0))


func build_heater() -> void:
	# Electric oil heater: glows when the power grid feeds it.
	use("metal")
	bx(Vector3(0.7, 0.7, 0.25), Vector3(0, 0.4, 0), c(Color(0.8, 0.8, 0.76)), Vector3.ZERO, 0.0)
	for i in 6:
		bx(Vector3(0.07, 0.6, 0.3), Vector3(-0.27 + i * 0.11, 0.4, 0), Color(0.72, 0.72, 0.7), Vector3.ZERO, 0.0)
	bx(Vector3(0.06, 0.06, 0.02), Vector3(0.25, 0.7, 0.14), Color(1.0, 0.4, 0.1), Vector3.ZERO, 0.0, 3.0 if p.lit else 0.0)
	if p.lit:
		p._omni(Vector3(0, 0.7, 0.4), Color(1.0, 0.55, 0.3), 0.5, 3.0)


func build_string_lights() -> void:
	# A warm garland along +X (size.x * 4 m), sagging between two ends.
	var length := p.size.x * 4.0
	use("plain")
	for i in 12:
		var t := float(i) / 11.0
		var pos := Vector3(-length * 0.5 + length * t, 2.7 - sin(PI * t) * 0.35, 0)
		bx(Vector3(length / 11.0, 0.02, 0.02), pos, Color(0.1, 0.1, 0.1), Vector3.ZERO, 0.0)
		var bulb: Color = [Color(1.0, 0.75, 0.35), Color(1.0, 0.55, 0.3), Color(0.9, 0.85, 0.5)][i % 3]
		bx(Vector3(0.06, 0.08, 0.06), pos - Vector3(0, 0.06, 0), bulb, Vector3.ZERO, 0.0, 3.0 if p.lit else 0.2)
	if p.lit:
		p._omni(Vector3(0, 2.3, 0), Color(1.0, 0.72, 0.4), 0.6, length * 0.8)


func build_plant() -> void:
	use("plastic")
	cy(0.2, 0.3, Vector3(0, 0.15, 0), Color(0.55, 0.3, 0.2), Vector3.ZERO, 0.25, 8, 0.0)
	use("plain")
	var green := c(Color(0.25, 0.5, 0.28))
	sph(0.22, Vector3(0, 0.5, 0), green, Vector3(1, 1.2, 1))
	sph(0.14, Vector3(0.12, 0.65, 0.05), green.lightened(0.1))


func build_tool_wall() -> void:
	use("planks")
	bx(Vector3(2.0, 1.2, 0.05), Vector3(0, 1.6, 0), c(Color(0.5, 0.42, 0.3)), Vector3.ZERO, 0.0)
	use("metal")
	var tools := [[Vector3(0.05, 0.5, 0.03), -0.7, 0.0], [Vector3(0.3, 0.06, 0.03), -0.4, 20.0], [Vector3(0.05, 0.45, 0.03), -0.1, -10.0],
		[Vector3(0.4, 0.12, 0.03), 0.3, 0.0], [Vector3(0.05, 0.6, 0.03), 0.7, 5.0]]
	for t in tools:
		bx(t[0], Vector3(t[1], 1.65, 0.05), Color(0.55, 0.56, 0.6), Vector3(0, 0, t[2]), 0.0)


# --- Decals (flat, no collision) ------------------------------------------------------------------------

func build_manhole() -> void:
	use("metal")
	cy(0.4, 0.02, Vector3(0, 0.012, 0), c(Color(0.16, 0.16, 0.17)), Vector3.ZERO, -1.0, 12, 0.3)


func build_stain() -> void:
	# Irregular dark blot (oil, blood, soot). Colour sets the kind.
	use("plain")
	var s := c(Color(0.08, 0.07, 0.07))
	var sc := p.size.x
	bx(Vector3(1.0, 0.01, 0.7) * Vector3(sc, 1, sc), Vector3(0, 0.012, 0), s, Vector3(0, 15, 0), 0.0)
	bx(Vector3(0.6, 0.01, 0.8) * Vector3(sc, 1, sc), Vector3(0.35 * sc, 0.013, 0.2 * sc), s, Vector3(0, -30, 0), 0.0)
	bx(Vector3(0.3, 0.01, 0.3) * Vector3(sc, 1, sc), Vector3(-0.6 * sc, 0.014, -0.3 * sc), s, Vector3(0, 45, 0), 0.0)
	bx(Vector3(0.15, 0.01, 0.15) * Vector3(sc, 1, sc), Vector3(0.8 * sc, 0.014, -0.4 * sc), s, Vector3(0, 10, 0), 0.0)


func build_crosswalk() -> void:
	use("paint")
	var w := p.size.x * 10.0
	for i in 6:
		bx(Vector3(0.5, 0.01, w), Vector3(-2.5 + i, 0.02, 0), Color(0.85, 0.85, 0.82), Vector3.ZERO, 0.35)


func build_road_line() -> void:
	use("paint")
	var length := p.size.x * 20.0
	var n := int(length / 3.0)
	for i in n:
		bx(Vector3(1.6, 0.01, 0.15), Vector3(-length * 0.5 + i * 3.0 + 0.8, 0.02, 0), c(Color(0.85, 0.8, 0.5)), Vector3.ZERO, 0.35)


func build_paper() -> void:
	use("cardboard")
	for i in 5:
		bx(Vector3(0.25, 0.005, 0.32), Vector3(-0.4 + i * 0.2, 0.012 + i * 0.001, 0.15 * sin(i * 2.1)), Color(0.88, 0.86, 0.8), Vector3(0, i * 37, 0), 0.5)
