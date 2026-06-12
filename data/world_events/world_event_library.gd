# world_event_library.gd
# Static registry of random world events and crisis definitions (pure data, no state).
# WorldEventManager loads this once in _ready(). Owned by A6 (World & Story).
#
# Event schema per docs/ARCHITECTURE_CONTRACTS.md section 3:
#   {event_id, display_name, description, weight, effects}
# The `effects` Dictionary is interpreted by WorldEventManager._apply_event_effects():
#   gold: int                              -> InventoryManager.add_gold
#   items: [{item_id, count}]              -> ItemDatabase.create_item_instance + add_item
#   heal_full: bool                        -> fully heal the player
#   status_effect: {effect_id, duration}   -> StatusEffectManager.apply_effect on the player
#   reputation: {faction_id, delta}        -> FactionManager.modify_reputation
#                                             (faction_id "random" picks a random faction)
#   notify_type: String                    -> notification color ("info"/"warning"/"success")
#
# Crisis schema: {crisis_id, display_name, phases: [{phase: int, name, description}]}
extends RefCounted


static func get_event_definitions() -> Dictionary:
	"""Return {event_id: event definition Dictionary} for all random world events."""
	var defs: Dictionary = {}

	defs["merchant_caravan"] = {
		"event_id": "merchant_caravan",
		"display_name": "Merchant Caravan",
		"description": "A guild caravan rests at the roadside. The master presses supplies and a few coins on you for the company on a dark road.",
		"weight": 20,
		"effects": {
			"gold": 15,
			"items": [{"item_id": "potion_healing_minor", "count": 1}],
			"notify_type": "success",
		},
	}

	defs["wandering_healer"] = {
		"event_id": "wandering_healer",
		"display_name": "Wandering Healer",
		"description": "A quiet pilgrim of the Dawn lays hands on your wounds and walks on without a word. You are fully healed.",
		"weight": 12,
		"effects": {
			"heal_full": true,
			"notify_type": "success",
		},
	}

	defs["ambush"] = {
		"event_id": "ambush",
		"display_name": "Ambush!",
		"description": "Figures burst from cover ahead — steel glints between the trees!",
		"weight": 18,
		"effects": {
			"notify_type": "warning",
			# Intentionally no mechanical effect: the integration layer may spawn
			# enemies near the player when this event id is returned.
		},
	}

	defs["treasure_cache"] = {
		"event_id": "treasure_cache",
		"display_name": "Treasure Cache",
		"description": "Beneath a toppled waystone you find a forgotten strongbox: coin and goods, free for the prying.",
		"weight": 14,
		"effects": {
			"gold": 25,
			"items": [
				{"item_id": "material_iron", "count": 2},
				{"item_id": "potion_healing", "count": 1},
			],
			"notify_type": "success",
		},
	}

	defs["shrine_blessing"] = {
		"event_id": "shrine_blessing",
		"display_name": "Forest Shrine",
		"description": "An old shrine hums with quiet warmth. You leave it feeling blessed.",
		"weight": 10,
		"effects": {
			"status_effect": {"effect_id": "blessed", "duration": 10},
			"notify_type": "success",
		},
	}

	defs["lost_traveler"] = {
		"event_id": "lost_traveler",
		"display_name": "Lost Traveler",
		"description": "You set a frightened traveler back on the road home. Word of the kindness travels further than they do.",
		"weight": 16,
		"effects": {
			"reputation": {"faction_id": "random", "delta": 3},
			"notify_type": "info",
		},
	}

	return defs


static func get_crisis_definitions() -> Dictionary:
	"""Return {crisis_id: crisis definition Dictionary}."""
	var defs: Dictionary = {}

	defs["lich_king_rises"] = {
		"crisis_id": "lich_king_rises",
		"display_name": "The Lich King Rises",
		"phases": [
			{
				"phase": 1,
				"name": "Whispers",
				"description": "Rumors creep along the border roads: graves lie open and the dead do not rest.",
			},
			{
				"phase": 2,
				"name": "The Risen Dead",
				"description": "Skeletons walk the barrowfields in ranks. The Order of the Dawn sounds the call to arms.",
			},
			{
				"phase": 3,
				"name": "The Herald",
				"description": "A robed herald of the Lich King gathers the dead beneath a black banner.",
			},
			{
				"phase": 4,
				"name": "The Lich King",
				"description": "The Lich King rises from the Hollow Throne. The Borderlands stand in his shadow.",
			},
		],
	}

	return defs
