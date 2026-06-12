# companion_manager.gd
# AutoLoad singleton — recruitable companions, the active party,
# relationship values, and romance tracks.
# Panel id: "companions"  (registered by the orchestrator).
extends Node

# ── Constants ────────────────────────────────────────────────────────────────
const PARTY_CAP: int = 3
const REL_MIN:   int = -100
const REL_MAX:   int = 100

# Romance thresholds (forward)
const ROMANCE_INTERESTED_THRESHOLD: int = 30
const ROMANCE_DATING_THRESHOLD:     int = 60
const ROMANCE_COMMITTED_THRESHOLD:  int = 90

# Gift relationship deltas
const GIFT_DELTA_LOVED:   int =  15
const GIFT_DELTA_LIKED:   int =  8
const GIFT_DELTA_DISLIKED: int = -5
const GIFT_DELTA_NEUTRAL: int =  3

# Gift flavour lines (companion_id → [loved_line, liked_line, disliked_line, neutral_line])
const _GIFT_FLAVOUR: Dictionary = {
	"kaelen": [
		"Kaelen turns the weapon over slowly. \"Good steel. I'll put it to use.\"",
		"Kaelen gives a short nod. \"Useful. Thanks.\"",
		"Kaelen looks at the cloth with a flat expression. \"...Right.\"",
		"Kaelen tucks it away without comment, which is about as warm as he gets.",
	],
	"lyra": [
		"Lyra's eyes light up. She immediately opens it, nearly dropping everything else she's holding.",
		"Lyra smiles. \"Oh, this is actually quite lovely.\"",
		"Lyra accepts it politely. \"I'm sure someone finds these... practical.\"",
		"Lyra slips it into her satchel. \"Thank you. Really.\"",
	],
	"brom": [
		"Brom's face splits into a grin. \"THAT'S the stuff! Tonight we feast!\"",
		"Brom slaps you on the shoulder hard enough to stagger you. \"Good lad/lass!\"",
		"Brom accepts it with a good-natured shrug. \"Not exactly my style, but I'll find a use.\"",
		"Brom nods warmly. \"You're alright, you know that?\"",
	],
	"whisper": [
		"Whisper's fingers close around it before you've finished handing it over. \"Where'd you get this? Never mind. Mine now.\"",
		"Whisper smirks. \"Not bad. You're improving.\"",
		"Whisper turns it over with two fingers like it's slightly suspicious. \"I suppose I could re-gift it.\"",
		"Whisper pockets it. \"I'll figure out a use for it.\"",
	],
}

# ── State ─────────────────────────────────────────────────────────────────────
# companion_id → companion definition dict (from CompanionLibrary)
var companion_definitions: Dictionary = {}

# companion_id → runtime state
# { recruited: bool, in_party: bool, relationship: int, romance_status: String }
var companion_states: Dictionary = {}


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready():
	"""Load all companion definitions from the library helper."""
	_load_definitions()
	print("Companions: %d companions loaded" % companion_definitions.size())


func _load_definitions():
	"""Load companion_library.gd at runtime (avoids hard class_name dependency)."""
	var path = "res://data/companions/companion_library.gd"
	if not ResourceLoader.exists(path):
		push_error("CompanionManager: companion_library.gd not found at %s" % path)
		return

	var lib_script = load(path)
	if lib_script == null:
		push_error("CompanionManager: failed to load companion_library.gd")
		return

	var lib_instance = lib_script.new()
	if not lib_instance.has_method("get_all"):
		push_error("CompanionManager: companion_library has no get_all() method")
		return

	companion_definitions = lib_instance.get_all()

	# Initialise default state for every companion
	for cid in companion_definitions:
		companion_states[cid] = {
			"recruited":     false,
			"in_party":      false,
			"relationship":  0,
			"romance_status": "none",
		}


# ── Public API (all stub signatures kept; new params use defaults) ─────────────

func get_companions() -> Array:
	"""Return all companion definitions as an Array of Dictionaries."""
	return companion_definitions.values()


func recruit(companion_id: String) -> bool:
	"""
	Mark a companion as recruited and put them in the active party.
	Returns false if the companion doesn't exist, is already recruited,
	or the party is full.
	"""
	if not companion_definitions.has(companion_id):
		push_error("Companions: recruit() — unknown companion '%s'" % companion_id)
		return false

	var state: Dictionary = companion_states[companion_id]

	if state.recruited:
		EventBus.ui_notification.emit(
			"%s is already with you." % companion_definitions[companion_id].display_name,
			"info")
		return false

	# Party cap check
	var party = get_party()
	if party.size() >= PARTY_CAP:
		EventBus.ui_notification.emit(
			"Party is full! Dismiss a companion first (max %d)." % PARTY_CAP,
			"warning")
		return false

	state.recruited = true
	state.in_party  = true

	var display = companion_definitions[companion_id].display_name
	print("Companions: recruited %s" % display)
	EventBus.companion_recruited.emit(companion_id)
	EventBus.ui_notification.emit("%s has joined your party!" % display, "success")
	return true


func dismiss(companion_id: String):
	"""Remove a companion from the active party (keeps them recruited)."""
	if not companion_states.has(companion_id):
		push_error("Companions: dismiss() — unknown companion '%s'" % companion_id)
		return

	var state: Dictionary = companion_states[companion_id]
	if not state.in_party:
		return

	state.in_party = false
	var display = companion_definitions[companion_id].display_name
	print("Companions: dismissed %s" % display)
	EventBus.companion_dismissed.emit(companion_id)
	EventBus.ui_notification.emit("%s has left the active party." % display, "info")


func get_party() -> Array:
	"""Return the ids of companions currently in the active party."""
	var result: Array = []
	for cid in companion_states:
		if companion_states[cid].in_party:
			result.append(cid)
	return result


func get_relationship(companion_id: String) -> int:
	"""Return the current relationship value (-100..100)."""
	if not companion_states.has(companion_id):
		return 0
	return companion_states[companion_id].relationship


func modify_relationship(companion_id: String, delta: int):
	"""
	Add delta to the relationship value (clamped to -100..100).
	Emits relationship_changed.
	Automatically advances / regresses romance status for romanceable companions.
	"""
	if not companion_states.has(companion_id):
		push_error("Companions: modify_relationship() — unknown companion '%s'" % companion_id)
		return

	var state: Dictionary = companion_states[companion_id]
	var old_rel: int = state.relationship
	state.relationship = clampi(old_rel + delta, REL_MIN, REL_MAX)
	var new_rel: int = state.relationship

	EventBus.relationship_changed.emit(companion_id, old_rel, new_rel)

	# Romance progression (romanceable companions only)
	var defn: Dictionary = companion_definitions[companion_id]
	if defn.get("romanceable", false):
		_update_romance(companion_id, new_rel)


func _update_romance(companion_id: String, rel: int):
	"""Advance or regress romance status based on relationship value."""
	var state: Dictionary = companion_states[companion_id]
	var old_status: String = state.romance_status
	var new_status: String = old_status

	if rel >= ROMANCE_COMMITTED_THRESHOLD:
		new_status = "committed"
	elif rel >= ROMANCE_DATING_THRESHOLD:
		new_status = "dating"
	elif rel >= ROMANCE_INTERESTED_THRESHOLD:
		new_status = "interested"
	else:
		new_status = "none"

	if new_status != old_status:
		state.romance_status = new_status
		print("Companions: %s romance status → %s" % [companion_id, new_status])
		EventBus.romance_status_changed.emit(companion_id, new_status)


func get_romance_status(companion_id: String) -> String:
	"""Return 'none' | 'interested' | 'dating' | 'committed'."""
	if not companion_states.has(companion_id):
		return "none"
	return companion_states[companion_id].get("romance_status", "none")


func give_gift(companion_id: String, item_instance: Dictionary) -> bool:
	"""
	Give an item from inventory to a companion.
	Consumes the item via InventoryManager.remove_item().
	Returns false if the companion isn't recruited or item_instance is invalid.

	Delta rules:
	  +15 if item_id is in gift_loved
	  +8  if item_id or a prefix token matches gift_liked
	  -5  if item_id or a prefix token matches gift_disliked
	  +3  otherwise (neutral)
	"""
	if not companion_states.has(companion_id):
		push_error("Companions: give_gift() — unknown companion '%s'" % companion_id)
		return false

	if not companion_states[companion_id].recruited:
		EventBus.ui_notification.emit("Recruit this companion before giving gifts.", "warning")
		return false

	if item_instance.is_empty() or not item_instance.has("instance_id"):
		push_error("Companions: give_gift() — invalid item_instance")
		return false

	var defn: Dictionary = companion_definitions[companion_id]
	var item_id: String = ""
	var item_type_int: int = -1

	if item_instance.has("item_data") and item_instance.item_data != null:
		var idata = item_instance.item_data
		if idata.has_method("get") or idata.get("item_id", "") != "":
			item_id = idata.get("item_id", "")
		elif "item_id" in idata:
			item_id = idata.item_id
		# item_type as int (ItemData.ItemType enum)
		if "item_type" in idata:
			item_type_int = int(idata.item_type)

	# ── Match category ─────────────────────────────────────────────────
	var delta: int = GIFT_DELTA_NEUTRAL
	var match_category: int = 3  # 0=loved 1=liked 2=disliked 3=neutral

	var loved:    Array = defn.get("gift_loved",    [])
	var liked:    Array = defn.get("gift_liked",    [])
	var disliked: Array = defn.get("gift_disliked", [])

	if _match_gift_list(item_id, item_type_int, loved):
		delta = GIFT_DELTA_LOVED
		match_category = 0
	elif _match_gift_list(item_id, item_type_int, liked):
		delta = GIFT_DELTA_LIKED
		match_category = 1
	elif _match_gift_list(item_id, item_type_int, disliked):
		delta = GIFT_DELTA_DISLIKED
		match_category = 2

	# ── Consume item ───────────────────────────────────────────────────
	InventoryManager.remove_item(item_instance.instance_id)

	# ── Apply relationship change ──────────────────────────────────────
	modify_relationship(companion_id, delta)

	# ── Flavour notification ───────────────────────────────────────────
	var flavour_line: String = _get_flavour_line(companion_id, match_category)
	EventBus.ui_notification.emit(flavour_line, "info")
	print("Companions: give_gift to %s → delta %+d (%s)" % [
		companion_id, delta,
		["loved", "liked", "disliked", "neutral"][match_category]
	])

	return true


func _match_gift_list(item_id: String, item_type_int: int, list: Array) -> bool:
	"""
	Match item_id / item_type against a gift preference list.
	Tokens understood:
	  Exact item_id match
	  "material_*" prefix  → item_id starts with token
	  "type:scroll"        → item_id starts with "scroll_"
	  "type:weapon"        → item_type_int == 0 (WEAPON)
	  "type:armor"         → item_type_int == 1 (ARMOR)
	  "type:consumable"    → item_type_int == 2 (CONSUMABLE)
	  "type:misc"          → item_type_int == 4 (MISC) or 3 (QUEST)
	  "type:cloth"         → item_id contains cloth-armour keyword
	"""
	var cloth_keywords: Array = ["hood", "robe", "wraps", "pants", "slippers"]

	for token in list:
		var t: String = str(token)

		if t == item_id:
			return true

		if t.begins_with("material_") and item_id.begins_with(t):
			return true

		if t.begins_with("type:"):
			var type_token = t.substr(5)
			match type_token:
				"scroll":
					if item_id.begins_with("scroll_"):
						return true
				"weapon":
					if item_type_int == 0:
						return true
				"armor":
					if item_type_int == 1:
						return true
				"consumable":
					if item_type_int == 2:
						return true
				"misc":
					if item_type_int == 4 or item_type_int == 3:
						return true
				"cloth":
					for kw in cloth_keywords:
						if kw in item_id:
							return true

	return false


func _get_flavour_line(companion_id: String, match_category: int) -> String:
	"""Return a flavour string for the gift reaction."""
	if _GIFT_FLAVOUR.has(companion_id):
		var lines: Array = _GIFT_FLAVOUR[companion_id]
		if match_category < lines.size():
			return lines[match_category]
	match match_category:
		0: return "They love it!"
		1: return "They seem pleased."
		2: return "They don't look impressed."
		_: return "They accept the gift."


# ── Node creation ──────────────────────────────────────────────────────────────

func create_companion_node(companion_id: String) -> Node:
	"""
	Build a CharacterBody2D node for a companion in code (no .tscn).
	Returns the node UNPARENTED — the integration layer adds it to the scene.
	Returns null if the companion is unknown or the script can't be loaded.
	"""
	if not companion_definitions.has(companion_id):
		push_error("Companions: create_companion_node() — unknown id '%s'" % companion_id)
		return null

	var script_path = "res://scripts/companion.gd"
	if not ResourceLoader.exists(script_path):
		push_error("Companions: companion.gd not found at %s" % script_path)
		return null

	var companion_script = load(script_path)
	if companion_script == null:
		push_error("Companions: failed to load companion.gd")
		return null

	# Create the CharacterBody2D node and attach the script
	var node: CharacterBody2D = CharacterBody2D.new()
	node.set_script(companion_script)
	node.name = "Companion_%s" % companion_id

	# The script's _ready() will initialise stats; we set companion_id first
	# so _ready() can look up the definition.
	node.set("companion_id", companion_id)

	return node


# ── Save / Load ───────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	"""
	Export companion_states for saving.  Primitives only.
	Schema: { companion_states: { companion_id: { recruited, in_party, relationship, romance_status } } }
	"""
	var exported_states: Dictionary = {}
	for cid in companion_states:
		var s: Dictionary = companion_states[cid]
		exported_states[cid] = {
			"recruited":      s.get("recruited",     false),
			"in_party":       s.get("in_party",      false),
			"relationship":   s.get("relationship",  0),
			"romance_status": s.get("romance_status","none"),
		}
	return {
		"companion_states": exported_states
	}


func from_dict(_data: Dictionary):
	"""
	Import companion_states from a save dictionary.
	Tolerant of missing keys (new companions added after save, old saves, etc.).
	"""
	var loaded_states: Dictionary = _data.get("companion_states", {})
	for cid in companion_states:
		if loaded_states.has(cid):
			var s: Dictionary = loaded_states[cid]
			companion_states[cid]["recruited"]     = s.get("recruited",     false)
			companion_states[cid]["in_party"]      = s.get("in_party",      false)
			companion_states[cid]["relationship"]  = clampi(s.get("relationship", 0), REL_MIN, REL_MAX)
			companion_states[cid]["romance_status"] = s.get("romance_status", "none")
	print("Companions: loaded companion states (%d entries)" % loaded_states.size())
