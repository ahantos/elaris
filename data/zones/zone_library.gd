# zone_library.gd
# Static registry of the 9 world zones (pure data, no state). Owned by A6 (World & Story).
# ZoneManager loads this once in _ready().
# Schema per docs/ARCHITECTURE_CONTRACTS.md section 3:
#   {zone_id, display_name, description, biome, danger_tier: 1-9,
#    cities: [{city_id, name, description}], unlocked: bool}
# zone_1 ("The Borderlands") is fleshed out with 3 cities; zones 2-9 are skeletal
# placeholders whose biomes cycle through the existing dungeon generators
# (house / cave / dungeon / crypt / forest).
extends RefCounted


static func get_definitions() -> Dictionary:
	"""Return {zone_id: zone definition Dictionary} for all 9 zones."""
	var defs: Dictionary = {}

	defs["zone_1"] = {
		"zone_id": "zone_1",
		"display_name": "The Borderlands",
		"description": "Forested marches at the edge of the old kingdom. Palisade towns, barrowfields, and roads that are no longer as safe as the maps claim.",
		"biome": "forest",
		"danger_tier": 1,
		"cities": [
			{
				"city_id": "brackenford",
				"name": "Brackenford",
				"description": "A palisaded market town on the old river crossing; seat of the Merchants' Guild in the Borderlands."
			},
			{
				"city_id": "dawnwatch",
				"name": "Dawnwatch",
				"description": "A fortress-chapel on the ridge where the Order of the Dawn keeps its vigil against the restless dead."
			},
			{
				"city_id": "mournstead",
				"name": "Mournstead",
				"description": "A grey hamlet at the edge of the barrowfields, tended by the Gravewardens and their silent bells."
			},
		],
		"unlocked": true,
	}

	defs["zone_2"] = {
		"zone_id": "zone_2",
		"display_name": "The Desert Wastes",
		"description": "Sun-bleached ruins and buried caravans beyond the southern passes.",
		"biome": "house",
		"danger_tier": 2,
		"cities": [],
		"unlocked": false,
	}

	defs["zone_3"] = {
		"zone_id": "zone_3",
		"display_name": "The Frozen North",
		"description": "Glacier-carved valleys where the wind never sleeps.",
		"biome": "cave",
		"danger_tier": 3,
		"cities": [],
		"unlocked": false,
	}

	defs["zone_4"] = {
		"zone_id": "zone_4",
		"display_name": "The Sunken Marshes",
		"description": "Drowned causeways and fever-lights over black water.",
		"biome": "dungeon",
		"danger_tier": 4,
		"cities": [],
		"unlocked": false,
	}

	defs["zone_5"] = {
		"zone_id": "zone_5",
		"display_name": "The Shattered Peaks",
		"description": "Broken mountains honeycombed with the halls of the dwarven dead.",
		"biome": "crypt",
		"danger_tier": 5,
		"cities": [],
		"unlocked": false,
	}

	defs["zone_6"] = {
		"zone_id": "zone_6",
		"display_name": "The Verdant Deep",
		"description": "A jungle older than any map, green and hungry.",
		"biome": "forest",
		"danger_tier": 6,
		"cities": [],
		"unlocked": false,
	}

	defs["zone_7"] = {
		"zone_id": "zone_7",
		"display_name": "The Ashen Plains",
		"description": "Cinder fields beneath a sky that still remembers fire.",
		"biome": "house",
		"danger_tier": 7,
		"cities": [],
		"unlocked": false,
	}

	defs["zone_8"] = {
		"zone_id": "zone_8",
		"display_name": "The Twilight Moors",
		"description": "Mist-bound fells where day and night blur together.",
		"biome": "cave",
		"danger_tier": 8,
		"cities": [],
		"unlocked": false,
	}

	defs["zone_9"] = {
		"zone_id": "zone_9",
		"display_name": "The Hollow Throne",
		"description": "The dead heart of the old kingdom, where the Lich King waits.",
		"biome": "dungeon",
		"danger_tier": 9,
		"cities": [],
		"unlocked": false,
	}

	return defs
