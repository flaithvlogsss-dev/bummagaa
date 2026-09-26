@tool
class_name LowPolyProp
extends StaticBody3D
## LowPolyProp — composite placeholder props built from primitives (car, lamp, bed, ...).
##
## Purpose: every prop is one node with a `kind`, so levels stay readable and editable.
##   Replace a prop with real art by swapping this node for an imported model scene.
## Public API: set_lit(bool), set_occluding(bool), set_cutaway(bool)

const KINDS := [
	"car", "lamp", "barrel_fire", "bench", "pine", "drift", "bin", "antenna", "fence", "crate",
	"pallet", "barricade", "bus", "tracks", "device", "symbol", "kiosk", "notice_board", "hydrant",
	"window", "bed", "shelf", "table", "stove", "generator", "workbench", "radio_set", "phone",
	"counter", "wardrobe", "chair", "transmitter", "board", "candle", "ceiling_lamp", "rubble",
	"door_frame", "body_bag",
]

@export_enum("car", "lamp", "barrel_fire", "bench", "pine", "drift", "bin", "antenna", "fence", "crate",
	"pallet", "barricade", "bus", "tracks", "device", "symbol", "kiosk", "notice_board", "hydrant",
	"window", "bed", "shelf", "table", "stove", "generator", "workbench", "radio_set", "phone",
	"counter", "wardrobe", "chair", "transmitter", "board", "candle", "ceiling_lamp", "rubble",
	"door_frame", "body_bag") var kind: String = "crate":
	set(v):
		kind = v
		_rebuild()
## Main colour; alpha 0 means "use the kind's default colour".
@export var color: Color = Color(0, 0, 0, 0):
	set(v):
		color = v
		_rebuild()
## Scale parameter for stretchable kinds (drift, fence, tracks, counter...).
@export var size: Vector3 = Vector3.ONE:
	set(v):
		size = v
		_rebuild()
@export var lit: bool = true:
	set(v):
		lit = v
		_rebuild()
@export var flicker: bool = false
@export var light_color: Color = Color(1.0, 0.72, 0.4)
@export var light_energy: float = 1.6
@export var light_range: float = 8.0
@export var light_shadows: bool = false
@export var has_collision: bool = true:
	set(v):
		has_collision = v
		_rebuild()
@export var fadeable: bool = true
## Blocks/props sharing a fade group (e.g. body, roof and windows of one building) fade together.
@export var fade_group: String = ""
@export var map_label: String = ""

var _parts: Array[MeshInstance3D] = []
var _mb: MeshBuilder
var _casts_shadow: bool = true
var _light: OmniLight3D
var _flicker_t: float = 0.0
var _fade_tween: Tween
var _fade: float = 0.0
var _occluding: bool = false
var _cutaway: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not flicker or _light == null or not lit:
		return
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		_flicker_t = randf_range(0.04, 0.22)
		var dead := randf() < 0.12
		_light.light_energy = 0.05 if dead else light_energy * randf_range(0.7, 1.1)


func set_lit(value: bool) -> void:
	lit = value


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.get_meta("_prop_part", false):
			c.queue_free()
			remove_child(c)
	_parts.clear()
	_light = null
	_casts_shadow = kind not in ["tracks", "symbol", "window", "door_frame"]
	set_process(flicker and not Engine.is_editor_hint())
	var key := "prop:%s:%s:%s:%s:%s" % [kind, color.to_html(), size, lit, light_color.to_html()]
	var mesh := MeshBuilder.cached(key)
	_mb = null if mesh else MeshBuilder.new()
	var builder: Callable = Callable(self, "_build_" + kind)
	if builder.is_valid():
		builder.call()
	else:
		_build_crate()
	if mesh == null:
		mesh = _mb.commit()
		MeshBuilder.store(key, mesh)
	_mb = null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = LowPolyBlock.shared_material(_fade)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("_prop_part", true)
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	_parts.append(mi)


# --- Helpers -----------------------------------------------------------------------

func _c(default: Color) -> Color:
	return color if color.a > 0.0 else default


func _part(mesh: PrimitiveMesh, pos: Vector3, col: Color, rot_deg: Vector3 = Vector3.ZERO, snow: float = 1.0, emission: float = 0.0, scale_v: Vector3 = Vector3.ONE) -> void:
	if _mb == null:
		return
	var basis := Basis.from_euler(rot_deg * (PI / 180.0)).scaled_local(scale_v)
	_mb.add(mesh, Transform3D(basis, pos), col, snow, emission)


func _box(s: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, snow: float = 1.0, emission: float = 0.0) -> void:
	var m := BoxMesh.new()
	m.size = s
	_part(m, pos, col, rot, snow, emission)


func _cyl(radius: float, height: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, top_radius: float = -1.0, segments: int = 8, snow: float = 1.0, emission: float = 0.0) -> void:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	_part(m, pos, col, rot, snow, emission)


func _sphere(radius: float, height: float, pos: Vector3, col: Color, scale_v: Vector3 = Vector3.ONE) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 5
	_part(m, pos, col, Vector3.ZERO, 1.0, 0.0, scale_v)


func _col(s: Vector3, pos: Vector3) -> void:
	if not has_collision:
		return
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = s
	cs.shape = shape
	cs.position = pos
	cs.set_meta("_prop_part", true)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)


func _omni(pos: Vector3, col: Color, energy: float, light_range_m: float, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = light_range_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.set_meta("_prop_part", true)
	add_child(l, false, Node.INTERNAL_MODE_FRONT)
	_light = l
	return l


# --- Street props ------------------------------------------------------------------------

func _build_car() -> void:
	var body := _c(Color(0.42, 0.18, 0.16))
	_box(Vector3(4.2, 0.75, 1.9), Vector3(0, 0.62, 0), body)
	_box(Vector3(2.3, 0.7, 1.75), Vector3(-0.25, 1.33, 0), body.darkened(0.15))
	_box(Vector3(2.35, 0.45, 1.8), Vector3(-0.25, 1.35, 0), Color(0.1, 0.12, 0.16), Vector3.ZERO, 0.0)
	for x in [-1.35, 1.35]:
		for z in [-0.9, 0.9]:
			_cyl(0.36, 0.28, Vector3(x, 0.36, z), Color(0.08, 0.08, 0.09), Vector3(90, 0, 0))
	_box(Vector3(0.1, 0.18, 0.4), Vector3(2.1, 0.75, 0.6), Color(0.9, 0.85, 0.6), Vector3.ZERO, 0.0, 0.0)
	_col(Vector3(4.2, 1.7, 1.9), Vector3(0, 0.85, 0))


func _build_bus() -> void:
	var c := _c(Color(0.62, 0.52, 0.22))
	_box(Vector3(10.0, 2.6, 2.6), Vector3(0, 1.3, 0), c)
	for i in 5:
		_box(Vector3(1.4, 0.8, 0.05), Vector3(-3.6 + i * 1.8, 1.8, 1.31), Color(0.1, 0.12, 0.15), Vector3.ZERO, 0.0)
	_col(Vector3(10.0, 2.6, 2.6), Vector3(0, 1.3, 0))


func _build_lamp() -> void:
	var metal := _c(Color(0.2, 0.22, 0.25))
	_cyl(0.08, 4.6, Vector3(0, 2.3, 0), metal)
	_box(Vector3(1.1, 0.08, 0.08), Vector3(0.5, 4.55, 0), metal)
	_box(Vector3(0.5, 0.14, 0.28), Vector3(1.0, 4.45, 0), Color(1.0, 0.85, 0.6) if lit else Color(0.15, 0.15, 0.17), Vector3.ZERO, 0.0, 2.5 if lit else 0.0)
	if lit:
		_omni(Vector3(1.0, 4.0, 0), light_color, light_energy, light_range, light_shadows)
	_col(Vector3(0.3, 4.6, 0.3), Vector3(0, 2.3, 0))


func _build_barrel_fire() -> void:
	_cyl(0.42, 1.0, Vector3(0, 0.5, 0), _c(Color(0.35, 0.2, 0.12)))
	if lit:
		_box(Vector3(0.5, 0.25, 0.5), Vector3(0, 1.05, 0), Color(1.0, 0.45, 0.1), Vector3(0, 20, 0), 0.0, 4.0)
		_box(Vector3(0.3, 0.35, 0.3), Vector3(0.05, 1.2, 0), Color(1.0, 0.7, 0.25), Vector3(0, 55, 0), 0.0, 5.0)
		_omni(Vector3(0, 1.6, 0), Color(1.0, 0.55, 0.22), light_energy * 1.6, light_range, true)
		set_process(not Engine.is_editor_hint())
		flicker = true
	_col(Vector3(0.9, 1.0, 0.9), Vector3(0, 0.5, 0))


func _build_bench() -> void:
	var wood := _c(Color(0.35, 0.24, 0.16))
	_box(Vector3(1.8, 0.1, 0.5), Vector3(0, 0.45, 0), wood)
	_box(Vector3(1.8, 0.45, 0.08), Vector3(0, 0.75, -0.22), wood)
	for x in [-0.8, 0.8]:
		_box(Vector3(0.08, 0.45, 0.45), Vector3(x, 0.22, 0), Color(0.15, 0.15, 0.17))
	_col(Vector3(1.8, 0.9, 0.5), Vector3(0, 0.45, 0))


func _build_pine() -> void:
	var green := _c(Color(0.12, 0.22, 0.18))
	var s := size.y
	_cyl(0.15, 1.2 * s, Vector3(0, 0.6 * s, 0), Color(0.22, 0.15, 0.1))
	_cyl(1.5 * s, 1.8 * s, Vector3(0, 1.8 * s, 0), green, Vector3.ZERO, 0.0, 7)
	_cyl(1.15 * s, 1.6 * s, Vector3(0, 2.8 * s, 0), green.lightened(0.05), Vector3.ZERO, 0.0, 7)
	_cyl(0.8 * s, 1.4 * s, Vector3(0, 3.7 * s, 0), green.lightened(0.1), Vector3.ZERO, 0.0, 7)
	_col(Vector3(0.6, 3.0 * s, 0.6), Vector3(0, 1.5 * s, 0))


func _build_drift() -> void:
	_sphere(1.0, 1.0, Vector3(0, 0, 0), _c(Color(0.86, 0.9, 0.96)), size)
	_col(Vector3(size.x * 1.8, size.y, size.z * 1.8), Vector3(0, size.y * 0.25, 0))


func _build_rubble() -> void:
	var c := _c(Color(0.4, 0.4, 0.42))
	_box(Vector3(1.4, 0.6, 1.0), Vector3(0, 0.3, 0), c, Vector3(0, 15, 8))
	_box(Vector3(0.9, 0.5, 0.8), Vector3(0.9, 0.25, 0.5), c.darkened(0.1), Vector3(5, -30, 0))
	_box(Vector3(1.8, 0.12, 0.25), Vector3(-0.4, 0.7, 0.3), Color(0.3, 0.22, 0.15), Vector3(0, 40, 20))
	_col(Vector3(2.4, 0.9, 1.6), Vector3(0.2, 0.45, 0.2))


func _build_bin() -> void:
	var c := _c(Color(0.16, 0.3, 0.22))
	_box(Vector3(1.6, 1.05, 1.0), Vector3(0, 0.55, 0), c)
	_box(Vector3(1.65, 0.1, 1.05), Vector3(0, 1.12, 0), c.darkened(0.3))
	_col(Vector3(1.6, 1.15, 1.0), Vector3(0, 0.57, 0))


func _build_antenna() -> void:
	var metal := _c(Color(0.45, 0.45, 0.5))
	var h := 8.0 * size.y
	_cyl(0.07, h, Vector3(0, h * 0.5, 0), metal, Vector3.ZERO, -1.0, 6)
	for i in 4:
		_box(Vector3(1.2 - i * 0.2, 0.05, 0.05), Vector3(0, h * (0.4 + i * 0.15), 0), metal)
	_box(Vector3(0.15, 0.15, 0.15), Vector3(0, h + 0.05, 0), Color(1.0, 0.15, 0.1), Vector3.ZERO, 0.0, 3.0 if lit else 0.0)
	_col(Vector3(0.4, h, 0.4), Vector3(0, h * 0.5, 0))


func _build_fence() -> void:
	var c := _c(Color(0.3, 0.3, 0.33))
	var length := size.x * 4.0
	var posts := int(length / 2.0) + 1
	for i in posts:
		_box(Vector3(0.1, 1.6, 0.1), Vector3(-length * 0.5 + i * (length / max(1, posts - 1)), 0.8, 0), c)
	_box(Vector3(length, 0.06, 0.06), Vector3(0, 1.4, 0), c)
	_box(Vector3(length, 0.06, 0.06), Vector3(0, 0.6, 0), c)
	_box(Vector3(length, 1.2, 0.02), Vector3(0, 0.9, 0), c.lightened(0.1), Vector3.ZERO, 0.0)
	_col(Vector3(length, 1.8, 0.3), Vector3(0, 0.9, 0))


func _build_crate() -> void:
	var c := _c(Color(0.45, 0.33, 0.2))
	_box(Vector3(0.8, 0.7, 0.8) * size, Vector3(0, 0.35 * size.y, 0), c)
	_box(Vector3(0.82, 0.08, 0.82) * size, Vector3(0, 0.6 * size.y, 0), c.darkened(0.2))
	_col(Vector3(0.8, 0.7, 0.8) * size, Vector3(0, 0.35 * size.y, 0))


func _build_pallet() -> void:
	var c := _c(Color(0.55, 0.42, 0.28))
	for i in 3:
		_box(Vector3(1.2, 0.14, 1.0), Vector3(0, 0.08 + i * 0.16, 0), c.darkened(i * 0.05), Vector3(0, i * 9, 0))
	_col(Vector3(1.2, 0.5, 1.0), Vector3(0, 0.25, 0))


func _build_barricade() -> void:
	var length := size.x * 6.0
	var n := int(length / 1.5)
	for i in n:
		_box(Vector3(1.3, 0.9, 0.7), Vector3(-length * 0.5 + 0.75 + i * 1.5, 0.45, 0), Color(0.55, 0.55, 0.56))
	for i in n:
		var stripe := Color(0.8, 0.12, 0.1) if i % 2 == 0 else Color(0.9, 0.9, 0.9)
		_box(Vector3(1.5, 0.25, 0.08), Vector3(-length * 0.5 + 0.75 + i * 1.5, 1.35, 0), stripe, Vector3.ZERO, 0.4)
	_box(Vector3(length, 0.1, 0.1), Vector3(0, 1.2, 0), Color(0.2, 0.2, 0.2))
	_col(Vector3(length, 1.6, 0.9), Vector3(0, 0.8, 0))


func _build_tracks() -> void:
	# Three-toed prints of something that walks upright. Length along -Z.
	var steps := int(size.z * 4.0)
	var c := _c(Color(0.28, 0.33, 0.42))
	for i in steps:
		var side := -0.28 if i % 2 == 0 else 0.28
		var base := Vector3(side, 0.03, -i * 1.3)
		for t in 3:
			_box(Vector3(0.09, 0.02, 0.42), base + Vector3((t - 1) * 0.14, 0, -0.1 - abs(t - 1) * 0.05), c, Vector3(0, (t - 1) * 14.0, 0), 0.0)
		_box(Vector3(0.26, 0.02, 0.2), base + Vector3(0, 0, 0.18), c, Vector3.ZERO, 0.0)


func _build_device() -> void:
	# Unknown faction object: warm to the touch; snow never settles around it.
	_cyl(2.2, 0.02, Vector3(0, 0.01, 0), Color(0.12, 0.12, 0.14), Vector3.ZERO, -1.0, 16, 0.0)
	_cyl(0.28, 0.9, Vector3(0, 0.45, 0), _c(Color(0.16, 0.17, 0.2)), Vector3.ZERO, 0.22, 8, 0.0)
	_cyl(0.3, 0.06, Vector3(0, 0.55, 0), Color(1.0, 0.5, 0.2), Vector3.ZERO, -1.0, 8, 0.0, 3.0)
	_cyl(0.3, 0.06, Vector3(0, 0.3, 0), Color(1.0, 0.5, 0.2), Vector3.ZERO, -1.0, 8, 0.0, 2.0)
	if lit:
		_omni(Vector3(0, 0.8, 0), Color(1.0, 0.5, 0.25), 0.9, 4.0)
	_col(Vector3(0.6, 0.9, 0.6), Vector3(0, 0.45, 0))


func _build_symbol() -> void:
	# Painted ring with three falling lines — the mark of the Unknown.
	var paint := _c(Color(0.75, 0.9, 0.95))
	var r := 0.55
	for i in 12:
		var a := TAU * i / 12.0
		_box(Vector3(0.3, 0.07, 0.03), Vector3(cos(a) * r, 1.8 + sin(a) * r, 0), paint, Vector3(0, 0, rad_to_deg(a) + 90.0), 0.0, 0.6)
	for i in 3:
		_box(Vector3(0.06, 0.55 - abs(i - 1) * 0.15, 0.03), Vector3((i - 1) * 0.2, 1.8 - abs(i - 1) * 0.05, 0), paint, Vector3.ZERO, 0.0, 0.6)


func _build_kiosk() -> void:
	var c := _c(Color(0.3, 0.36, 0.42))
	_box(Vector3(2.6, 2.6, 2.4), Vector3(0, 1.3, 0), c)
	_box(Vector3(3.0, 0.2, 2.8), Vector3(0, 2.7, 0), c.darkened(0.3))
	_box(Vector3(1.6, 0.8, 0.05), Vector3(0, 1.6, 1.21), Color(0.9, 0.75, 0.45) if lit else Color(0.08, 0.1, 0.12), Vector3.ZERO, 0.0, 1.2 if lit else 0.0)
	_cyl(0.05, 5.0, Vector3(0.9, 5.2, -0.8), Color(0.5, 0.5, 0.55))
	_box(Vector3(1.4, 0.05, 0.05), Vector3(0.9, 7.2, -0.8), Color(0.5, 0.5, 0.55))
	_box(Vector3(0.12, 0.12, 0.12), Vector3(0.9, 7.8, -0.8), Color(1.0, 0.2, 0.1), Vector3.ZERO, 0.0, 3.0)
	if lit:
		_omni(Vector3(0, 1.8, 1.8), Color(0.95, 0.8, 0.55), 0.8, 5.0)
	_col(Vector3(2.6, 2.8, 2.4), Vector3(0, 1.4, 0))


func _build_notice_board() -> void:
	var wood := _c(Color(0.3, 0.22, 0.15))
	_box(Vector3(0.1, 2.0, 0.1), Vector3(-0.8, 1.0, 0), wood)
	_box(Vector3(0.1, 2.0, 0.1), Vector3(0.8, 1.0, 0), wood)
	_box(Vector3(1.8, 1.0, 0.08), Vector3(0, 1.5, 0), wood.lightened(0.1))
	for i in 3:
		_box(Vector3(0.35, 0.45, 0.02), Vector3(-0.5 + i * 0.5, 1.5 + (i % 2) * 0.1, 0.06), Color(0.9, 0.9, 0.85), Vector3(0, 0, (i - 1) * 6), 0.0)
	_col(Vector3(1.8, 2.0, 0.3), Vector3(0, 1.0, 0))


func _build_hydrant() -> void:
	_cyl(0.18, 0.8, Vector3(0, 0.4, 0), _c(Color(0.7, 0.15, 0.1)))
	_col(Vector3(0.4, 0.8, 0.4), Vector3(0, 0.4, 0))


func _build_window() -> void:
	var glow := lit
	_box(Vector3(1.0 * size.x, 1.2 * size.y, 0.08), Vector3(0, 0, 0), light_color if glow else Color(0.08, 0.1, 0.13), Vector3.ZERO, 0.0, 1.8 if glow else 0.0)
	_box(Vector3(1.1 * size.x, 0.08, 0.15), Vector3(0, -0.62 * size.y, 0.04), Color(0.3, 0.3, 0.32))


func _build_door_frame() -> void:
	var c := _c(Color(0.25, 0.2, 0.16))
	_box(Vector3(1.4, 2.3, 0.12), Vector3(0, 1.15, 0), c, Vector3.ZERO, 0.0)
	_box(Vector3(0.12, 0.12, 0.14), Vector3(0.45, 1.1, 0.07), Color(0.7, 0.65, 0.4), Vector3.ZERO, 0.0)


func _build_body_bag() -> void:
	_box(Vector3(0.6, 0.25, 1.8), Vector3(0, 0.12, 0), _c(Color(0.15, 0.17, 0.2)))


# --- Interior props ----------------------------------------------------------------------

func _build_bed() -> void:
	var c := _c(Color(0.35, 0.3, 0.4))
	_box(Vector3(1.1, 0.4, 2.1), Vector3(0, 0.2, 0), Color(0.3, 0.22, 0.15), Vector3.ZERO, 0.0)
	_box(Vector3(1.0, 0.18, 1.5), Vector3(0, 0.49, 0.25), c, Vector3.ZERO, 0.0)
	_box(Vector3(0.8, 0.15, 0.4), Vector3(0, 0.48, -0.75), Color(0.85, 0.85, 0.82), Vector3.ZERO, 0.0)
	_col(Vector3(1.1, 0.6, 2.1), Vector3(0, 0.3, 0))


func _build_shelf() -> void:
	var c := _c(Color(0.4, 0.32, 0.22))
	_box(Vector3(1.8 * size.x, 2.0, 0.08), Vector3(0, 1.0, -0.22), c.darkened(0.2), Vector3.ZERO, 0.0)
	for i in 4:
		_box(Vector3(1.8 * size.x, 0.06, 0.5), Vector3(0, 0.3 + i * 0.5, 0), c, Vector3.ZERO, 0.0)
		_box(Vector3(0.3, 0.25, 0.3), Vector3(-0.5 + (i % 3) * 0.4, 0.45 + i * 0.5, 0), Color(0.5, 0.45, 0.35).lerp(Color(0.3, 0.4, 0.5), i * 0.3), Vector3.ZERO, 0.0)
	_col(Vector3(1.8 * size.x, 2.0, 0.55), Vector3(0, 1.0, 0))


func _build_table() -> void:
	var c := _c(Color(0.42, 0.3, 0.2))
	_box(Vector3(1.4 * size.x, 0.08, 0.8 * size.z), Vector3(0, 0.78, 0), c, Vector3.ZERO, 0.0)
	for x in [-0.6, 0.6]:
		for z in [-0.32, 0.32]:
			_box(Vector3(0.07, 0.78, 0.07), Vector3(x * size.x, 0.39, z * size.z), c.darkened(0.2), Vector3.ZERO, 0.0)
	_col(Vector3(1.4 * size.x, 0.85, 0.8 * size.z), Vector3(0, 0.42, 0))


func _build_counter() -> void:
	var c := _c(Color(0.38, 0.36, 0.34))
	_box(Vector3(2.0 * size.x, 1.0, 0.7), Vector3(0, 0.5, 0), c, Vector3.ZERO, 0.0)
	_box(Vector3(2.05 * size.x, 0.06, 0.75), Vector3(0, 1.02, 0), c.lightened(0.2), Vector3.ZERO, 0.0)
	_col(Vector3(2.0 * size.x, 1.05, 0.7), Vector3(0, 0.52, 0))


func _build_wardrobe() -> void:
	var c := _c(Color(0.32, 0.24, 0.18))
	_box(Vector3(1.2, 2.1, 0.6), Vector3(0, 1.05, 0), c, Vector3.ZERO, 0.0)
	_box(Vector3(0.02, 1.9, 0.02), Vector3(0, 1.05, 0.31), c.darkened(0.4), Vector3.ZERO, 0.0)
	_col(Vector3(1.2, 2.1, 0.6), Vector3(0, 1.05, 0))


func _build_chair() -> void:
	var c := _c(Color(0.4, 0.28, 0.18))
	_box(Vector3(0.45, 0.06, 0.45), Vector3(0, 0.45, 0), c, Vector3.ZERO, 0.0)
	_box(Vector3(0.45, 0.5, 0.06), Vector3(0, 0.72, -0.2), c, Vector3.ZERO, 0.0)
	_col(Vector3(0.45, 0.9, 0.45), Vector3(0, 0.45, 0))


func _build_stove() -> void:
	var c := _c(Color(0.18, 0.18, 0.2))
	_box(Vector3(0.9, 0.9, 0.7), Vector3(0, 0.45, 0), c, Vector3.ZERO, 0.0)
	_cyl(0.1, 2.2, Vector3(0, 2.0, -0.2), c.darkened(0.2), Vector3.ZERO, -1.0, 6, 0.0)
	_box(Vector3(0.45, 0.3, 0.04), Vector3(0, 0.45, 0.36), Color(1.0, 0.45, 0.1) if lit else Color(0.05, 0.05, 0.05), Vector3.ZERO, 0.0, 4.0 if lit else 0.0)
	if lit:
		_omni(Vector3(0, 0.9, 0.8), Color(1.0, 0.55, 0.25), light_energy, light_range, true)
		flicker = true
		set_process(not Engine.is_editor_hint())
	_col(Vector3(0.9, 0.9, 0.7), Vector3(0, 0.45, 0))


func _build_generator() -> void:
	var c := _c(Color(0.45, 0.4, 0.15))
	_box(Vector3(1.3, 0.9, 0.8), Vector3(0, 0.45, 0), c, Vector3.ZERO, 0.0)
	_cyl(0.25, 0.9, Vector3(0.2, 0.5, 0), Color(0.2, 0.2, 0.22), Vector3(0, 0, 90), -1.0, 8, 0.0)
	_box(Vector3(0.15, 0.1, 0.02), Vector3(-0.4, 0.75, 0.41), Color(0.2, 1.0, 0.3) if lit else Color(0.4, 0.05, 0.05), Vector3.ZERO, 0.0, 3.0)
	_col(Vector3(1.3, 0.9, 0.8), Vector3(0, 0.45, 0))


func _build_workbench() -> void:
	var c := _c(Color(0.45, 0.35, 0.22))
	_box(Vector3(2.0, 0.1, 0.9), Vector3(0, 0.9, 0), c, Vector3.ZERO, 0.0)
	for x in [-0.9, 0.9]:
		_box(Vector3(0.1, 0.9, 0.8), Vector3(x, 0.45, 0), c.darkened(0.2), Vector3.ZERO, 0.0)
	_box(Vector3(0.4, 0.25, 0.3), Vector3(-0.5, 1.07, 0), Color(0.3, 0.32, 0.35), Vector3.ZERO, 0.0)
	_box(Vector3(0.6, 0.05, 0.1), Vector3(0.4, 0.98, 0.1), Color(0.6, 0.6, 0.62), Vector3(0, 20, 0), 0.0)
	_col(Vector3(2.0, 1.0, 0.9), Vector3(0, 0.5, 0))


func _build_radio_set() -> void:
	_box(Vector3(0.9, 0.8, 0.6), Vector3(0, 0.4, 0), Color(0.3, 0.3, 0.28), Vector3.ZERO, 0.0)
	_box(Vector3(0.7, 0.45, 0.4), Vector3(0, 1.02, 0), _c(Color(0.25, 0.2, 0.15)), Vector3.ZERO, 0.0)
	_box(Vector3(0.35, 0.12, 0.02), Vector3(-0.1, 1.08, 0.21), Color(1.0, 0.7, 0.3) if lit else Color(0.1, 0.08, 0.05), Vector3.ZERO, 0.0, 2.0 if lit else 0.0)
	_cyl(0.015, 0.7, Vector3(0.25, 1.55, -0.1), Color(0.6, 0.6, 0.6), Vector3(0, 0, -15), -1.0, 4, 0.0)
	_col(Vector3(0.9, 1.3, 0.6), Vector3(0, 0.65, 0))


func _build_transmitter() -> void:
	_box(Vector3(1.2, 1.4, 0.7), Vector3(0, 0.7, 0), _c(Color(0.22, 0.26, 0.3)), Vector3.ZERO, 0.0)
	for i in 3:
		_box(Vector3(0.12, 0.08, 0.02), Vector3(-0.3 + i * 0.3, 1.1, 0.36), [Color(0.2, 1, 0.3), Color(1, 0.7, 0.2), Color(1, 0.2, 0.2)][i], Vector3.ZERO, 0.0, 3.0)
	_box(Vector3(0.9, 0.35, 0.02), Vector3(0, 0.65, 0.36), Color(0.2, 0.5, 0.45), Vector3.ZERO, 0.0, 1.0)
	_col(Vector3(1.2, 1.4, 0.7), Vector3(0, 0.7, 0))


func _build_phone() -> void:
	_box(Vector3(0.5, 0.75, 0.4), Vector3(0, 0.375, 0), Color(0.3, 0.22, 0.15), Vector3.ZERO, 0.0)
	_box(Vector3(0.25, 0.1, 0.18), Vector3(0, 0.8, 0), _c(Color(0.6, 0.1, 0.08)), Vector3.ZERO, 0.0)
	_col(Vector3(0.5, 0.85, 0.4), Vector3(0, 0.42, 0))


func _build_board() -> void:
	_box(Vector3(1.6, 1.1, 0.06), Vector3(0, 1.5, 0), _c(Color(0.35, 0.3, 0.22)), Vector3.ZERO, 0.0)
	for i in 4:
		_box(Vector3(0.3, 0.35, 0.02), Vector3(-0.55 + i * 0.37, 1.55, 0.04), Color(0.85, 0.85, 0.8), Vector3(0, 0, (i % 2) * 5.0), 0.0)
	_col(Vector3(1.6, 1.1, 0.2), Vector3(0, 1.5, 0))


func _build_candle() -> void:
	_cyl(0.04, 0.2, Vector3(0, 0.1, 0), Color(0.9, 0.88, 0.8), Vector3.ZERO, -1.0, 6, 0.0)
	if lit:
		_box(Vector3(0.03, 0.06, 0.03), Vector3(0, 0.23, 0), Color(1.0, 0.7, 0.3), Vector3.ZERO, 0.0, 6.0)
		_omni(Vector3(0, 0.4, 0), Color(1.0, 0.65, 0.3), light_energy, light_range)
		flicker = true
		set_process(not Engine.is_editor_hint())


func _build_ceiling_lamp() -> void:
	_box(Vector3(0.4, 0.1, 0.4), Vector3(0, 2.9, 0), Color(0.9, 0.9, 0.8) if lit else Color(0.2, 0.2, 0.2), Vector3.ZERO, 0.0, 3.0 if lit else 0.0)
	if lit:
		_omni(Vector3(0, 2.6, 0), light_color, light_energy, light_range, light_shadows)


# --- Fading ---------------------------------------------------------------------------------

func set_occluding(value: bool) -> void:
	if not fadeable or value == _occluding:
		return
	_occluding = value
	_update_fade()


func set_cutaway(value: bool) -> void:
	if value == _cutaway:
		return
	_cutaway = value
	_update_fade()


func _update_fade() -> void:
	var target := 0.92 if _cutaway else (0.8 if _occluding else 0.0)
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_fade_now, _fade, target, 0.25)


func _set_fade_now(v: float) -> void:
	_fade = v
	var m := LowPolyBlock.shared_material(v)
	for p in _parts:
		if is_instance_valid(p) and p.material_override != m:
			p.material_override = m
