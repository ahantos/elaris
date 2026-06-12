# dialogue_manager.gd
# AutoLoad singleton - dialogue trees with choices, skill-check branches, conditions, and effects.
# Owned by A6 (World & Story). Hand-authored trees live in data/dialogues/zone_1_dialogues.gd.
#
# Session flow (integration: call start_dialogue, then UIManager.open_panel("dialogue")):
#   start_dialogue  -> emits dialogue_started, session begins at start_node ("root")
#   get_current_node -> node enriched with ONLY the choices whose conditions pass
#   make_choice(i)  -> i indexes that filtered choice list; resolves skill_check via
#                      GameManager.player.stats.make_skill_check (CharacterStats emits
#                      skill_check_made itself), applies effects, advances to next node
#   next == ""      -> end_dialogue -> emits dialogue_ended (QuestManager talk objectives)
#
# Condition types: quest_active | quest_completed | quest_not_started (A6 extension;
# also true for failed quests) | reputation_at_least | relationship_at_least | has_item.
# Unknown condition types fail OPEN (choice shown) with a warning.
# Effect types: start_quest, give_item, take_item, give_gold (negative = take gold),
# reputation, relationship, recruit_companion, start_crisis (only fires while the
# crisis is still dormant). CompanionManager calls are has_method-guarded (A7 builds
# it concurrently).
extends Node

const Zone1Dialogues = preload("res://data/dialogues/zone_1_dialogues.gd")

# dialogue_id -> dialogue tree definition (see contracts doc for the schema)
var dialogues: Dictionary = {}

# Active session state (transient — never saved)
var _active: bool = false
var _current_dialogue_id: String = ""
var _current_npc_id: String = ""
var _current_node_id: String = ""

func _ready():
	var defs: Dictionary = Zone1Dialogues.get_definitions()
	for dialogue_id in defs:
		register_dialogue(dialogue_id, defs[dialogue_id])
	print("Dialogue: DialogueManager initialized — ", dialogues.size(), " dialogues registered")

func register_dialogue(dialogue_id: String, dialogue: Dictionary):
	dialogues[dialogue_id] = dialogue

# === SESSION ===

func start_dialogue(dialogue_id: String, npc_id: String = "") -> bool:
	"""Begin a dialogue session. Returns false if unknown, malformed, or another
	dialogue is already active. Emits EventBus.dialogue_started on success.
	npc_id defaults to the dialogue_id when omitted."""
	if _active:
		push_warning("Dialogue: start_dialogue('" + dialogue_id + "') while '"
			+ _current_dialogue_id + "' is active — refused")
		return false
	if not dialogues.has(dialogue_id):
		push_error("Dialogue: unknown dialogue: " + dialogue_id)
		return false

	var dialogue: Dictionary = dialogues[dialogue_id]
	var start_node: String = str(dialogue.get("start_node", "root"))
	if not dialogue.get("nodes", {}).has(start_node):
		push_error("Dialogue: '" + dialogue_id + "' missing start node '" + start_node + "'")
		return false

	_active = true
	_current_dialogue_id = dialogue_id
	_current_npc_id = npc_id if npc_id != "" else dialogue_id
	_current_node_id = start_node

	print("Dialogue: started '", dialogue_id, "' (npc: ", _current_npc_id, ")")
	EventBus.dialogue_started.emit(_current_npc_id, dialogue_id)
	return true

func make_choice(choice_index: int):
	"""Pick a choice by index into the FILTERED choice list (what get_current_node
	returned). Resolves skill checks, applies effects, then advances or ends."""
	if not _active:
		push_error("Dialogue: make_choice with no active dialogue")
		return
	var node: Dictionary = _get_raw_node(_current_node_id)
	var choices: Array = _get_available_choices(node)
	if choice_index < 0 or choice_index >= choices.size():
		push_error("Dialogue: choice index %d out of range (%d choices)" % [choice_index, choices.size()])
		return

	var choice: Dictionary = choices[choice_index]
	EventBus.dialogue_choice_made.emit(_current_dialogue_id, _current_node_id, choice_index)

	# Skill-check branches override the plain "next" target.
	var next: String = str(choice.get("next", ""))
	if choice.has("skill_check"):
		var check: Dictionary = choice["skill_check"]
		var success := _resolve_skill_check(check)
		next = str(check.get("success_next", "")) if success else str(check.get("failure_next", ""))

	for effect in choice.get("effects", []):
		_apply_effect(effect)

	if next == "":
		end_dialogue()
		return
	if not dialogues[_current_dialogue_id].get("nodes", {}).has(next):
		push_error("Dialogue: '" + _current_dialogue_id + "' has no node '" + next + "' — ending")
		end_dialogue()
		return
	_current_node_id = next

func end_dialogue():
	"""End the active session. Emits EventBus.dialogue_ended (which drives
	QuestManager talk objectives). State is cleared before emitting."""
	if not _active:
		return
	var npc_id := _current_npc_id
	var dialogue_id := _current_dialogue_id
	_active = false
	_current_dialogue_id = ""
	_current_npc_id = ""
	_current_node_id = ""
	print("Dialogue: ended '", dialogue_id, "'")
	EventBus.dialogue_ended.emit(npc_id, dialogue_id)

func is_active() -> bool:
	return _active

func get_current_node() -> Dictionary:
	"""The active node enriched for UI: {speaker, text, node_id, npc_name,
	choices: [only choices whose conditions pass]}. {} when inactive."""
	if not _active:
		return {}
	var node: Dictionary = _get_raw_node(_current_node_id)
	if node.is_empty():
		return {}
	var dialogue: Dictionary = dialogues[_current_dialogue_id]
	return {
		"node_id": _current_node_id,
		"npc_name": dialogue.get("npc_name", _current_npc_id),
		"speaker": node.get("speaker", dialogue.get("npc_name", "")),
		"text": node.get("text", ""),
		"choices": _get_available_choices(node),
	}

func _get_raw_node(node_id: String) -> Dictionary:
	if not _active:
		return {}
	return dialogues.get(_current_dialogue_id, {}).get("nodes", {}).get(node_id, {})

# === CONDITIONS ===

func _get_available_choices(node: Dictionary) -> Array:
	"""Choices whose conditions pass, in authored order (used by both
	get_current_node and make_choice so indices always agree)."""
	var available: Array = []
	for choice in node.get("choices", []):
		if not choice.has("condition") or _check_condition(choice["condition"]):
			available.append(choice)
	return available

func _check_condition(condition: Dictionary) -> bool:
	"""Evaluate a choice condition. Unknown types fail open with a warning."""
	match str(condition.get("type", "")):
		"quest_active":
			return QuestManager.get_quest_status(str(condition.get("quest_id", ""))) == "active"
		"quest_completed":
			return QuestManager.get_quest_status(str(condition.get("quest_id", ""))) == "completed"
		"quest_not_started":
			var status: String = QuestManager.get_quest_status(str(condition.get("quest_id", "")))
			return status == "not_started" or status == "failed"
		"reputation_at_least":
			return FactionManager.get_reputation(str(condition.get("faction_id", ""))) \
				>= int(condition.get("value", 0))
		"relationship_at_least":
			if CompanionManager.has_method("get_relationship"):
				return CompanionManager.get_relationship(str(condition.get("companion_id", ""))) \
					>= int(condition.get("value", 0))
			return false
		"has_item":
			return InventoryManager.has_item(str(condition.get("item_id", "")))
		_:
			push_warning("Dialogue: unknown condition type '" + str(condition.get("type", "")) + "'")
			return true

# === SKILL CHECKS ===

func _resolve_skill_check(check: Dictionary) -> bool:
	"""Roll the player's skill check (bool). No player/stats available counts as
	a failure. CharacterStats emits skill_check_made itself — nothing extra here."""
	var player = GameManager.player
	if player != null and is_instance_valid(player):
		var stats = player.get("stats")
		if stats != null and stats.has_method("make_skill_check"):
			return bool(stats.make_skill_check(str(check.get("skill", "persuasion")),
				int(check.get("dc", 10))))
	push_warning("Dialogue: no player stats for skill check — treating as failure")
	return false

# === EFFECTS ===

func _apply_effect(effect: Dictionary):
	"""Apply one choice effect (see file header for the supported types)."""
	match str(effect.get("type", "")):
		"start_quest":
			QuestManager.start_quest(str(effect.get("quest_id", "")))
		"give_item":
			_give_items(str(effect.get("item_id", "")), int(effect.get("count", 1)),
				int(effect.get("quality", 0)), int(effect.get("magic", 0)))
		"take_item":
			_take_items(str(effect.get("item_id", "")), int(effect.get("count", 1)))
		"give_gold":
			var amount: int = int(effect.get("amount", 0))
			if amount >= 0:
				InventoryManager.add_gold(amount)
			else:
				InventoryManager.remove_gold(-amount)
		"reputation":
			FactionManager.modify_reputation(str(effect.get("faction_id", "")),
				int(effect.get("delta", 0)))
		"relationship":
			if CompanionManager.has_method("modify_relationship"):
				CompanionManager.modify_relationship(str(effect.get("companion_id", "")),
					int(effect.get("delta", 0)))
		"recruit_companion":
			if CompanionManager.has_method("recruit"):
				CompanionManager.recruit(str(effect.get("companion_id", "")))
		"start_crisis":
			var crisis_id: String = str(effect.get("crisis_id", "lich_king_rises"))
			if WorldEventManager.get_crisis_phase(crisis_id) == 0:
				WorldEventManager.advance_crisis(crisis_id)
		_:
			push_warning("Dialogue: unknown effect type '" + str(effect.get("type", "")) + "'")

func _give_items(item_id: String, count: int, quality: int = 0, magic: int = 0):
	for _i in range(maxi(1, count)):
		var instance: Dictionary = ItemDatabase.create_item_instance(item_id, quality, magic)
		if instance.is_empty():
			push_error("Dialogue: give_item failed — unknown item: " + item_id)
			return
		InventoryManager.add_item(instance)

func _take_items(item_id: String, count: int):
	"""Remove up to `count` of item_id from the inventory (stack-aware)."""
	for _i in range(maxi(1, count)):
		var found: Dictionary = {}
		for item in InventoryManager.items:
			if item.get("item_data") != null and item.item_data.item_id == item_id:
				found = item
				break
		if found.is_empty():
			push_warning("Dialogue: take_item — player has no '" + item_id + "' left")
			return
		InventoryManager.remove_item(str(found.get("instance_id", "")))

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Dialogue sessions are transient and never persisted (by design — saving
	mid-conversation is not supported). Nothing to export."""
	return {}

func from_dict(_data: Dictionary):
	pass
