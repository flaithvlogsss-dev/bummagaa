class_name ItemData
extends Resource
## Definition of one item type.
##
## Items live in JSON tables (res://data/items/*.json, one row per item) and are turned into
## ItemData by Data at startup; a hand-made .tres in the same folder works too.
## Runtime inventories store stacks {id, count, cond, q, data}; everything static is read here.

const QUALITY_NAMES: Array[String] = ["Плохое", "Обычное", "Хорошее", "Отличное"]
const QUALITY_MULT: Array[float] = [0.75, 1.0, 1.15, 1.3]
const CATEGORY_NAMES := {
	"Food": "Еда", "Water": "Вода", "Medical": "Медицина", "Material": "Материал", "Tool": "Инструмент",
	"Survival": "Выживание", "Clothing": "Одежда", "Mask": "Защита дыхания", "Weapon": "Оружие",
	"Ammunition": "Боеприпасы", "Electronics": "Электроника", "Quest": "Особое", "Book": "Знания",
}
const RARITY_NAMES := {"common": "обычный", "uncommon": "необычный", "rare": "редкий", "unique": "уникальный"}

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
## Short line of what the item does ("+30 сытость"), shown in tooltips.
@export var effect_text: String = ""
## Optional art; when empty the icon is drawn from icon_shape + icon_colors (data/art/icons.txt).
@export var icon: Texture2D
@export var icon_shape: String = "box"
@export var icon_colors: PackedColorArray = PackedColorArray()
@export var weight: float = 0.5
@export var stack_size: int = 10
@export var category: String = "Material"
@export_enum("common", "uncommon", "rare", "unique") var rarity: String = "common"
@export var value: int = 1
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Use")
@export var use_text: String = "Использовать"
## Consequence dictionaries applied when the item is used (see Consequences).
@export var use_effects: Array = []
## Books and similar: using does not consume the item.
@export var keep_on_use: bool = false
## Quest items cannot be dropped or destroyed.
@export var quest: bool = false

@export_group("Equipment")
## "", "head", "mask", "body", "backpack", "weapon", "secondary", "utility"
@export var equip_slot: String = ""
@export var insulation: float = 0.0
## Tracks wear (0..100). Such items never stack.
@export var has_condition: bool = false

@export_group("Special")
@export var throwable: bool = false
## Masks: share of contamination blocked with a working filter (0..1).
@export var mask_efficiency: float = 0.0
## Masks: how much the visor narrows the view (0..1).
@export var mask_visibility: float = 0.0
## Filters: game minutes of clean air and how well they clean it (0..1).
@export var filter_capacity: float = 0.0
@export var filter_efficiency: float = 0.0
## Backpacks: carry weight (kg) and grid slots.
@export var backpack_capacity: float = 0.0
@export var backpack_slots: int = 0
## Generator fuel units / stove burn minutes.
@export var fuel_value: float = 0.0
## Days until food spoils into spoiled_food (0 = never).
@export var spoil_days: float = 0.0
## Damage reduction 0..1 (helmets).
@export var protection: float = 0.0


func is_equippable() -> bool:
	return not equip_slot.is_empty()


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func is_stackable() -> bool:
	return stack_size > 1 and not has_condition


func is_usable() -> bool:
	return not use_effects.is_empty()


func is_worn() -> bool:
	return equip_slot in ["head", "mask", "body", "backpack"]


func is_filter() -> bool:
	return filter_capacity > 0.0


func category_name() -> String:
	return CATEGORY_NAMES.get(category, category)


static func from_dict(d: Dictionary) -> ItemData:
	var item: ItemData = WeaponData.new() if d.get("category", "") == "Weapon" else ItemData.new()
	for key in d.keys():
		match key:
			"icon_colors":
				var colors := PackedColorArray()
				for c in d[key]:
					colors.append(Color(str(c)))
				item.icon_colors = colors
			"tags":
				item.tags = PackedStringArray(d[key])
			_:
				if key in item:
					item.set(key, d[key])
				else:
					push_warning("ItemData %s: unknown field '%s'" % [d.get("id", "?"), key])
	if item.has_condition:
		item.stack_size = 1
	return item
