# art_manifest.gd
# The one list of every piece of art the game loads, and what is standing in for it.
#
# HOW TO REPLACE A PIECE OF ART
#   Find its row below (or in docs/ART_CHECKLIST.md), and save your own PNG over the
#   file named in the first column. Nothing else: no code change, no build step. Open
#   the project in Godot once (or run tools\run_checks.bat) so the new file is imported.
#   Everything is 32x32 pixels with a transparent background where the floor should
#   show through. Creature sprites and item icons may be larger; they are scaled to fit.
#
# HOW TO ADD ART FOR SOMETHING NEW (a new enemy type, item, biome, tile variant)
#   Add a row to the matching table and put the PNG where the table's comment says.
#   Leave the stand-in column as "" for a file that never had a placeholder.
#
# WHAT HAPPENS WHEN ART IS MISSING
#   The game shows a magenta-and-black checker instead and keeps running. The smoke
#   test (tools\run_checks.bat) fails and names the id or file that has no art.
#
# The second column is the Dungeon Crawl Stone Soup tile (CC0) the placeholder was
# copied from, relative to art_source/dcss-tiles/. It is only used for the checklist
# and by "tools/art_checklist.gd --copy-missing". See art_source/CREDITS.md.
#
# This file is data only. The lookups live in scripts/art_library.gd (ArtLibrary).
# No class_name on purpose: it is preloaded, so it never depends on the editor's cache.
extends RefCounted

const ASSET_ROOT := "res://assets/"
const STAND_IN_ROOT := "res://art_source/dcss-tiles/"

# Width and height of one map tile, in pixels
const TILE_SIZE := 32

# ============================================================================
#  MAP TILES  ->  assets/tiles/<biome>/<file>
# ============================================================================
# One block per biome (the names in scripts/room_library.gd), one list per tile role
# (the DungeonGenerator.TileType names, lower case). Each row is one variant:
#     [file, stand-in, weight]
# A cell picks one variant from its coordinates, always the same one. Weight is how
# often a variant turns up next to the others in its list: 8 beside 1 means roughly
# eight cells in nine. Walls, doors and decorations are drawn on top of a floor tile,
# so they may have transparent parts.

const TILE_ROLES: Array = ["floor", "wall", "door", "decoration"]

const TILES: Dictionary = {
	"house": {
		"floor": [
			["floor_1.png", "dngn/floor/sandstone_floor0.png", 1],
			["floor_2.png", "dngn/floor/sandstone_floor1.png", 1],
			["floor_3.png", "dngn/floor/sandstone_floor2.png", 1],
			["floor_4.png", "dngn/floor/sandstone_floor3.png", 1],
		],
		"wall": [
			["wall_1.png", "dngn/wall/brick_brown0.png", 1],
			["wall_2.png", "dngn/wall/brick_brown1.png", 1],
			["wall_3.png", "dngn/wall/brick_brown2.png", 1],
			["wall_4.png", "dngn/wall/brick_brown3.png", 1],
		],
		"door": [
			["door_1.png", "dngn/doors/closed_door.png", 1],
		],
		"decoration": [
			["decoration_1.png", "dngn/blue_fountain.png", 1],
		],
	},
	"cave": {
		"floor": [
			["floor_1.png", "dngn/floor/pebble_brown0.png", 1],
			["floor_2.png", "dngn/floor/pebble_brown1.png", 1],
			["floor_3.png", "dngn/floor/pebble_brown2.png", 1],
			["floor_4.png", "dngn/floor/pebble_brown3.png", 1],
		],
		"wall": [
			["wall_1.png", "dngn/wall/lair0.png", 1],
			["wall_2.png", "dngn/wall/lair1.png", 1],
			["wall_3.png", "dngn/wall/lair2.png", 1],
			["wall_4.png", "dngn/wall/lair3.png", 1],
		],
		"door": [
			["door_1.png", "dngn/doors/open_door.png", 1],
		],
		"decoration": [
			["decoration_1.png", "dngn/wall/crystal_wall_lightcyan.png", 2],
			["decoration_2.png", "dngn/wall/crystal_wall_lightblue.png", 1],
			["decoration_3.png", "dngn/wall/crystal_wall_lightmagenta.png", 1],
		],
	},
	"dungeon": {
		"floor": [
			["floor_1.png", "dngn/floor/rect_gray0.png", 1],
			["floor_2.png", "dngn/floor/rect_gray1.png", 1],
			["floor_3.png", "dngn/floor/rect_gray2.png", 1],
			["floor_4.png", "dngn/floor/rect_gray3.png", 1],
		],
		"wall": [
			["wall_1.png", "dngn/wall/brick_gray0.png", 1],
			["wall_2.png", "dngn/wall/brick_gray1.png", 1],
			["wall_3.png", "dngn/wall/brick_gray2.png", 1],
			["wall_4.png", "dngn/wall/brick_gray3.png", 1],
		],
		"door": [
			["door_1.png", "dngn/doors/gate_closed_middle.png", 1],
		],
		"decoration": [
			["decoration_1.png", "dngn/floor/pedestal_full.png", 1],
		],
	},
	"crypt": {
		"floor": [
			["floor_1.png", "dngn/floor/green_bones01.png", 1],
			["floor_2.png", "dngn/floor/green_bones02.png", 1],
			["floor_3.png", "dngn/floor/green_bones03.png", 1],
			["floor_4.png", "dngn/floor/green_bones04.png", 1],
		],
		"wall": [
			["wall_1.png", "dngn/wall/catacombs0.png", 4],
			["wall_2.png", "dngn/wall/catacombs1.png", 4],
			["wall_3.png", "dngn/wall/catacombs2.png", 4],
			["wall_4.png", "dngn/wall/catacombs3.png", 4],
			["wall_5.png", "dngn/wall/catacombs14.png", 1],
			["wall_6.png", "dngn/wall/catacombs15.png", 1],
		],
		"door": [
			["door_1.png", "dngn/doors/runed_door.png", 1],
		],
		"decoration": [
			["decoration_1.png", "dngn/vaults/sarcophagus_sealed.png", 1],
		],
	},
	"forest": {
		"floor": [
			["floor_1.png", "dngn/floor/grass/grass0.png", 8],
			["floor_2.png", "dngn/floor/grass/grass1.png", 8],
			["floor_3.png", "dngn/floor/grass/grass2.png", 8],
			["floor_4.png", "dngn/floor/grass/grass_flowers_blue1.png", 1],
			["floor_5.png", "dngn/floor/grass/grass_flowers_red1.png", 1],
			["floor_6.png", "dngn/floor/grass/grass_flowers_yellow1.png", 1],
		],
		"wall": [
			["wall_1.png", "dngn/trees/mangrove1.png", 3],
			["wall_2.png", "dngn/trees/mangrove2.png", 3],
			["wall_3.png", "dngn/trees/mangrove3.png", 3],
			["wall_4.png", "dngn/trees/tree1_yellow.png", 1],
			["wall_5.png", "dngn/trees/tree2_yellow.png", 1],
		],
		"door": [
			["door_1.png", "dngn/floor/grass/grass0-dirt-mix1.png", 1],
		],
		"decoration": [
			["decoration_1.png", "mon/fungi_plants/bush2.png", 1],
			["decoration_2.png", "mon/fungi_plants/bush3.png", 1],
			["decoration_3.png", "mon/fungi_plants/bush4.png", 1],
		],
	},
}

# ============================================================================
#  CREATURES AND LOOT  ->  assets/sprites/...
# ============================================================================
# Each row:  id: [file, stand-in]

# Enemy types (world.gd ENEMY_TYPE_DEFS)  ->  assets/sprites/enemies/<file>
const ENEMY_SPRITES: Dictionary = {
	"goblin":   ["goblin.png",   "mon/goblin.png"],
	"skeleton": ["skeleton.png", "mon/undead/skeletons/skeleton_humanoid_small.png"],
	"bandit":   ["bandit.png",   "mon/human.png"],
	"wolf":     ["wolf.png",     "mon/animals/wolf.png"],
}

# The player, by class id (data/classes)  ->  assets/sprites/player/<file>
const PLAYER_SPRITES: Dictionary = {
	"fighter": ["fighter.png", "mon/unique/terence.png"],
	"wizard":  ["wizard.png",  "mon/unique/jessica.png"],
	"cleric":  ["cleric.png",  "mon/unique/edmund.png"],
	"rogue":   ["rogue.png",   "mon/unique/maurice.png"],
}
# Shown while the player has no class yet
const PLAYER_DEFAULT_CLASS := "fighter"

# Companions, by companion id (data/companions/companion_library.gd)
#   ->  assets/sprites/companions/<file>
# A companion with no row of its own is drawn with the player sprite of its class.
const COMPANION_SPRITES: Dictionary = {
	"kaelen":  ["kaelen.png",  "mon/vault_guard.png"],
	"lyra":    ["lyra.png",    "mon/deep_elf_conjurer.png"],
	"brom":    ["brom.png",    "mon/dwarf.png"],
	"whisper": ["whisper.png", "mon/halfling.png"],
}

# Loot lying on the floor  ->  assets/sprites/loot/<file>
#   "items": the drop holds at least one item;  "gold": coins only
const LOOT_SPRITES: Dictionary = {
	"items": ["loot_bag.png",  "item/armour/animal_skin1.png"],
	"gold":  ["loot_gold.png", "item/gold/10.png"],
}

# ============================================================================
#  ITEM ICONS  ->  assets/icons/items/<file>
# ============================================================================
# Each row:  icon name: [file, stand-in]
#
# How an item finds its icon (first match wins):
#   1. ITEM_ICON_ALIASES has the item id          explorer_pack   -> "pack"
#   2. the item id is an icon name                potion_healing  -> "potion_healing"
#   3. the id ends in "_<icon name>" (base type)  steel_longsword -> "longsword"
#   4. the id starts with an ITEM_ICON_PREFIXES key   scroll_fireball -> "scroll"
# So every material variant of a weapon or armour piece shares its base type's icon.
# To give one item its own picture, add a row named after its full id
# ("steel_longsword") and it wins over the base type.

const ITEM_ICONS: Dictionary = {
	# Weapons (ItemDatabase.WEAPON_BASES)
	"dagger":         ["dagger.png",         "item/weapon/dagger.png"],
	"shortsword":     ["shortsword.png",     "item/weapon/short_sword1.png"],
	"longsword":      ["longsword.png",      "item/weapon/long_sword1.png"],
	"greatsword":     ["greatsword.png",     "item/weapon/greatsword1.png"],
	"handaxe":        ["handaxe.png",        "item/weapon/hand_axe1.png"],
	"battleaxe":      ["battleaxe.png",      "UNUSED/weapons/battle_axe4.png"],
	"greataxe":       ["greataxe.png",       "UNUSED/weapons/executioner_axe4.png"],
	"mace":           ["mace.png",           "item/weapon/mace1.png"],
	"warhammer":      ["warhammer.png",      "UNUSED/weapons/hammer1.png"],
	"spear":          ["spear.png",          "item/weapon/spear1.png"],
	"rapier":         ["rapier.png",         "item/weapon/rapier1.png"],
	"quarterstaff":   ["quarterstaff.png",   "item/weapon/quarterstaff.png"],
	"club":           ["club.png",           "item/weapon/club.png"],
	"shortbow":       ["shortbow.png",       "item/weapon/ranged/shortbow1.png"],
	"longbow":        ["longbow.png",        "item/weapon/ranged/longbow1.png"],
	"light_crossbow": ["light_crossbow.png", "item/weapon/ranged/hand_crossbow.png"],
	"heavy_crossbow": ["heavy_crossbow.png", "item/weapon/ranged/arbalest1.png"],

	# Metal armour (ItemDatabase.ARMOR_BASES)
	"helmet":      ["helmet.png",      "item/armour/headgear/helmet1.png"],
	"chestplate":  ["chestplate.png",  "item/armour/plate1.png"],
	"chain_mail":  ["chain_mail.png",  "item/armour/scale_mail1.png"],
	"scale_mail":  ["scale_mail.png",  "item/armour/scale_mail2.png"],
	"gauntlets":   ["gauntlets.png",   "UNUSED/armour/gauntlet1.png"],
	"greaves":     ["greaves.png",     "player/legs/leg_armour01.png"],
	"plate_boots": ["plate_boots.png", "UNUSED/armour/boots_iron2.png"],
	"shield":      ["shield.png",      "UNUSED/armour/shield2.png"],
	# Leather armour
	"leather_cap": ["leather_cap.png", "UNUSED/armour/cap1.png"],
	"jerkin":      ["jerkin.png",      "item/armour/leather_armour1.png"],
	"gloves":      ["gloves.png",      "item/armour/glove1.png"],
	"leggings":    ["leggings.png",    "player/legs/pants_brown.png"],
	"boots":       ["boots.png",       "item/armour/boots1_brown.png"],
	# Cloth armour
	"hood":        ["hood.png",        "item/armour/headgear/hat1.png"],
	"robe":        ["robe.png",        "item/armour/robe1.png"],
	"wraps":       ["wraps.png",       "item/armour/artefact/urand_fencer.png"],
	"pants":       ["pants.png",       "player/legs/pants_l_white.png"],
	"slippers":    ["slippers.png",    "item/armour/boots3_stripe.png"],

	# Accessories
	"ring_protection":  ["ring_protection.png",  "item/ring/artefact/urand_shadows.png"],
	"ring_strength":    ["ring_strength.png",    "item/ring/ruby.png"],
	"ring_dexterity":   ["ring_dexterity.png",   "item/ring/tourmaline.png"],
	"ring_wisdom":      ["ring_wisdom.png",      "item/ring/artefact/urand_octoring.png"],
	"amulet_health":    ["amulet_health.png",    "item/amulet/crystal_red.png"],
	"amulet_charisma":  ["amulet_charisma.png",  "item/amulet/cameo_blue.png"],
	"cloak_protection": ["cloak_protection.png", "item/armour/cloak3.png"],
	"cloak_stealth":    ["cloak_stealth.png",    "item/armour/cloak2.png"],
	"belt":             ["belt.png",             "item/weapon/ranged/sling2.png"],
	"trinket_luck":     ["trinket_luck.png",     "item/misc/runes/rune_elven.png"],
	"trinket_arcane":   ["trinket_arcane.png",   "item/misc/misc_crystal.png"],
	"holy_symbol":      ["holy_symbol.png",      "item/amulet/celtic_yellow.png"],

	# Consumables
	"potion_healing_minor":   ["potion_healing_minor.png",   "item/potion/puce.png"],
	"potion_healing":         ["potion_healing.png",         "item/potion/ruby.png"],
	"potion_healing_greater": ["potion_healing_greater.png", "item/potion/magenta.png"],
	"antidote":               ["antidote.png",               "item/potion/bubbly.png"],
	"elixir_strength":        ["elixir_strength.png",        "item/potion/orange.png"],
	"elixir_agility":         ["elixir_agility.png",         "item/potion/cyan.png"],
	"elixir_resist_fire":     ["elixir_resist_fire.png",     "item/potion/brilliant_blue.png"],
	"elixir_mana":            ["elixir_mana.png",            "item/potion/effervescent.png"],
	"elixir_fortitude":       ["elixir_fortitude.png",       "item/potion/yellow.png"],
	"bread":                  ["bread.png",                  "item/food/bread_ration.png"],
	"cooked_meat":            ["cooked_meat.png",            "item/food/chunk.png"],
	"hearty_stew":            ["hearty_stew.png",            "item/food/meat_ration.png"],

	# Packs, tools, books
	"pack":            ["pack.png",            "item/armour/artefact/urand_ratskin_cloak.png"],
	"component_pouch": ["component_pouch.png", "item/weapon/ranged/sling1.png"],
	"spellbook":       ["spellbook.png",       "item/book/dark_blue.png"],
	"thieves_tools":   ["thieves_tools.png",   "item/weapon/ranged/needle-c.png"],

	# Crafting materials, one icon per material category
	"material_metal":   ["material_metal.png",   "item/misc/misc_stone.png"],
	"material_wood":    ["material_wood.png",    "item/weapon/giant_club.png"],
	"material_leather": ["material_leather.png", "item/armour/animal_skin1.png"],
	"material_cloth":   ["material_cloth.png",   "item/armour/artefact/urand_starlight.png"],

	# Field repair: the kit, and scrap, one icon per material category
	"repair_kit":    ["repair_kit.png",    "item/misc/misc_box.png"],
	"scrap_metal":   ["scrap_metal.png",   "item/misc/misc_stone_inert.png"],
	"scrap_wood":    ["scrap_wood.png",    "item/weapon/giant_club2.png"],
	"scrap_leather": ["scrap_leather.png", "item/armour/animal_skin2.png"],
	"scrap_cloth":   ["scrap_cloth.png",   "item/armour/robe2.png"],

	# Spell items (registered by SpellDatabase)
	"scroll": ["scroll.png", "item/scroll/scroll.png"],
	"wand":   ["wand.png",   "item/wand/gem_silver.png"],
}

# Item ids that use an icon with a different name
const ITEM_ICON_ALIASES: Dictionary = {
	"leather_armor": "jerkin",

	"explorer_pack": "pack",
	"scholar_pack":  "pack",
	"priest_pack":   "pack",
	"burglar_pack":  "pack",

	# Crafting materials (ItemDatabase.load_materials), by kind
	"material_copper":         "material_metal",
	"material_wrought_iron":   "material_metal",
	"material_bronze":         "material_metal",
	"material_steel":          "material_metal",
	"material_silver":         "material_metal",
	"material_damascus_steel": "material_metal",
	"material_mythril":        "material_metal",
	"material_adamantite":     "material_metal",

	"material_pine":     "material_wood",
	"material_oak":      "material_wood",
	"material_ash":      "material_wood",
	"material_maple":    "material_wood",
	"material_hickory":  "material_wood",
	"material_ironwood": "material_wood",
	"material_yew":      "material_wood",
	"material_ebony":    "material_wood",
	"material_starwood": "material_wood",

	"material_pigskin":        "material_leather",
	"material_deerskin":       "material_leather",
	"material_cowhide":        "material_leather",
	"material_boiled_leather": "material_leather",
	"material_wolfhide":       "material_leather",
	"material_bearhide":       "material_leather",
	"material_scaled_leather": "material_leather",
	"material_wyvern_leather": "material_leather",
	"material_dragon_leather": "material_leather",

	"material_burlap":          "material_cloth",
	"material_roughspun_wool":  "material_cloth",
	"material_cotton":          "material_cloth",
	"material_wool":            "material_cloth",
	"material_fine_linen":      "material_cloth",
	"material_silk":            "material_cloth",
	"material_spidersilk":      "material_cloth",
	"material_celestial_cloth": "material_cloth",

	# Scrap (ItemDatabase: scrap_<material id>), by kind
	"scrap_copper":         "scrap_metal",
	"scrap_wrought_iron":   "scrap_metal",
	"scrap_bronze":         "scrap_metal",
	"scrap_steel":          "scrap_metal",
	"scrap_silver":         "scrap_metal",
	"scrap_damascus_steel": "scrap_metal",
	"scrap_mythril":        "scrap_metal",
	"scrap_adamantite":     "scrap_metal",

	"scrap_pine":     "scrap_wood",
	"scrap_oak":      "scrap_wood",
	"scrap_ash":      "scrap_wood",
	"scrap_maple":    "scrap_wood",
	"scrap_hickory":  "scrap_wood",
	"scrap_ironwood": "scrap_wood",
	"scrap_yew":      "scrap_wood",
	"scrap_ebony":    "scrap_wood",
	"scrap_starwood": "scrap_wood",

	"scrap_pigskin":        "scrap_leather",
	"scrap_deerskin":       "scrap_leather",
	"scrap_cowhide":        "scrap_leather",
	"scrap_boiled_leather": "scrap_leather",
	"scrap_wolfhide":       "scrap_leather",
	"scrap_bearhide":       "scrap_leather",
	"scrap_scaled_leather": "scrap_leather",
	"scrap_wyvern_leather": "scrap_leather",
	"scrap_dragon_leather": "scrap_leather",

	"scrap_burlap":          "scrap_cloth",
	"scrap_roughspun_wool":  "scrap_cloth",
	"scrap_cotton":          "scrap_cloth",
	"scrap_wool":            "scrap_cloth",
	"scrap_fine_linen":      "scrap_cloth",
	"scrap_silk":            "scrap_cloth",
	"scrap_spidersilk":      "scrap_cloth",
	"scrap_celestial_cloth": "scrap_cloth",
}

# Families of item ids that share one icon:  id prefix -> icon name
const ITEM_ICON_PREFIXES: Dictionary = {
	"scroll_": "scroll",
	"wand_":   "wand",
	"belt_":   "belt",
}
