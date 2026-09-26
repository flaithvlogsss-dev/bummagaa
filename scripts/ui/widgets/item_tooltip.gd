class_name ItemTooltip
extends RefCounted
## ItemTooltip — builds the hover card and the detail text for an item stack.


static func build(item: ItemData, stack: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.035, 0.05, 0.97), UIKit.BORDER, 1, 8))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label(title(item, stack), 15, rarity_color(item)))
	v.add_child(UIKit.label(meta_line(item, stack), 12, UIKit.TEXT_DIM))
	var effect := item.effect_text
	if not effect.is_empty():
		v.add_child(UIKit.label(effect, 13, UIKit.GOOD))
	for line in state_lines(item, stack):
		v.add_child(UIKit.label(line, 12, UIKit.COLD))
	return p


static func title(item: ItemData, stack: Dictionary) -> String:
	var t := item.name
	if stack.has("q") and int(stack.q) != 1:
		t += " (%s)" % ItemData.QUALITY_NAMES[clampi(int(stack.q), 0, 3)].to_lower()
	return t


static func rarity_color(item: ItemData) -> Color:
	match item.rarity:
		"uncommon":
			return Color(0.7, 0.9, 0.75)
		"rare":
			return UIKit.ACCENT
		"unique":
			return Color(0.95, 0.6, 0.85)
	return UIKit.TEXT


static func meta_line(item: ItemData, stack: Dictionary) -> String:
	var n := int(stack.get("count", 1))
	var parts: PackedStringArray = [item.category_name()]
	if item.rarity != "common":
		parts.append(ItemData.RARITY_NAMES.get(item.rarity, item.rarity))
	parts.append("%.2f кг" % item.weight if item.weight < 0.1 else "%.1f кг" % item.weight)
	if n > 1:
		parts.append("×%d = %.1f кг" % [n, item.weight * n])
	return " • ".join(parts)


## Condition, filter charge, magazine, expiry, equipment slot.
static func state_lines(item: ItemData, stack: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var d: Dictionary = stack.get("data", {})
	if stack.has("cond"):
		out.append("Состояние: %d%%%s" % [int(stack.cond), "  — сломано" if float(stack.cond) <= 0.0 else ""])
	if item.equip_slot == "mask":
		if d.has("filter") and not str(d.filter).is_empty():
			var f := Data.get_item(str(d.filter))
			out.append("Фильтр: %s — %d мин" % [f.name if f else "?", int(ceil(float(d.get("filter_left", 0.0))))])
		else:
			out.append("Фильтр: нет — маска почти не защищает")
	if item.is_filter():
		var left := float(d.get("left", item.filter_capacity))
		out.append("Ресурс: %d из %d мин" % [int(ceil(left)), int(item.filter_capacity)])
	if item is WeaponData and (item as WeaponData).is_firearm():
		out.append("Заряжено: %d / %d" % [int(d.get("mag", 0)), (item as WeaponData).magazine_size])
	if d.has("exp"):
		var left_h := (float(d.exp) - TimeManager.total_minutes) / 60.0
		out.append("Испортится через %s" % ("%d ч" % int(ceil(left_h)) if left_h >= 1.0 else "меньше часа"))
	if item.is_equippable():
		out.append("Слот: %s" % Inventory.SLOT_NAMES.get(item.equip_slot, item.equip_slot))
	return out
