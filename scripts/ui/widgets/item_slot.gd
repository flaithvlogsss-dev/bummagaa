class_name ItemSlot
extends Control
## ItemSlot — one inventory cell: pixel icon, count, wear bar, quality mark, quick-slot key.
##
## Purpose: shared by the backpack grid, equipment slots, containers and storage. It only
##   displays a stack and reports clicks / drags; the owning panel decides what they mean.
## Drag data: {"source": ItemSlot, "inventory": Inventory, "index": int, "equip": String}
## Signals: clicked(slot, button, double), dropped_on(slot, data)

signal clicked(slot: ItemSlot, button: int, double: bool)
signal dropped_on(slot: ItemSlot, data: Dictionary)
signal hovered(slot: ItemSlot)

const SIZE := 56

var inventory: Inventory
## Grid index, or -1 for an equipment slot.
var index: int = -1
## Equipment slot name ("" for grid cells).
var equip_slot: String = ""
var stack: Dictionary = {}
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
## Placeholder drawn in an empty equipment slot.
var placeholder: Texture2D
var quick_key: int = 0
var locked: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_entered.connect(func():
		queue_redraw()
		hovered.emit(self))
	mouse_exited.connect(queue_redraw)


func set_stack(s: Dictionary) -> void:
	stack = s
	var item := Data.get_item(str(s.id)) if not s.is_empty() else null
	tooltip_text = item.name if item else ""
	queue_redraw()


func get_item() -> ItemData:
	return Data.get_item(str(stack.id)) if not stack.is_empty() else null


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var item := get_item()
	var bg := Color(0.05, 0.06, 0.08, 0.95)
	if locked:
		bg = Color(0.03, 0.03, 0.04, 0.9)
	elif item and item.rarity == "rare":
		bg = Color(0.09, 0.08, 0.05, 0.95)
	elif item and item.rarity == "unique":
		bg = Color(0.1, 0.06, 0.08, 0.95)
	draw_rect(r, bg)
	var hover := get_global_rect().has_point(get_global_mouse_position())
	var border := Color(0.25, 0.28, 0.33)
	if selected:
		border = UIKit.ACCENT
	elif hover:
		border = Color(0.6, 0.66, 0.74)
	draw_rect(r.grow(-0.5), border, false, 2.0 if selected else 1.0)
	if item == null:
		if placeholder:
			var ps := Vector2(32, 32)
			draw_texture_rect(placeholder, Rect2((size - ps) * 0.5, ps), false, Color(1, 1, 1, 0.16))
		if locked:
			draw_line(Vector2(8, 8), size - Vector2(8, 8), Color(0.2, 0.22, 0.26), 1.0)
		_draw_quick_key()
		return
	var tex := IconArt.item_icon(item)
	if tex:
		# Whole multiples of 16 keep the pixels square.
		var k := maxf(1.0, floorf((minf(size.x, size.y) - 6.0) / 16.0))
		var isz := Vector2(16, 16) * k
		draw_texture_rect(tex, Rect2(((size - isz) * 0.5 - Vector2(0, 1)).floor(), isz), false)
	var font := UIKit.small_font()
	var count := int(stack.get("count", 1))
	if count > 1:
		var txt := str(count)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(font, Vector2(size.x - w - 4, size.y - 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(size.x - w - 4, size.y - 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT)
	if stack.has("cond"):
		var c := clampf(float(stack.cond) / 100.0, 0.0, 1.0)
		var col := UIKit.GOOD if c > 0.6 else (UIKit.ACCENT if c > 0.25 else UIKit.DANGER)
		draw_rect(Rect2(4, size.y - 5, size.x - 8, 2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(4, size.y - 5, (size.x - 8) * c, 2), col)
	var q := int(stack.get("q", 1))
	if stack.has("q") and q != 1:
		var qc: Color = [UIKit.DANGER, UIKit.TEXT, UIKit.GOOD, UIKit.ACCENT][clampi(q, 0, 3)]
		draw_rect(Rect2(size.x - 8, 4, 4, 4), qc)
	var fill := _filter_fill(item)
	if fill >= 0.0:
		var col := UIKit.COLD if fill > 0.25 else UIKit.DANGER
		draw_rect(Rect2(size.x - 6, 10, 3, size.y - 18), Color(0, 0, 0, 0.7))
		var h := (size.y - 18) * fill
		draw_rect(Rect2(size.x - 6, 10 + (size.y - 18) - h, 3, h), col)
	_draw_quick_key()


func _draw_quick_key() -> void:
	if quick_key <= 0:
		return
	var font := UIKit.small_font()
	draw_rect(Rect2(2, 2, 12, 13), Color(0, 0, 0, 0.75))
	draw_string(font, Vector2(4, 13), str(quick_key), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIKit.ACCENT)


## Remaining filter charge 0..1 for masks with a filter and loose partially used filters.
func _filter_fill(item: ItemData) -> float:
	var d: Dictionary = stack.get("data", {})
	if item.equip_slot == "mask":
		if d.has("filter") and not str(d.filter).is_empty():
			var f := Data.get_item(str(d.filter))
			return clampf(float(d.get("filter_left", 0.0)) / maxf(1.0, f.filter_capacity if f else 1.0), 0.0, 1.0)
		return 0.0
	if item.is_filter() and d.has("left"):
		return clampf(float(d.left) / maxf(1.0, item.filter_capacity), 0.0, 1.0)
	return -1.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			clicked.emit(self, event.button_index, event.double_click)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if stack.is_empty() or locked:
		return null
	var preview := TextureRect.new()
	preview.texture = IconArt.item_icon(get_item())
	preview.custom_minimum_size = Vector2(40, 40)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1, 1, 1, 0.85)
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = Vector2(-20, -20)
	set_drag_preview(holder)
	return {"source": self, "inventory": inventory, "index": index, "equip": equip_slot}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("source") and data.source != self and not locked


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped_on.emit(self, data)


func _make_custom_tooltip(_for_text: String) -> Object:
	var item := get_item()
	if item == null:
		return null
	return ItemTooltip.build(item, stack)
