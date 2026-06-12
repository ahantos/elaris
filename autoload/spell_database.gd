# spell_database.gd
# AutoLoad singleton - definitions for all spells (80+ across all 8 schools, levels 0-9).
# Pure data registry: definitions live in data/spells/spell_library.gd and are loaded
# once in _ready(). Also registers scroll_<spell_id> / wand_<spell_id> items with
# ItemDatabase for a set of iconic spells (re-registered every boot, so saved scroll/wand
# instances never dangle). Owned by A4 (Magic) - see docs/ARCHITECTURE_CONTRACTS.md.
extends Node

# Explicit preload (not the class_name global) so boot never depends on the editor's
# global script-class cache having scanned the new data/spells/ folder.
const SpellLibraryData = preload("res://data/spells/spell_library.gd")

const VALID_SCHOOLS: Array = [
	"abjuration", "conjuration", "divination", "enchantment",
	"evocation", "illusion", "necromancy", "transmutation"
]

# Iconic spells that get scroll_<id> + wand_<id> items registered at boot
const SPELL_ITEM_IDS: Array = [
	"fire_bolt", "magic_missile", "cure_wounds", "bless", "misty_step",
	"scorching_ray", "fireball", "lightning_bolt", "hold_person", "ice_storm"
]

const WAND_CHARGES: int = 7

# spell_id -> spell definition Dictionary (see contracts doc for the schema)
var spells: Dictionary = {}

func _ready():
	spells = SpellLibraryData.get_definitions()
	_validate_definitions()
	var item_count = _register_spell_items()
	print("SpellDatabase: registered %d spells (+%d spell items)" % [spells.size(), item_count])

func get_spell(spell_id: String) -> Dictionary:
	"""Get spell definition by ID"""
	return spells.get(spell_id, {})

func get_all_spells() -> Array:
	"""Get all spell definitions"""
	return spells.values()

func get_spells_by_level(level: int) -> Array:
	"""Get all spells of a given spell level (0 = cantrip)"""
	var result = []
	for spell in spells.values():
		if spell.get("level", 0) == level:
			result.append(spell)
	return result

func get_spells_by_school(school: String) -> Array:
	"""Get all spells of a given school"""
	var result = []
	for spell in spells.values():
		if spell.get("school", "") == school:
			result.append(spell)
	return result

func get_spells_for_class(class_id: String, max_level: int = 9) -> Array:
	"""Get all spells castable by a class, up to an optional max spell level"""
	var result = []
	for spell in spells.values():
		if int(spell.get("level", 0)) > max_level:
			continue
		if class_id in spell.get("classes", []):
			result.append(spell)
	return result

func has_spell(spell_id: String) -> bool:
	"""True when a spell id exists in the registry"""
	return spells.has(spell_id)

# === INTERNAL: VALIDATION ===

func _validate_definitions():
	"""Sanity-check the registry at boot (programmer errors only - never fatal)."""
	for spell_id in spells:
		var spell: Dictionary = spells[spell_id]
		if spell.get("spell_id", "") != spell_id:
			push_error("SpellDatabase: spell key '%s' does not match its spell_id '%s'" % [spell_id, spell.get("spell_id", "")])
		var level = int(spell.get("level", -1))
		if level < 0 or level > 9:
			push_error("SpellDatabase: spell '%s' has invalid level %d" % [spell_id, level])
		if not VALID_SCHOOLS.has(spell.get("school", "")):
			push_error("SpellDatabase: spell '%s' has unknown school '%s'" % [spell_id, spell.get("school", "")])
		if spell.get("display_name", "") == "":
			push_error("SpellDatabase: spell '%s' has no display_name" % spell_id)

# === INTERNAL: SPELL ITEM REGISTRATION ===

func _register_spell_items() -> int:
	"""Register scroll_<spell_id> (single-use CONSUMABLE) and wand_<spell_id>
	(7-charge MISC item; current_durability = remaining charges) items with
	ItemDatabase for the iconic spell list. Returns the number of items registered.
	Runs every boot, so saved instances of these ids always resolve."""
	if not ItemDatabase.has_method("register_item"):
		push_error("SpellDatabase: ItemDatabase.register_item missing - spell items not registered")
		return 0

	var count = 0
	for spell_id in SPELL_ITEM_IDS:
		var spell: Dictionary = spells.get(spell_id, {})
		if spell.is_empty():
			push_error("SpellDatabase: cannot register items for unknown spell '%s'" % spell_id)
			continue
		ItemDatabase.register_item(_build_scroll_item(spell))
		ItemDatabase.register_item(_build_wand_item(spell))
		count += 2
	return count

func _build_scroll_item(spell: Dictionary) -> ItemData:
	"""Single-use spell scroll: CONSUMABLE, cast via SpellManager.use_scroll()."""
	var level = int(spell.get("level", 0))
	var item = ItemData.new()
	item.item_id = "scroll_" + str(spell.get("spell_id", ""))
	item.item_name = "Scroll of " + str(spell.get("display_name", "?"))
	item.item_type = ItemData.ItemType.CONSUMABLE
	item.is_consumable = true
	item.consumable_effect = "cast_spell"
	item.consumable_power = level
	item.stackable = true
	item.max_stack_size = 5
	item.weight = 0.1
	item.base_value = 25 + level * 50
	item.is_magical = true
	item.description = "A single-use scroll. Casts %s (level %d %s) without spending a spell slot, then crumbles to dust." % [
		str(spell.get("display_name", "?")), level, str(spell.get("school", ""))]
	return item

func _build_wand_item(spell: Dictionary) -> ItemData:
	"""Spell wand: WAND_CHARGES charges tracked as instance durability
	(SpellManager.use_wand decrements current_durability; 0 charges = fizzle)."""
	var level = int(spell.get("level", 0))
	var item = ItemData.new()
	item.item_id = "wand_" + str(spell.get("spell_id", ""))
	item.item_name = "Wand of " + str(spell.get("display_name", "?"))
	item.item_type = ItemData.ItemType.MISC
	item.has_durability = true
	item.max_durability = WAND_CHARGES
	item.can_break_permanently = false
	item.weight = 1.0
	item.base_value = 150 + level * 200
	item.is_magical = true
	item.description = "A slender wand holding %d charges of %s (level %d %s). Each use spends one charge; a spent wand merely fizzles." % [
		WAND_CHARGES, str(spell.get("display_name", "?")), level, str(spell.get("school", ""))]
	return item
