extends Node
## Developer tool: renders every item icon (and every unused template) into one PNG sheet.
## Env: SHEET_OUT (default user://icons.png), SHEET_SCALE (default 4)
## Usage: godot --headless --path . res://tools/IconSheet.tscn

func _ready() -> void:
	var scale := int(OS.get_environment("SHEET_SCALE")) if not OS.get_environment("SHEET_SCALE").is_empty() else 4
	var out := OS.get_environment("SHEET_OUT")
	if out.is_empty():
		out = "user://icons.png"
	var ids: Array = Data.items.keys()
	ids.sort()
	var textures: Array = []
	var used := {}
	for id in ids:
		var item: ItemData = Data.items[id]
		used[item.icon_shape.split("+")[0]] = true
		textures.append(IconArt.item_icon(item))
		print("%3d %-22s %s" % [textures.size() - 1, id, item.icon_shape])
	for t in IconArt.template_names():
		if not used.has(t):
			print("unused template: ", t)
			textures.append(IconArt.template_icon(t))
	var cols := 12
	var cell := 16 * scale + 8
	var rows := int(ceil(textures.size() / float(cols)))
	var sheet := Image.create_empty(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.17, 0.2))
	for i in textures.size():
		var tex: Texture2D = textures[i]
		if tex == null:
			continue
		var img := tex.get_image()
		img.resize(16 * scale, 16 * scale, Image.INTERPOLATE_NEAREST)
		var cx := (i % cols) * cell + 4
		var cy := (i / cols) * cell + 4
		sheet.fill_rect(Rect2i(cx, cy, 16 * scale, 16 * scale), Color(0.22, 0.23, 0.27) if (i / cols + i % cols) % 2 == 0 else Color(0.25, 0.26, 0.3))
		sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(cx, cy))
	sheet.save_png(out)
	print("saved ", out, " (", textures.size(), " icons)")
	get_tree().quit()
