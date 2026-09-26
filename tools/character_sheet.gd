extends Node
## Developer tool: renders every character's sheet (plain and masked variants, plus a fully
## equipped player) into one PNG for review.
## Env: SHEET_OUT (default user://characters.png), SHEET_SCALE (default 3),
##      SHEET_ONLY (comma-separated character ids)
## Usage: godot --headless --path . res://tools/CharacterSheet.tscn

func _ready() -> void:
	var scale := int(OS.get_environment("SHEET_SCALE")) if not OS.get_environment("SHEET_SCALE").is_empty() else 3
	var out := OS.get_environment("SHEET_OUT")
	if out.is_empty():
		out = "user://characters.png"
	var sheets: Array = []
	var ids: Array = Data.characters.keys()
	ids.sort()
	var only := OS.get_environment("SHEET_ONLY")
	if not only.is_empty():
		ids = Array(only.split(","))
	for id in ids:
		var data: CharacterData = Data.characters[id]
		sheets.append(CharacterArt.sheet(CharacterArt.appearance_for(data, false)))
		sheets.append(CharacterArt.sheet(CharacterArt.appearance_for(data, true)))
	var geared := CharacterArt.appearance_for(Data.get_character("player"), false)
	geared.merge({"hat": "ushanka", "mask": "pano", "backpack": "big", "coat_style": "parka", "coat": Color(0.36, 0.4, 0.26), "hat_color": Color(0.4, 0.34, 0.28)}, true)
	sheets.append(CharacterArt.sheet(geared))
	for kind in ["stalker", "watcher", "brute"]:
		sheets.append(EnemyArt.sheet(kind))
	var w: int = CharacterArt.FRAME * CharacterArt.COLS
	var h: int = CharacterArt.FRAME * CharacterArt.ROWS
	var cols := 2
	var rows := int(ceil(sheets.size() / float(cols)))
	var pad := 6
	var img := Image.create_empty((w * scale + pad) * cols, (h * scale + pad) * rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.58, 0.64))
	for i in sheets.size():
		var sheet_img: Image = (sheets[i] as Texture2D).get_image()
		var sw := sheet_img.get_width() * scale
		var sh := mini(sheet_img.get_height() * scale, h * scale)
		sheet_img.resize(sheet_img.get_width() * scale, sheet_img.get_height() * scale, Image.INTERPOLATE_NEAREST)
		img.blend_rect(sheet_img, Rect2i(0, 0, mini(sw, w * scale), sh), Vector2i((i % cols) * (w * scale + pad), (i / cols) * (h * scale + pad)))
	img.save_png(out)
	print("saved ", out, " (", sheets.size(), " sheets)")
	get_tree().quit()
