class_name UIKit
extends RefCounted
## UIKit — pixel-style theme and small widget helpers shared by every UI panel.

const BG := Color(0.045, 0.055, 0.075, 0.9)
const BG_SOFT := Color(0.06, 0.07, 0.095, 0.72)
const BORDER := Color(0.52, 0.6, 0.7, 0.85)
const TEXT := Color(0.88, 0.9, 0.93)
const TEXT_DIM := Color(0.6, 0.64, 0.7)
const ACCENT := Color(1.0, 0.7, 0.35)
const COLD := Color(0.55, 0.78, 1.0)
const DANGER := Color(0.95, 0.35, 0.3)
const GOOD := Color(0.55, 0.9, 0.6)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", box(BG, BORDER, 2, 10))
	t.set_stylebox("panel", "Panel", box(BG, BORDER, 2, 10))
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.12, 0.16, 0.95), Color(0.35, 0.4, 0.48), 1, 6))
	t.set_stylebox("hover", "Button", box(Color(0.16, 0.19, 0.25, 0.98), ACCENT, 1, 6))
	t.set_stylebox("pressed", "Button", box(Color(0.22, 0.18, 0.12, 1.0), ACCENT, 2, 6))
	t.set_stylebox("disabled", "Button", box(Color(0.07, 0.08, 0.1, 0.9), Color(0.2, 0.22, 0.26), 1, 6))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 1, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.42, 0.46))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0.02, 0.025, 0.035, 0.9), Color(0.25, 0.28, 0.33), 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("normal", "LineEdit", box(Color(0.03, 0.035, 0.05, 1), Color(0.35, 0.4, 0.48), 1, 5))
	t.set_stylebox("panel", "ItemList", box(Color(0.03, 0.035, 0.05, 0.9), Color(0.25, 0.28, 0.33), 1, 4))
	t.set_stylebox("selected", "ItemList", box(Color(0.22, 0.18, 0.12, 1.0), ACCENT, 1, 2))
	t.set_stylebox("selected_focus", "ItemList", box(Color(0.22, 0.18, 0.12, 1.0), ACCENT, 1, 2))
	t.set_stylebox("slider", "HSlider", box(Color(0.1, 0.12, 0.16), Color(0.35, 0.4, 0.48), 1, 2))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(0.16, 0.19, 0.25, 1), ACCENT, 1, 6))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.07, 0.08, 0.1, 1), Color(0.3, 0.33, 0.4), 1, 6))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.12, 0.14, 0.18, 1), ACCENT, 1, 6))
	t.set_stylebox("panel", "TabContainer", box(Color(0.03, 0.035, 0.05, 0.6), Color(0.25, 0.28, 0.33), 1, 8))
	t.set_stylebox("panel", "PopupMenu", box(BG, BORDER, 2, 6))
	t.set_stylebox("normal", "OptionButton", box(Color(0.1, 0.12, 0.16, 0.95), Color(0.35, 0.4, 0.48), 1, 6))
	_theme = t
	return t


static func box(bg: Color, border: Color, border_w: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margin)
	s.anti_aliasing = false
	return s


static func label(text: String = "", size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


static func rich(text: String = "", size: int = 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func button(text: String, callback: Callable = Callable(), min_width: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if min_width > 0:
		b.custom_minimum_size.x = min_width
	if callback.is_valid():
		b.pressed.connect(callback)
	b.pressed.connect(func(): AudioManager.play_ui("click"))
	return b


static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func bar(color: Color, height: int = 10) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.max_value = 100.0
	p.custom_minimum_size = Vector2(0, height)
	p.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 0, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


## Centred panel filling a full-screen parent.
static func centered(parent: Control, min_size: Vector2) -> PanelContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	var p := panel(min_size)
	c.add_child(p)
	return p


static func title(text: String) -> Label:
	var l := label(text, 20, ACCENT)
	return l


static func spacer(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", box(Color(0.3, 0.34, 0.4, 0.6), Color(0, 0, 0, 0), 0, 0))
	return s


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
