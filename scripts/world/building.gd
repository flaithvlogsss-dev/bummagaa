@tool
class_name Building
extends LowPolyBlock
## Building — a whole (non-enterable) building merged into ONE mesh: body, plinth, floor
## ledges, windows (dark / lit / curtained / boarded), balconies, drainpipes, an entrance with
## canopy and house plate, a shop front with a sign, and a flat roof with parapet and rooftop
## clutter (vents, AC units, chimney, antenna, machine room) or a snowy gable roof.
##
## Purpose: readable, detailed facades from the three-quarter camera without hundreds of nodes.
## Collision is the body box; fading, cut-away and the map behave exactly like LowPolyBlock.
## The front is the +Z face (the one the camera sees). `window_faces` lists faces with windows.

@export_range(1, 12) var floors: int = 3:
	set(v):
		floors = v
		_rebuild()
@export var trim_color: Color = Color(0.58, 0.58, 0.58):
	set(v):
		trim_color = v
		_rebuild()
@export_enum("flat", "gable", "none") var roof_type: String = "flat":
	set(v):
		roof_type = v
		_rebuild()
@export var roof_color: Color = Color(0.26, 0.25, 0.27):
	set(v):
		roof_color = v
		_rebuild()
## Faces with windows: any of "s" (front, +Z), "n", "e", "w".
@export var window_faces: String = "s":
	set(v):
		window_faces = v
		_rebuild()
@export var window_step: float = 3.2:
	set(v):
		window_step = v
		_rebuild()
@export_range(0.0, 1.0) var lit_windows: float = 0.12:
	set(v):
		lit_windows = v
		_rebuild()
@export_range(0.0, 1.0) var boarded_windows: float = 0.1:
	set(v):
		boarded_windows = v
		_rebuild()
@export_range(0.0, 1.0) var balconies: float = 0.0:
	set(v):
		balconies = v
		_rebuild()
@export var has_entrance: bool = false:
	set(v):
		has_entrance = v
		_rebuild()
## Entrance position along the front face (local X).
@export var entrance_x: float = 0.0:
	set(v):
		entrance_x = v
		_rebuild()
@export var shop_front: bool = false:
	set(v):
		shop_front = v
		_rebuild()
## Shop sign colour; alpha 0 = no sign.
@export var sign_color: Color = Color(0, 0, 0, 0):
	set(v):
		sign_color = v
		_rebuild()
@export var rooftop: bool = true:
	set(v):
		rooftop = v
		_rebuild()
@export var window_light: Color = Color(1.0, 0.74, 0.42):
	set(v):
		window_light = v
		_rebuild()
@export var seed_value: int = 1:
	set(v):
		seed_value = v
		_rebuild()

var _mb: MeshBuilder
var _rng := RandomNumberGenerator.new()
var _m := {}


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "Shape"
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	var key := "bld:%s|%s|%s|%d|%s|%s|%s|%s|%.2f|%.2f|%.2f|%.2f|%s|%.2f|%s|%s|%s|%s|%d|%.2f" % [
		size, color.to_html(), material, floors, trim_color.to_html(), roof_type, roof_color.to_html(),
		window_faces, window_step, lit_windows, boarded_windows, balconies, has_entrance, entrance_x,
		shop_front, sign_color.to_html(), rooftop, window_light.to_html(), seed_value, snow_mask]
	var mesh := MeshBuilder.cached(key)
	if mesh == null:
		mesh = _build()
		MeshBuilder.store(key, mesh)
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = shared_material(_fade)
	_mesh_instance.position = Vector3.ZERO
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := BoxShape3D.new()
	box.size = size
	_collision.shape = box
	_collision.position = Vector3(0, size.y * 0.5, 0)
	_collision.disabled = not has_collision and not fadeable
	collision_layer = 1 if has_collision else (128 if fadeable else 0)


func _build() -> ArrayMesh:
	_mb = MeshBuilder.new()
	_rng.seed = seed_value * 7919 + 17
	for n in ["concrete", "glass", "metal", "planks", "door", "paint", "roof", "brick", "fabric", "plastic"]:
		_m[n] = WorldTextures.id(n)
	var wall := resolve_material()
	var fh := size.y / float(floors)
	# Body and plinth.
	_box(size, Vector3(0, size.y * 0.5, 0), color, wall, snow_mask)
	_box(Vector3(size.x + 0.16, 0.75, size.z + 0.16), Vector3(0, 0.375, 0), color.darkened(0.35), _m.concrete, 1.0)
	# Floor ledges catch snow.
	for f in range(1, floors):
		_box(Vector3(size.x + 0.14, 0.12, size.z + 0.14), Vector3(0, f * fh, 0), trim_color, _m.concrete, 1.0)
	for face in ["s", "n", "e", "w"]:
		if window_faces.contains(face):
			_windows(face, fh)
	if balconies > 0.0:
		_balconies(fh)
	_drainpipes()
	if has_entrance:
		_entrance()
	if shop_front:
		_shop_front(fh)
	match roof_type:
		"flat":
			_flat_roof()
		"gable":
			_gable_roof()
	return _mb.commit()


# --- Parts ---------------------------------------------------------------------------------

func _box(s: Vector3, pos: Vector3, col: Color, mat: int, snow: float = 1.0, emit: float = 0.0, xf: Transform3D = Transform3D.IDENTITY, rot_z: float = 0.0) -> void:
	var b := BoxMesh.new()
	b.size = s
	var t := Transform3D(Basis(Vector3.BACK, deg_to_rad(rot_z)), pos)
	_mb.add(b, xf * t, col, snow, emit, mat)


func _cyl(r: float, h: float, pos: Vector3, col: Color, mat: int, snow: float = 0.5) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 6
	c.rings = 1
	_mb.add(c, Transform3D(Basis.IDENTITY, pos), col, snow, 0.0, mat)


## Transform from face space (x along the face, z out of it, origin on the face) to local.
func _face_xform(face: String) -> Transform3D:
	match face:
		"n":
			return Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -size.z * 0.5))
		"e":
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(size.x * 0.5, 0, 0))
		"w":
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-size.x * 0.5, 0, 0))
	return Transform3D(Basis.IDENTITY, Vector3(0, 0, size.z * 0.5))


func _face_length(face: String) -> float:
	return size.x if face in ["s", "n"] else size.z


func _slots(length: float) -> Array[float]:
	var out: Array[float] = []
	var n := maxi(1, int((length - 1.6) / window_step))
	var step := (length - 1.6) / float(n)
	for i in n:
		out.append(-length * 0.5 + 0.8 + step * (i + 0.5))
	return out


func _windows(face: String, fh: float) -> void:
	var xf := _face_xform(face)
	var front := face == "s"
	for f in floors:
		if f == 0 and front and shop_front:
			continue
		var y := f * fh + fh * 0.55
		for x in _slots(_face_length(face)):
			if f == 0 and front and has_entrance and absf(x - entrance_x) < 1.6:
				continue
			var r := _rng.randf()
			var boarded := boarded_windows * (2.0 if f == 0 else 1.0)
			if r < boarded:
				_window_boarded(xf, x, y)
			elif r < boarded + lit_windows:
				_window(xf, x, y, true)
			else:
				_window(xf, x, y, false)


func _window(xf: Transform3D, x: float, y: float, lit: bool) -> void:
	var w := 1.1
	var h := minf(1.4, size.y / floors - 1.1)
	_box(Vector3(w + 0.22, h + 0.22, 0.05), Vector3(x, y, 0.02), trim_color.darkened(0.15), _m.concrete, 0.2, 0.0, xf)
	var glass_col := window_light if lit else Color(0.07, 0.09, 0.12).lerp(Color(0.14, 0.17, 0.22), _rng.randf())
	_box(Vector3(w, h, 0.06), Vector3(x, y, 0.035), glass_col, _m.glass, 0.0, 1.5 if lit else 0.0, xf)
	if lit and _rng.randf() < 0.6:
		var cc: Color = [Color(0.7, 0.35, 0.25), Color(0.75, 0.65, 0.4), Color(0.4, 0.5, 0.35)][_rng.randi() % 3]
		_box(Vector3(w * 0.32, h, 0.02), Vector3(x - w * 0.34, y, 0.07), cc, _m.fabric, 0.0, 0.6, xf)
	elif not lit and _rng.randf() < 0.25:
		# Frost / old newspaper taped over half the pane.
		_box(Vector3(w * 0.5, h * 0.5, 0.02), Vector3(x + w * 0.2, y - h * 0.2, 0.07), Color(0.62, 0.64, 0.66), _m.paint, 0.0, 0.0, xf)
	_box(Vector3(0.05, h, 0.03), Vector3(x, y, 0.075), trim_color.darkened(0.25), _m.concrete, 0.0, 0.0, xf)
	_box(Vector3(w, 0.05, 0.03), Vector3(x, y + h * 0.22, 0.075), trim_color.darkened(0.25), _m.concrete, 0.0, 0.0, xf)
	_box(Vector3(w + 0.35, 0.07, 0.24), Vector3(x, y - h * 0.5 - 0.1, 0.1), trim_color, _m.concrete, 1.0, 0.0, xf)


func _window_boarded(xf: Transform3D, x: float, y: float) -> void:
	var w := 1.1
	var h := minf(1.4, size.y / floors - 1.1)
	_box(Vector3(w + 0.22, h + 0.22, 0.05), Vector3(x, y, 0.02), trim_color.darkened(0.15), _m.concrete, 0.2, 0.0, xf)
	_box(Vector3(w, h, 0.06), Vector3(x, y, 0.035), Color(0.04, 0.05, 0.06), _m.glass, 0.0, 0.0, xf)
	var wood := Color(0.46, 0.35, 0.23)
	for i in 3:
		var a := _rng.randf_range(-14.0, 14.0)
		_box(Vector3(w + 0.3, 0.17, 0.05), Vector3(x, y - h * 0.32 + i * h * 0.32, 0.09), wood.darkened(0.08 * i), _m.planks, 0.6, 0.0, xf, a)
	_box(Vector3(w + 0.35, 0.07, 0.24), Vector3(x, y - h * 0.5 - 0.1, 0.1), trim_color, _m.concrete, 1.0, 0.0, xf)


func _balconies(fh: float) -> void:
	var xf := _face_xform("s")
	for f in range(1, floors):
		for x in _slots(size.x):
			if _rng.randf() > balconies:
				continue
			var y := f * fh + 0.05
			var panel := [Color(0.62, 0.6, 0.55), Color(0.55, 0.3, 0.24), Color(0.42, 0.5, 0.56)][_rng.randi() % 3] as Color
			_box(Vector3(2.4, 0.14, 1.0), Vector3(x, y, 0.5), trim_color, _m.concrete, 1.0, 0.0, xf)
			_box(Vector3(2.4, 0.9, 0.06), Vector3(x, y + 0.52, 0.98), panel, _m.paint, 0.6, 0.0, xf)
			_box(Vector3(0.06, 0.9, 1.0), Vector3(x - 1.17, y + 0.52, 0.5), panel.darkened(0.15), _m.paint, 0.6, 0.0, xf)
			_box(Vector3(0.06, 0.9, 1.0), Vector3(x + 1.17, y + 0.52, 0.5), panel.darkened(0.15), _m.paint, 0.6, 0.0, xf)
			_box(Vector3(2.46, 0.06, 1.04), Vector3(x, y + 1.0, 0.5), Color(0.25, 0.25, 0.27), _m.metal, 1.0, 0.0, xf)
			if _rng.randf() < 0.4:
				# Stored junk: boxes / a sled / skis.
				_box(Vector3(0.5, 0.4, 0.4), Vector3(x + 0.6, y + 0.27, 0.45), Color(0.55, 0.45, 0.3), _m.paint, 1.0, 0.0, xf)


func _drainpipes() -> void:
	var metal := Color(0.44, 0.46, 0.5)
	for sx in [-1.0, 1.0]:
		_cyl(0.08, size.y, Vector3(sx * (size.x * 0.5 - 0.3), size.y * 0.5, size.z * 0.5 + 0.12), metal, _m.metal, 0.2)
		_box(Vector3(0.2, 0.18, 0.34), Vector3(sx * (size.x * 0.5 - 0.3), 0.12, size.z * 0.5 + 0.24), metal.darkened(0.1), _m.metal)


func _entrance() -> void:
	var z := size.z * 0.5
	var x := entrance_x
	_box(Vector3(1.8, 2.6, 0.08), Vector3(x, 1.3, z + 0.02), trim_color.darkened(0.3), _m.concrete, 0.2)
	_box(Vector3(1.4, 2.3, 0.1), Vector3(x, 1.15, z + 0.05), Color(0.28, 0.22, 0.17), _m.door, 0.0)
	_box(Vector3(0.1, 0.1, 0.08), Vector3(x + 0.48, 1.1, z + 0.12), Color(0.7, 0.62, 0.35), _m.metal, 0.0)
	_box(Vector3(2.6, 0.14, 1.3), Vector3(x, 2.75, z + 0.65), trim_color.darkened(0.1), _m.concrete, 1.0)
	_box(Vector3(2.4, 0.16, 0.9), Vector3(x, 0.08, z + 0.45), Color(0.45, 0.45, 0.47), _m.concrete, 1.0)
	# House plate + a small lamp over the door.
	_box(Vector3(0.5, 0.3, 0.03), Vector3(x + 1.3, 2.3, z + 0.02), Color(0.15, 0.3, 0.6), _m.paint, 0.0)
	_box(Vector3(0.3, 0.12, 0.02), Vector3(x + 1.3, 2.3, z + 0.04), Color(0.9, 0.9, 0.88), _m.paint, 0.0)
	_box(Vector3(0.25, 0.12, 0.15), Vector3(x, 2.55, z + 0.1), Color(1.0, 0.8, 0.5), _m.glass, 0.0, 1.2)


func _shop_front(fh: float) -> void:
	var xf := _face_xform("s")
	var h := minf(1.9, fh - 1.2)
	for x in _slots(size.x):
		if has_entrance and absf(x - entrance_x) < 1.6:
			continue
		_box(Vector3(2.4, h + 0.2, 0.05), Vector3(x, 0.8 + h * 0.5, 0.02), Color(0.2, 0.21, 0.23), _m.metal, 0.2, 0.0, xf)
		_box(Vector3(2.2, h, 0.06), Vector3(x, 0.8 + h * 0.5, 0.035), Color(0.1, 0.13, 0.17), _m.glass, 0.0, 0.0, xf)
		var shutter := _rng.randf()
		if shutter < 0.55:
			# Roller shutter pulled half / all the way down.
			var sh := h * (1.0 if shutter < 0.25 else 0.5)
			_box(Vector3(2.3, sh, 0.05), Vector3(x, 0.8 + h - sh * 0.5, 0.08), Color(0.52, 0.54, 0.56), _m.metal, 0.3, 0.0, xf)
		_box(Vector3(2.5, 0.08, 0.3), Vector3(x, 0.72, 0.12), Color(0.3, 0.3, 0.32), _m.concrete, 1.0, 0.0, xf)
	if sign_color.a > 0.0:
		var sy := fh - 0.45
		var sw := minf(size.x * 0.7, 9.0)
		_box(Vector3(sw, 0.7, 0.14), Vector3(0, sy, 0.1), sign_color, _m.paint, 0.4, 0.35, xf)
		var lx := -sw * 0.5 + 0.5
		while lx < sw * 0.5 - 0.5:
			var lw := _rng.randf_range(0.25, 0.4)
			_box(Vector3(lw, 0.36, 0.03), Vector3(lx + lw * 0.5, sy, 0.18), sign_color.lightened(0.65), _m.paint, 0.0, 0.6, xf)
			lx += lw + (0.35 if _rng.randf() < 0.15 else 0.08)


func _flat_roof() -> void:
	var top := size.y
	var t := 0.3
	var ph := 0.6
	var pc := trim_color.darkened(0.1)
	_box(Vector3(size.x, 0.08, size.z), Vector3(0, top + 0.04, 0), roof_color, _m.roof, 1.0)
	_box(Vector3(size.x + 0.1, ph, t), Vector3(0, top + ph * 0.5, size.z * 0.5 - t * 0.5 + 0.05), pc, _m.concrete, 1.0)
	_box(Vector3(size.x + 0.1, ph, t), Vector3(0, top + ph * 0.5, -size.z * 0.5 + t * 0.5 - 0.05), pc, _m.concrete, 1.0)
	_box(Vector3(t, ph, size.z), Vector3(size.x * 0.5 - t * 0.5 + 0.05, top + ph * 0.5, 0), pc, _m.concrete, 1.0)
	_box(Vector3(t, ph, size.z), Vector3(-size.x * 0.5 + t * 0.5 - 0.05, top + ph * 0.5, 0), pc, _m.concrete, 1.0)
	if not rooftop:
		return
	var hx := size.x * 0.5 - 1.5
	var hz := size.z * 0.5 - 1.5
	if size.y > 8.0 and size.x > 10.0:
		# Lift machine room.
		var mx := _rng.randf_range(-hx * 0.5, hx * 0.5)
		_box(Vector3(3.2, 2.2, 3.0), Vector3(mx, top + 1.1, -hz * 0.3), trim_color.darkened(0.2), _m.concrete, 1.0)
		_box(Vector3(0.9, 1.8, 0.06), Vector3(mx + 0.8, top + 0.9, -hz * 0.3 + 1.52), Color(0.35, 0.3, 0.25), _m.door, 0.2)
	for i in _rng.randi_range(2, 4):
		var p := Vector3(_rng.randf_range(-hx, hx), top, _rng.randf_range(-hz, hz))
		match _rng.randi() % 4:
			0:
				_box(Vector3(0.9, 0.6, 0.5), p + Vector3(0, 0.3, 0), Color(0.68, 0.7, 0.7), _m.metal, 1.0)
			1:
				_cyl(0.25, 0.9, p + Vector3(0, 0.45, 0), Color(0.5, 0.52, 0.55), _m.metal, 1.0)
				_box(Vector3(0.7, 0.06, 0.7), p + Vector3(0, 0.93, 0), Color(0.42, 0.44, 0.47), _m.metal, 1.0)
			2:
				_box(Vector3(0.8, 1.4, 0.8), p + Vector3(0, 0.7, 0), Color(0.42, 0.26, 0.2), _m.brick, 1.0)
			3:
				_box(Vector3(1.4, 0.5, 1.0), p + Vector3(0, 0.25, 0), Color(0.4, 0.42, 0.44), _m.metal, 1.0)
	if _rng.randf() < 0.6:
		var a := Vector3(_rng.randf_range(-hx, hx), top, _rng.randf_range(-hz, hz))
		_cyl(0.04, 3.0, a + Vector3(0, 1.5, 0), Color(0.35, 0.36, 0.38), _m.metal, 0.3)
		_box(Vector3(1.2, 0.04, 0.04), a + Vector3(0, 2.6, 0), Color(0.35, 0.36, 0.38), _m.metal, 0.3)
		_box(Vector3(0.8, 0.04, 0.04), a + Vector3(0, 2.2, 0), Color(0.35, 0.36, 0.38), _m.metal, 0.3)


func _gable_roof() -> void:
	var along_x := size.x >= size.z
	var rise := clampf(minf(size.x, size.z) * 0.28, 1.6, 4.0)
	var p := PrismMesh.new()
	if along_x:
		p.size = Vector3(size.z + 0.8, rise, size.x + 0.6)
		_mb.add(p, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, size.y + rise * 0.5, 0)), roof_color, 1.0, 0.0, _m.roof)
	else:
		p.size = Vector3(size.x + 0.8, rise, size.z + 0.6)
		_mb.add(p, Transform3D(Basis.IDENTITY, Vector3(0, size.y + rise * 0.5, 0)), roof_color, 1.0, 0.0, _m.roof)
	if rooftop:
		for i in _rng.randi_range(1, 2):
			var off := _rng.randf_range(-0.3, 0.3) * (size.x if along_x else size.z)
			var pos := Vector3(off, size.y + rise * 0.55, 0.4) if along_x else Vector3(0.4, size.y + rise * 0.55, off)
			_box(Vector3(0.7, rise * 0.9 + 0.6, 0.7), pos, Color(0.42, 0.26, 0.2), _m.brick, 1.0)
