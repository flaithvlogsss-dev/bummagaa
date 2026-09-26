class_name MapPanel
extends UIPanel
## MapPanel (M) — district map drawn from the District scene itself (blocks flagged
## show_on_map + LocationZones), discovered location names, the player and custom markers.
## Left click places the selected marker type, right click removes the nearest marker.

const DISTRICT_SCENE := "res://scenes/world/District.tscn"
const MARKER_TYPES := {
	"resource": ["Ресурсы", Color(0.55, 0.9, 0.55)],
	"npc": ["Люди", Color(0.55, 0.75, 1.0)],
	"danger": ["Опасность", Color(1.0, 0.4, 0.35)],
	"radio": ["Радио", Color(1.0, 0.85, 0.4)],
	"interest": ["Интересное", Color(0.9, 0.9, 0.95)],
}

static var _shapes: Array = []
static var _zones: Array = []
static var _bounds: Rect2 = Rect2(-80, -65, 160, 120)
static var _cached: bool = false

var _canvas: Control
var _marker_type: String = "interest"
var _type_buttons: Dictionary = {}


func _build() -> void:
	add_backdrop(0.7)
	var p := UIKit.centered(self, Vector2(900, 580))
	var col := UIKit.vbox(6)
	p.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	var t := UIKit.title("КАРТА КВАРТАЛА")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Закрыть [M]", close))
	var types := UIKit.hbox(6)
	col.add_child(types)
	types.add_child(UIKit.label("Метка:", 13, UIKit.TEXT_DIM))
	for k in MARKER_TYPES.keys():
		var b := UIKit.button(MARKER_TYPES[k][0], _select_type.bind(k))
		b.toggle_mode = true
		b.add_theme_color_override("font_color", MARKER_TYPES[k][1])
		types.add_child(b)
		_type_buttons[k] = b
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(870, 470)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_canvas_input)
	col.add_child(_canvas)
	col.add_child(UIKit.label("ЛКМ — поставить метку, ПКМ — убрать ближайшую.", 12, UIKit.TEXT_DIM))
	GameState.markers_changed.connect(func(): _canvas.queue_redraw())


func _on_open(_data: Dictionary) -> void:
	_ensure_cache()
	_select_type(_marker_type)
	_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if is_open:
		_canvas.queue_redraw()


func _select_type(k: String) -> void:
	_marker_type = k
	for key in _type_buttons.keys():
		_type_buttons[key].button_pressed = key == k


## Reads the district layout without adding it to the tree (works from inside the shelter too).
static func _ensure_cache() -> void:
	if _cached:
		return
	_cached = true
	var scene: PackedScene = load(DISTRICT_SCENE)
	if scene == null:
		return
	var root := scene.instantiate()
	if root is Level:
		_bounds = root.bounds
	_collect(root, root)
	root.free()


static func _collect(node: Node, root: Node) -> void:
	for c in node.get_children():
		if c is LowPolyBlock and c.show_on_map:
			var o := _origin(c, root)
			_shapes.append({"rect": Rect2(o.x - c.size.x * 0.5, o.z - c.size.z * 0.5, c.size.x, c.size.z), "color": c.color, "label": c.map_label})
		elif c is LocationZone:
			var o2 := _origin(c, root)
			var size := Vector3(10, 1, 10)
			for s in c.get_children():
				if s is CollisionShape3D and s.shape is BoxShape3D:
					size = s.shape.size
			_zones.append({"rect": Rect2(o2.x - size.x * 0.5, o2.z - size.z * 0.5, size.x, size.z), "id": c.location_id, "name": c.display_name})
		_collect(c, root)


static func _origin(node: Node3D, root: Node) -> Vector3:
	var t := node.transform
	var p := node.get_parent()
	while p != null and p != root:
		if p is Node3D:
			t = p.transform * t
		p = p.get_parent()
	return t.origin


func _to_screen(world: Vector2) -> Vector2:
	var s := _scale()
	var off := (_canvas.size - _bounds.size * s) * 0.5
	return off + (world - _bounds.position) * s


func _to_world(screen: Vector2) -> Vector2:
	var s := _scale()
	var off := (_canvas.size - _bounds.size * s) * 0.5
	return (screen - off) / s + _bounds.position


func _scale() -> float:
	return minf(_canvas.size.x / _bounds.size.x, _canvas.size.y / _bounds.size.y)


func _draw_map() -> void:
	var s := _scale()
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0.06, 0.07, 0.09))
	_canvas.draw_rect(Rect2(_to_screen(_bounds.position), _bounds.size * s), Color(0.78, 0.82, 0.88, 0.12))
	for z in _zones:
		var known: bool = GameState.discovered_locations.has(z.id)
		_canvas.draw_rect(Rect2(_to_screen(z.rect.position), z.rect.size * s), Color(0.5, 0.6, 0.75, 0.10 if known else 0.03))
	for sh in _shapes:
		var c: Color = sh.color
		_canvas.draw_rect(Rect2(_to_screen(sh.rect.position), sh.rect.size * s), Color(c.r, c.g, c.b, 0.85))
		_canvas.draw_rect(Rect2(_to_screen(sh.rect.position), sh.rect.size * s), Color(0.05, 0.05, 0.07), false, 1.0)
	var font := get_theme_default_font()
	for z in _zones:
		if GameState.discovered_locations.has(z.id):
			var center := _to_screen(z.rect.get_center())
			var w := font.get_string_size(z.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			_canvas.draw_string_outline(font, center - Vector2(w * 0.5, 0), z.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
			_canvas.draw_string(font, center - Vector2(w * 0.5, 0), z.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT)
	for m in GameState.map_markers:
		var info: Array = MARKER_TYPES.get(m.get("type", "interest"), MARKER_TYPES.interest)
		var pos := _to_screen(Vector2(float(m.x), float(m.y)))
		_canvas.draw_rect(Rect2(pos - Vector2(5, 5), Vector2(10, 10)), info[1])
		_canvas.draw_rect(Rect2(pos - Vector2(5, 5), Vector2(10, 10)), Color.BLACK, false, 1.0)
	var player := Main.get_player()
	var ppos := Vector2.ZERO
	if GameState.current_location == "district" and player:
		ppos = Vector2(player.global_position.x, player.global_position.z)
		var dir: Vector2 = player.facing
		var pp := _to_screen(ppos)
		var pts := PackedVector2Array([pp + dir * 9, pp + dir.orthogonal() * 5 - dir * 4, pp - dir.orthogonal() * 5 - dir * 4])
		_canvas.draw_colored_polygon(pts, UIKit.ACCENT)
	else:
		_canvas.draw_string(font, Vector2(10, 20), "Вы в убежище.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.ACCENT)


func _on_canvas_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var world := _to_world(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		GameState.add_marker(_marker_type, world, MARKER_TYPES[_marker_type][0])
		AudioManager.play_ui("click")
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		var best := -1
		var best_d := 8.0
		for i in GameState.map_markers.size():
			var m: Dictionary = GameState.map_markers[i]
			var d := Vector2(float(m.x), float(m.y)).distance_to(world)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			GameState.remove_marker(best)
