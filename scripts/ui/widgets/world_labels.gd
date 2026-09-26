class_name WorldLabels
extends Control
## WorldLabels — crisp names above nearby people, drawn at screen resolution on the HUD
## (3D labels inside the low-resolution world view were unreadable).

const HEAD_HEIGHT := 2.25


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := UIKit.small_font()
	var size_px := 15
	var inv := get_global_transform_with_canvas().affine_inverse()
	for n in get_tree().get_nodes_in_group("npc"):
		if not n.get("show_name"):
			continue
		var at: Variant = Main.world_to_canvas((n as Node3D).global_position + Vector3(0, HEAD_HEIGHT, 0))
		if at == null:
			continue
		var p: Vector2 = inv * (at as Vector2)
		var text := str(n.get("name_text"))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var pos := (p - Vector2(w * 0.5, 0)).round()
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, Color(0, 0, 0, 0.85))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1, 0.92, 0.8))
