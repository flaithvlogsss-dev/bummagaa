class_name MaskWidget
extends PanelContainer
## MaskWidget — HUD block for breathing: mask condition, filter charge and exposure.
##
## MASK and FILTER bars with percentages, the minutes of clean air left, and the exposure
## meter with its state. Blinks when the filter runs low and pulses red when exposure is
## critical. Reads everything from GameState and the player's ExposureSystem.

var _icon: TextureRect
var _mask_name: Label
var _mask_bar: ProgressBar
var _mask_pct: Label
var _filter_bar: ProgressBar
var _filter_pct: Label
var _filter_time: Label
var _exp_bar: ProgressBar
var _exp_state: Label
var _t: float = 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.box(UIKit.BG_SOFT, Color(0.4, 0.46, 0.55, 0.6), 1, 8))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(8)
	add_child(h)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(_icon)
	var v := UIKit.vbox(2)
	h.add_child(v)
	_mask_name = UIKit.label("", 11, UIKit.TEXT_DIM)
	v.add_child(_mask_name)
	var r1 := _row(v, "МАСКА", Color(0.7, 0.78, 0.85))
	_mask_bar = r1[0]
	_mask_pct = r1[1]
	var r2 := _row(v, "ФИЛЬТР", UIKit.COLD)
	_filter_bar = r2[0]
	_filter_pct = r2[1]
	_filter_time = UIKit.label("", 10, UIKit.TEXT_DIM)
	v.add_child(_filter_time)
	var r3 := _row(v, "ЗАРАЖЕНИЕ", Color(0.6, 0.85, 0.4))
	_exp_bar = r3[0]
	_exp_state = r3[1]
	_exp_state.custom_minimum_size.x = 84


func _row(parent: Control, title: String, color: Color) -> Array:
	var h := UIKit.hbox(6)
	parent.add_child(h)
	var l := UIKit.label(title, 10, UIKit.TEXT_DIM)
	l.custom_minimum_size.x = 64
	h.add_child(l)
	var b := UIKit.bar(color, 7)
	b.custom_minimum_size.x = 96
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	var p := UIKit.label("", 11)
	p.custom_minimum_size.x = 36
	h.add_child(p)
	return [b, p]


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var player := Main.get_player()
	var ex: ExposureSystem = player.exposure if player else null
	var inv := GameState.inventory
	var s := GameState.stats
	var mask := inv.get_equipped_stack("mask")
	var item := Data.get_item(str(mask.id)) if not mask.is_empty() else null
	var blink := 0.5 + 0.5 * sin(_t * 9.0)
	if item == null:
		_icon.texture = IconArt.template_icon("gasmask", PackedColorArray([Color(0.3, 0.32, 0.35), Color(0.3, 0.32, 0.35)]))
		_mask_name.text = "НЕТ МАСКИ  [G]"
		_mask_bar.value = 0.0
		_mask_pct.text = "—"
		_filter_bar.value = 0.0
		_filter_pct.text = "—"
		_filter_time.text = ""
	else:
		_icon.texture = IconArt.item_icon(item)
		_icon.modulate = Color(1, 1, 1, 1.0 if s.mask_on else 0.45)
		_mask_name.text = "%s — %s  [G]" % [item.name, "НАДЕТА" if s.mask_on else "СНЯТА"]
		var cond := float(mask.get("cond", 100.0))
		_mask_bar.value = cond
		_mask_pct.text = "%d%%" % int(cond)
		_mask_bar.modulate = Color(1, 0.45, 0.4) if cond < 25.0 else Color.WHITE
		var frac := ex.filter_fraction() if ex else 0.0
		var left := inv.get_mask_filter_left()
		_filter_bar.value = frac * 100.0
		_filter_pct.text = "%d%%" % int(round(frac * 100.0)) if left > 0.0 else "НЕТ"
		if left > 0.0:
			var drain := maxf(WeatherManager.filter_drain, 0.1)
			var real_min := left / drain / maxf(TimeManager.time_speed, 0.01) / 60.0
			_filter_time.text = "≈ %s на улице" % ("%d мин" % int(ceil(real_min)) if real_min >= 1.0 else "меньше минуты")
		else:
			_filter_time.text = "вставь фильтр в рюкзаке [I]"
		var low := left <= 0.0 or frac < ExposureSystem.FILTER_LOW
		_filter_bar.modulate = Color(1, blink * 0.6 + 0.3, blink * 0.6 + 0.3) if low else Color.WHITE
		_filter_pct.modulate = _filter_bar.modulate
	var v := s.exposure
	var st := ExposureSystem.state_for_value(v)
	_exp_bar.value = v
	_exp_state.text = ExposureSystem.STATE_NAMES[st]
	_exp_state.add_theme_color_override("font_color", ExposureSystem.STATE_COLORS[st])
	_exp_bar.add_theme_stylebox_override("fill", UIKit.box(ExposureSystem.STATE_COLORS[st], Color(0, 0, 0, 0), 0, 0))
	if st >= ExposureSystem.State.CRITICAL:
		modulate = Color(1, 0.55 + blink * 0.45, 0.55 + blink * 0.45)
	else:
		modulate = Color.WHITE
