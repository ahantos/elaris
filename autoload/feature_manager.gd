# feature_manager.gd
# AutoLoad singleton - racial traits and class features that act through the
# damage pipeline's hooks (EventBus.damage_incoming, dropping_to_zero,
# attack_resolved; see CombatManager), and what each character has used of
# them since its last long rest.
#
# A feature listens to a hook and changes the event when its rule applies.
# The first one: Relentless Endurance, the half-orc's refusal to fall.
extends Node

# Half-orc: once between long rests, damage that would leave the character on
# 0 hit points leaves it on 1 instead
const RELENTLESS_ENDURANCE: String = "relentless_endurance"
const RELENTLESS_ENDURANCE_NAME: String = "Relentless Endurance"

# CharacterStats -> {feature id: true}: used, and not back until a long rest
var _used: Dictionary = {}

func _ready():
	EventBus.dropping_to_zero.connect(_on_dropping_to_zero)
	EventBus.rest_taken.connect(_on_rest_taken)
	print("FeatureManager initialized")

func reset():
	"""Back to a fresh game: nobody has used anything.
	Called by GameManager.reset_game_state()."""
	_used.clear()

# === WHO HAS WHAT ===

func has_feature(stats, feature_id: String) -> bool:
	"""True when the character has a racial trait or feature: listed on the
	character itself, or on its race"""
	if stats == null or not (stats is CharacterStats):
		return false
	if stats.racial_traits.has(feature_id):
		return true
	var race_data = RaceDatabase.get_race_data(stats.race_id) if stats.race_id != "" else null
	return race_data != null and race_data.has_trait(feature_id)

func is_used(stats, feature_id: String) -> bool:
	"""True when the character has used a once-a-rest feature since its last long rest"""
	return _used.has(stats) and _used[stats].has(feature_id)

func is_available(stats, feature_id: String) -> bool:
	"""True when the character has the feature and has not used it up"""
	return has_feature(stats, feature_id) and not is_used(stats, feature_id)

func _mark_used(stats, feature_id: String):
	if not _used.has(stats):
		_used[stats] = {}
	_used[stats][feature_id] = true

# === THE HOOKS ===

func _on_dropping_to_zero(event: Dictionary):
	"""Relentless Endurance: the target stays on 1 hit point, once between long rests"""
	if event.get("prevented", false):
		return
	var target = event.get("target")
	if not is_instance_valid(target) or not (target is Combatant) or target.stats == null:
		return
	if not is_available(target.stats, RELENTLESS_ENDURANCE):
		return
	_mark_used(target.stats, RELENTLESS_ENDURANCE)
	event["prevented"] = true
	event["hp_left"] = 1
	event["prevented_by"] = RELENTLESS_ENDURANCE_NAME
	EventBus.ui_notification.emit("%s: %s stays on 1 hit point." % [RELENTLESS_ENDURANCE_NAME, target.get_display_name()], "warning")

func _on_rest_taken(rest_type: String):
	"""A long rest gives every once-a-rest feature back"""
	if rest_type == "long":
		_used.clear()

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""What has been used since the last long rest, by character uid (primitives only)"""
	var used: Dictionary = {}
	for stats in _used:
		if stats is CharacterStats and stats.character_uid != "":
			used[stats.character_uid] = _used[stats].keys()
	return {"used": used}

func from_dict(data: Dictionary):
	"""Restore what has been used. A uid that names no live character is skipped."""
	_used.clear()
	var used: Dictionary = data.get("used", {}) if data.get("used") is Dictionary else {}
	for uid in used:
		var stats = _resolve_stats_by_uid(str(uid))
		if stats == null:
			continue
		for feature_id in used[uid]:
			_mark_used(stats, str(feature_id))

func _resolve_stats_by_uid(uid: String):
	"""The live CharacterStats a saved uid belongs to; null when there is none"""
	var player = GameManager.player
	if uid == "player" and player != null and is_instance_valid(player) and player.get("stats") != null:
		return player.stats
	return null
