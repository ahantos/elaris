extends SceneTree
# tools/art_checklist.gd - writes docs/ART_CHECKLIST.md, the list of every piece of
# art the game loads, from data/art/art_manifest.gd and the item database.
#
# Run it after changing the manifest, the item list, or any file under assets/:
#   <godot> --headless --path <project> --script res://tools/art_checklist.gd
#
# Add "-- --copy-missing" to first copy the stand-in for every manifest row whose
# file does not exist yet (it never overwrites a file). Run the import afterwards:
#   <godot> --headless --path <project> --script res://tools/art_checklist.gd -- --copy-missing
#   <godot> --headless --path <project> --import
#
# Like every --script file it must reach autoloads with root.get_node("Name").

const OUTPUT := "res://docs/ART_CHECKLIST.md"

const GROUP_TITLES := {
	"tiles": "Map tiles",
	"enemies": "Enemies",
	"player": "Player",
	"companions": "Companions",
	"loot": "Loot on the floor",
	"items": "Item icons",
}

const GROUP_NOTES := {
	"tiles": "Opaque for floors. Walls, doors and decorations are drawn over a floor tile, so they may be transparent around the edges. The percentage is how many cells of that role show the variant.",
	"enemies": "Drawn at one tile. Transparent background.",
	"player": "One sprite per class; the sprite follows the character's class.",
	"companions": "A companion without a sprite of its own is drawn with the player sprite of its class.",
	"loot": "",
	"items": "Shown in the character sheet at twice their size. Material variants share the icon of their base type.",
}

func _initialize():
	_run()

func _run():
	# two frames: autoloads have run _ready and SpellDatabase has registered its items
	await process_frame
	await process_frame

	var art = load("res://scripts/art_library.gd")
	var manifest = load("res://data/art/art_manifest.gd")
	var items = root.get_node_or_null("ItemDatabase")
	if art == null or manifest == null or items == null:
		print("[ART] could not load ArtLibrary, the manifest or ItemDatabase")
		quit(1)
		return

	var entries: Array = art.all_entries()
	if "--copy-missing" in OS.get_cmdline_user_args():
		_copy_missing(entries, manifest)

	# Which item ids use which icon
	var users: Dictionary = {}     # icon name -> Array of item ids
	var unmapped: Array = []
	var item_ids: Array = items.items.keys()
	item_ids.sort()
	for item_id in item_ids:
		var icon_name: String = art.item_icon_name(item_id)
		if icon_name == "":
			unmapped.append(item_id)
		else:
			if not users.has(icon_name):
				users[icon_name] = []
			users[icon_name].append(item_id)

	var counts: Dictionary = {}    # group -> [files, stand-ins, own art, missing]
	var rows: Dictionary = {}      # group -> Array of table lines
	var group_order: Array = []
	for entry in entries:
		var group: String = entry["group"]
		if not rows.has(group):
			rows[group] = []
			counts[group] = [0, 0, 0, 0]
			group_order.append(group)
		var file_path: String = ProjectSettings.globalize_path(entry["path"])
		var stand_in: String = entry["stand_in"]
		var size_text := "-"
		var status := "MISSING"
		counts[group][0] += 1
		if FileAccess.file_exists(file_path):
			var image := Image.load_from_file(file_path)
			if image != null:
				size_text = "%dx%d" % [image.get_width(), image.get_height()]
			if stand_in != "" and _same_bytes(file_path, ProjectSettings.globalize_path(manifest.STAND_IN_ROOT + stand_in)):
				status = "stand-in"
				counts[group][1] += 1
			else:
				status = "own art"
				counts[group][2] += 1
		else:
			counts[group][3] += 1
		var used: String = entry["used_by"]
		if group == "items":
			var ids: Array = users.get(entry["id"], [])
			if ids.is_empty():
				used = "no item uses this icon yet"
			elif ids.size() == 1:
				used = "`%s`" % ids[0]
			else:
				used = "%d items: `%s`" % [ids.size(), "`, `".join(ids)]
		rows[group].append("| `%s` | %s | %s | %s | %s |" % [
			entry["path"].trim_prefix("res://"), size_text, used,
			("`%s`" % stand_in) if stand_in != "" else "-", status])

	var total := [0, 0, 0, 0]
	for group in group_order:
		for i in range(4):
			total[i] += counts[group][i]

	var out: Array = []
	out.append("# Art checklist")
	out.append("")
	out.append("Every piece of art the game loads right now: where the file is, how big it is, what")
	out.append("it is used for, and which Dungeon Crawl Stone Soup tile (CC0, see")
	out.append("`art_source/CREDITS.md`) is standing in for it. Draw against this list.")
	out.append("")
	out.append("**Generated file, do not edit by hand.** It is written by `tools/art_checklist.gd` from")
	out.append("`data/art/art_manifest.gd` and the item database. Regenerate it after changing the")
	out.append("manifest, adding items, or replacing files (run from the project folder):")
	out.append("")
	out.append("```")
	out.append("\"%GODOT_EXE%\" --headless --path . --script res://tools/art_checklist.gd")
	out.append("```")
	out.append("")
	out.append("## Replacing a piece of art")
	out.append("")
	out.append("1. Save your PNG over the file in the first column, same name, same folder.")
	out.append("2. Open the project in Godot once, or run `tools\\run_checks.bat`, so the file is imported.")
	out.append("")
	out.append("That is all; no code changes. Map tiles must be exactly %dx%d. Sprites and icons are" % [manifest.TILE_SIZE, manifest.TILE_SIZE])
	out.append("%dx%d too, but a larger square image is scaled down to fit. Use a transparent" % [manifest.TILE_SIZE, manifest.TILE_SIZE])
	out.append("background wherever the floor should show through. Textures are drawn unfiltered")
	out.append("(nearest neighbour), so pixels stay sharp.")
	out.append("")
	out.append("To add art for something new (an enemy type, an item, a tile variant, a biome), add a")
	out.append("row to the matching table in `data/art/art_manifest.gd`; the comments there say where")
	out.append("the file goes. Anything without art is drawn as a magenta and black checker, and the")
	out.append("smoke test names it.")
	out.append("")
	out.append("The **Status** column compares each file with its stand-in: `stand-in` means it is still")
	out.append("the placeholder, `own art` means the file has been replaced (or never had a placeholder),")
	out.append("`MISSING` means the manifest lists a file that is not there.")
	out.append("")
	out.append("## Summary")
	out.append("")
	out.append("| Group | Files | Still stand-ins | Own art | Missing |")
	out.append("|---|---|---|---|---|")
	for group in group_order:
		out.append("| %s | %d | %d | %d | %d |" % [GROUP_TITLES.get(group, group),
			counts[group][0], counts[group][1], counts[group][2], counts[group][3]])
	out.append("| **Total** | **%d** | **%d** | **%d** | **%d** |" % total)
	out.append("")
	out.append("Items in the database: %d, of which %d have an icon." % [item_ids.size(), item_ids.size() - unmapped.size()])
	if not unmapped.is_empty():
		out.append("")
		out.append("**Items without an icon:** `%s`" % "`, `".join(unmapped))
	out.append("")
	for group in group_order:
		out.append("## %s" % GROUP_TITLES.get(group, group))
		out.append("")
		var note: String = GROUP_NOTES.get(group, "")
		if note != "":
			out.append(note)
			out.append("")
		out.append("| File | Size | Used for | Stand-in (under `art_source/dcss-tiles/`) | Status |")
		out.append("|---|---|---|---|---|")
		out.append_array(rows[group])
		out.append("")
	out.append("## Not on this list")
	out.append("")
	out.append("Nothing in the game asks for these yet, so there is no file to draw: spell icons,")
	out.append("status-effect icons, attack and spell effects, portraits, UI frames and buttons, a")
	out.append("sprite per item lying on the floor, and equipment shown on the character. HP bars,")
	out.append("the path preview, the grid and the minimap are drawn by code.")
	out.append("")

	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT), FileAccess.WRITE)
	if file == null:
		print("[ART] cannot write ", OUTPUT)
		quit(1)
		return
	file.store_string("\n".join(out))
	file.close()

	print("[ART] %s written: %d files (%d stand-ins, %d own art, %d missing), %d of %d items have an icon" % [
		OUTPUT, total[0], total[1], total[2], total[3], item_ids.size() - unmapped.size(), item_ids.size()])
	for item_id in unmapped:
		print("[ART]   no icon: ", item_id)
	quit(1 if total[3] > 0 or not unmapped.is_empty() else 0)

func _copy_missing(entries: Array, manifest) -> void:
	"""Copy the stand-in for every manifest row whose file does not exist"""
	var copied := 0
	for entry in entries:
		var target: String = ProjectSettings.globalize_path(entry["path"])
		if FileAccess.file_exists(target) or entry["stand_in"] == "":
			continue
		var source: String = ProjectSettings.globalize_path(manifest.STAND_IN_ROOT + entry["stand_in"])
		if not FileAccess.file_exists(source):
			print("[ART]   stand-in not found: ", entry["stand_in"], " (for ", entry["path"], ")")
			continue
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var error := DirAccess.copy_absolute(source, target)
		if error == OK:
			copied += 1
		else:
			print("[ART]   copy failed (", error, "): ", entry["path"])
	print("[ART] copied %d stand-in file(s); run the import before starting the game" % copied)

func _same_bytes(path_a: String, path_b: String) -> bool:
	if not FileAccess.file_exists(path_a) or not FileAccess.file_exists(path_b):
		return false
	return FileAccess.get_file_as_bytes(path_a) == FileAccess.get_file_as_bytes(path_b)
