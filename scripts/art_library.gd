# art_library.gd
# The one place the game asks for art. Maps game ids (biome + tile role, enemy type,
# class, companion id, item id) to textures, using the tables in
# data/art/art_manifest.gd. To change which file an id uses, edit that file, not this one.
#
# Rules:
#   - Every function returns a texture. Missing art gives fallback_texture() (a
#     magenta checker) and is remembered in get_missing(), which the smoke test reads.
#   - Tile variants are chosen from the cell coordinates alone (cell_hash). Nothing
#     here touches the global random number generator, so drawing a dungeon never
#     changes what a seeded generator produces next.
#   - Static functions only, and no autoload names, so tool scripts can load it too.
class_name ArtLibrary
extends RefCounted

const Manifest = preload("res://data/art/art_manifest.gd")

const TILE_SIZE: int = Manifest.TILE_SIZE

static var _textures: Dictionary = {}      # res:// path -> Texture2D
static var _fallback: Texture2D = null
static var _missing: Dictionary = {}       # message -> true
static var _tileset: TileSet = null
static var _tile_sets: Dictionary = {}     # "biome/role" -> {ids, textures, weights, total}
static var _fallback_source_id: int = -1

# ============================================================================
#  MAP TILES
# ============================================================================

static func get_tileset() -> TileSet:
	"""The TileSet every dungeon draws with: 32x32 cells, one atlas source per
	tile PNG listed in the manifest. Built once and shared."""
	if _tileset == null:
		_build_tileset()
	return _tileset

static func tile_source_id(biome: String, role: String, cell: Vector2i) -> int:
	"""Atlas source id (in get_tileset()) of the variant this cell uses. The tile
	sits at atlas coordinates (0, 0) of that source."""
	var entry: Dictionary = _tile_set_for(biome, role)
	return entry["ids"][_pick_variant(entry, cell, _role_salt(role))]

static func tile_texture(biome: String, role: String, cell: Vector2i = Vector2i.ZERO) -> Texture2D:
	"""Texture of the variant this cell uses"""
	var entry: Dictionary = _tile_set_for(biome, role)
	return entry["textures"][_pick_variant(entry, cell, _role_salt(role))]

static func tile_textures(biome: String, role: String) -> Array:
	"""Every variant texture of one biome and tile role"""
	return _tile_set_for(biome, role)["textures"].duplicate()

static func tile_role(tile_type: int) -> String:
	"""Role name of a DungeonGenerator.TileType value: 0 floor, 1 wall, 2 door,
	3 decoration. Anything else gives an empty string."""
	if tile_type < 0 or tile_type >= Manifest.TILE_ROLES.size():
		return ""
	return Manifest.TILE_ROLES[tile_type]

static func get_biomes() -> Array:
	"""Biome names that have tiles in the manifest"""
	return Manifest.TILES.keys()

static func cell_hash(cell: Vector2i, salt: int = 0) -> int:
	"""A fixed pseudo-random number (0 .. 2^32-1) for a cell. Same cell and salt,
	same number, on every run and every machine."""
	var h: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	h &= 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return h ^ (h >> 16)

# ============================================================================
#  CREATURES AND LOOT
# ============================================================================

static func enemy_sprite(enemy_type: String) -> Texture2D:
	"""Sprite of an enemy type ('goblin', 'skeleton', ...)"""
	if not Manifest.ENEMY_SPRITES.has(enemy_type):
		return _no_art("enemy type '%s' (ENEMY_SPRITES)" % enemy_type)
	return _load("sprites/enemies/" + Manifest.ENEMY_SPRITES[enemy_type][0])

static func player_sprite(class_id: String = "") -> Texture2D:
	"""Sprite of the player for a class id. An empty id gives the default class."""
	if class_id == "":
		class_id = Manifest.PLAYER_DEFAULT_CLASS
	if not Manifest.PLAYER_SPRITES.has(class_id):
		return _no_art("player class '%s' (PLAYER_SPRITES)" % class_id)
	return _load("sprites/player/" + Manifest.PLAYER_SPRITES[class_id][0])

static func companion_sprite(companion_id: String, class_id: String = "") -> Texture2D:
	"""Sprite of a companion: its own if the manifest lists one, otherwise the
	player sprite of its class."""
	if Manifest.COMPANION_SPRITES.has(companion_id):
		return _load("sprites/companions/" + Manifest.COMPANION_SPRITES[companion_id][0])
	if class_id != "" and Manifest.PLAYER_SPRITES.has(class_id):
		return player_sprite(class_id)
	return _no_art("companion '%s' of class '%s' (COMPANION_SPRITES)" % [companion_id, class_id])

static func loot_marker(has_items: bool = true) -> Texture2D:
	"""Sprite of loot lying on the floor: a bag when the drop holds items, coins
	when it is gold only."""
	var key := "items" if has_items else "gold"
	if not Manifest.LOOT_SPRITES.has(key):
		return _no_art("loot marker '%s' (LOOT_SPRITES)" % key)
	return _load("sprites/loot/" + Manifest.LOOT_SPRITES[key][0])

static func fit_sprite(sprite: Sprite2D, texture: Texture2D, tile_size: int) -> void:
	"""Put a texture on a Sprite2D and scale it so its longer side fills one tile.
	32-pixel art on the 32-pixel grid is drawn 1:1."""
	if sprite == null:
		return
	if texture == null:
		texture = fallback_texture()
	sprite.texture = texture
	var longest: float = max(texture.get_width(), texture.get_height())
	var factor: float = float(tile_size) / longest if longest > 0.0 else 1.0
	sprite.scale = Vector2(factor, factor)

# ============================================================================
#  ITEM ICONS
# ============================================================================

static func item_icon(item_id: String) -> Texture2D:
	"""Inventory icon of an item id"""
	var icon_name := item_icon_name(item_id)
	if icon_name == "":
		return _no_art("item '%s' (ITEM_ICONS)" % item_id)
	return _load("icons/items/" + Manifest.ITEM_ICONS[icon_name][0])

static func item_icon_name(item_id: String) -> String:
	"""Name of the ITEM_ICONS row an item id uses, or "" when nothing matches.
	Order: alias, exact id, base type ('steel_longsword' ends in '_longsword'),
	id prefix ('scroll_')."""
	if item_id == "":
		return ""
	var icons: Dictionary = Manifest.ITEM_ICONS
	if Manifest.ITEM_ICON_ALIASES.has(item_id):
		var alias: String = Manifest.ITEM_ICON_ALIASES[item_id]
		return alias if icons.has(alias) else ""
	if icons.has(item_id):
		return item_id
	# Base type: the longest icon name the id ends with, so 'iron_plate_boots'
	# takes 'plate_boots' and not 'boots'
	var best := ""
	for icon_name in icons.keys():
		if icon_name.length() > best.length() and item_id.ends_with("_" + icon_name):
			best = icon_name
	if best != "":
		return best
	for prefix in Manifest.ITEM_ICON_PREFIXES.keys():
		if item_id.begins_with(prefix):
			var family: String = Manifest.ITEM_ICON_PREFIXES[prefix]
			return family if icons.has(family) else ""
	return ""

# ============================================================================
#  MISSING ART
# ============================================================================

static func fallback_texture() -> Texture2D:
	"""What is drawn when art is missing: a magenta and black checker, made in
	code so it can never be missing itself."""
	if _fallback == null:
		var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		for y in range(TILE_SIZE):
			for x in range(TILE_SIZE):
				var magenta: bool = (int(x / 8.0) + int(y / 8.0)) % 2 == 0
				image.set_pixel(x, y, Color(1, 0, 1) if magenta else Color(0, 0, 0))
		_fallback = ImageTexture.create_from_image(image)
	return _fallback

static func is_fallback(texture: Texture2D) -> bool:
	"""True for a null texture or the missing-art checker"""
	return texture == null or texture == _fallback

static func get_missing() -> Array:
	"""One line for every lookup that had to fall back so far"""
	var lines: Array = _missing.keys()
	lines.sort()
	return lines

static func clear_missing() -> void:
	"""Forget the recorded fallbacks (tests that provoke one on purpose)"""
	_missing.clear()

# ============================================================================
#  THE MANIFEST AS A LIST (checklist and checks)
# ============================================================================

static func all_entries() -> Array:
	"""Every art file the manifest lists, in manifest order. Each entry is
	{group, path (res://), stand_in (relative to art_source/dcss-tiles/, may be ""),
	used_by (what it depicts), id}."""
	var entries: Array = []
	for biome in Manifest.TILES.keys():
		var roles: Dictionary = Manifest.TILES[biome]
		for role in Manifest.TILE_ROLES:
			var rows: Array = roles.get(role, [])
			var total := 0
			for row in rows:
				total += int(row[2])
			for i in range(rows.size()):
				var row: Array = rows[i]
				var used := "%s biome, %s" % [biome, role]
				if rows.size() > 1:
					used += " (variant %d of %d, about %d%% of cells)" % [
						i + 1, rows.size(), roundi(100.0 * float(row[2]) / float(max(total, 1)))]
				entries.append(_entry("tiles", "tiles/%s/%s" % [biome, row[0]], row[1], used, "%s/%s" % [biome, role]))
	for enemy_type in Manifest.ENEMY_SPRITES.keys():
		var row: Array = Manifest.ENEMY_SPRITES[enemy_type]
		entries.append(_entry("enemies", "sprites/enemies/" + row[0], row[1], "enemy type '%s'" % enemy_type, enemy_type))
	for class_id in Manifest.PLAYER_SPRITES.keys():
		var row: Array = Manifest.PLAYER_SPRITES[class_id]
		var used := "the player as a %s" % class_id
		if class_id == Manifest.PLAYER_DEFAULT_CLASS:
			used += " (also before a class is chosen)"
		entries.append(_entry("player", "sprites/player/" + row[0], row[1], used, class_id))
	for companion_id in Manifest.COMPANION_SPRITES.keys():
		var row: Array = Manifest.COMPANION_SPRITES[companion_id]
		entries.append(_entry("companions", "sprites/companions/" + row[0], row[1], "companion '%s'" % companion_id, companion_id))
	for key in Manifest.LOOT_SPRITES.keys():
		var row: Array = Manifest.LOOT_SPRITES[key]
		var used := "loot on the floor that holds items" if key == "items" else "loot on the floor that is gold only"
		entries.append(_entry("loot", "sprites/loot/" + row[0], row[1], used, key))
	for icon_name in Manifest.ITEM_ICONS.keys():
		var row: Array = Manifest.ITEM_ICONS[icon_name]
		entries.append(_entry("items", "icons/items/" + row[0], row[1], "item icon '%s'" % icon_name, icon_name))
	return entries

static func validate_manifest() -> Array:
	"""Problems with the manifest and the files it names: a missing or unloadable
	file, a map tile that is not 32x32, a biome without one of the four roles, a
	weight below 1, the same file listed twice, an alias or prefix that points
	at an icon name that does not exist. Empty when everything is in order."""
	var problems: Array = []
	var seen: Dictionary = {}
	for entry in all_entries():
		var path: String = entry["path"]
		if seen.has(path):
			problems.append("%s is listed more than once" % path)
		seen[path] = true
		if not ResourceLoader.exists(path):
			problems.append("%s is missing (%s)" % [path, entry["used_by"]])
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			problems.append("%s could not be loaded as a texture" % path)
		elif entry["group"] == "tiles" and (texture.get_width() != TILE_SIZE or texture.get_height() != TILE_SIZE):
			problems.append("%s is %dx%d, map tiles must be %dx%d" % [
				path, texture.get_width(), texture.get_height(), TILE_SIZE, TILE_SIZE])
	for biome in Manifest.TILES.keys():
		for role in Manifest.TILE_ROLES:
			var rows: Array = Manifest.TILES[biome].get(role, [])
			if rows.is_empty():
				problems.append("biome '%s' has no '%s' tile" % [biome, role])
			for row in rows:
				if int(row[2]) < 1:
					problems.append("tiles/%s/%s has a weight below 1" % [biome, row[0]])
	if not Manifest.PLAYER_SPRITES.has(Manifest.PLAYER_DEFAULT_CLASS):
		problems.append("PLAYER_DEFAULT_CLASS '%s' has no row in PLAYER_SPRITES" % Manifest.PLAYER_DEFAULT_CLASS)
	for item_id in Manifest.ITEM_ICON_ALIASES.keys():
		if not Manifest.ITEM_ICONS.has(Manifest.ITEM_ICON_ALIASES[item_id]):
			problems.append("alias '%s' points at unknown icon '%s'" % [item_id, Manifest.ITEM_ICON_ALIASES[item_id]])
	for prefix in Manifest.ITEM_ICON_PREFIXES.keys():
		if not Manifest.ITEM_ICONS.has(Manifest.ITEM_ICON_PREFIXES[prefix]):
			problems.append("prefix '%s' points at unknown icon '%s'" % [prefix, Manifest.ITEM_ICON_PREFIXES[prefix]])
	return problems

# ============================================================================
#  INTERNALS
# ============================================================================

static func _entry(group: String, file: String, stand_in: String, used_by: String, id: String) -> Dictionary:
	return {"group": group, "path": Manifest.ASSET_ROOT + file, "stand_in": stand_in, "used_by": used_by, "id": id}

static func _report(message: String) -> void:
	"""Remember a fallback and warn about it once"""
	if _missing.has(message):
		return
	_missing[message] = true
	push_warning("ArtLibrary: " + message)

static func _no_art(what: String) -> Texture2D:
	_report("no art listed for %s in data/art/art_manifest.gd" % what)
	return fallback_texture()

static func _load(file: String) -> Texture2D:
	"""Load assets/<file>, cached. A missing or broken file gives the fallback."""
	var path: String = Manifest.ASSET_ROOT + file
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		_report("art file missing or not an image: %s" % path)
		texture = fallback_texture()
	_textures[path] = texture
	return texture

static func _role_salt(role: String) -> int:
	"""Different roles draw different numbers for the same cell"""
	return Manifest.TILE_ROLES.find(role) + 1

static func _pick_variant(entry: Dictionary, cell: Vector2i, salt: int) -> int:
	"""Index of the variant a cell uses, by weight"""
	var weights: Array = entry["weights"]
	if weights.size() <= 1:
		return 0
	var roll: int = cell_hash(cell, salt) % int(entry["total"])
	for i in range(weights.size()):
		roll -= int(weights[i])
		if roll < 0:
			return i
	return 0

static func _tile_set_for(biome: String, role: String) -> Dictionary:
	"""Variants of one biome and role; an unknown pair gives the fallback tile"""
	get_tileset()
	var key := biome + "/" + role
	if not _tile_sets.has(key):
		_report("no '%s' tile listed for biome '%s' in data/art/art_manifest.gd" % [role, biome])
		_tile_sets[key] = {"ids": [_fallback_source_id], "textures": [fallback_texture()], "weights": [1], "total": 1}
	return _tile_sets[key]

static func _add_tile_source(texture: Texture2D) -> int:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i.ZERO)
	return _tileset.add_source(source)

static func _build_tileset() -> void:
	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_tile_sets.clear()
	_fallback_source_id = _add_tile_source(fallback_texture())
	for biome in Manifest.TILES.keys():
		for role in Manifest.TILES[biome].keys():
			var entry := {"ids": [], "textures": [], "weights": [], "total": 0}
			for row in Manifest.TILES[biome][role]:
				var file := "tiles/%s/%s" % [biome, row[0]]
				var texture := _load(file)
				var source_id := _fallback_source_id
				if not is_fallback(texture):
					if texture.get_width() < TILE_SIZE or texture.get_height() < TILE_SIZE:
						_report("map tile %s%s is %dx%d, smaller than %dx%d" % [
							Manifest.ASSET_ROOT, file, texture.get_width(), texture.get_height(), TILE_SIZE, TILE_SIZE])
						texture = fallback_texture()
					else:
						if texture.get_width() != TILE_SIZE or texture.get_height() != TILE_SIZE:
							_report("map tile %s%s is %dx%d, only its top-left %dx%d is drawn" % [
								Manifest.ASSET_ROOT, file, texture.get_width(), texture.get_height(), TILE_SIZE, TILE_SIZE])
						source_id = _add_tile_source(texture)
				var weight: int = max(1, int(row[2]))
				entry["ids"].append(source_id)
				entry["textures"].append(texture)
				entry["weights"].append(weight)
				entry["total"] += weight
			if not entry["ids"].is_empty():
				_tile_sets[biome + "/" + role] = entry
