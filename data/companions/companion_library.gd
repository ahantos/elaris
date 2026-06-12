# companion_library.gd
# Companion definition registry.  Loaded at runtime by CompanionManager.
# Returns a Dictionary of companion_id -> companion definition matching the
# schema in ARCHITECTURE_CONTRACTS.md §3 (Companion).
# DO NOT add class_name — loaded via ResourceLoader by CompanionManager.
extends RefCounted

"""
Companion schema:
{
	companion_id, display_name, class_id, race_id,
	personality, backstory,
	recruit_zone, recruit_dialogue_id,
	romanceable: bool,
	gift_loved: [item_id ...],
	gift_liked: [item_id or prefix or category token ...],
	gift_disliked: [item_id or prefix or category token ...],
	base_stats: {str, dex, con, int, wis, cha}
}
"""

# Gift matching tokens used in liked/disliked lists (CompanionManager resolves these):
#   "material_iron"   — any item whose item_id starts with "material_iron"
#   "material_silk"   — any item whose item_id starts with "material_silk"
#   "type:weapon"     — any item whose item_type == ItemData.ItemType.WEAPON   (enum int 0)
#   "type:armor"      — item_type ARMOR   (1)
#   "type:consumable" — item_type CONSUMABLE (2)
#   "type:scroll"     — item whose item_id starts with "scroll_"
#   "type:misc"       — item_type MISC (4)
#   "type:cloth"      — item_id contains cloth keywords (hood/robe/wraps/pants/slippers)


static func get_all() -> Dictionary:
	"""Return the full companion definition registry (id → dict)."""
	var companions: Dictionary = {}

	# ------------------------------------------------------------------ #
	#  KAELEN — Human Fighter                                              #
	# ------------------------------------------------------------------ #
	companions["kaelen"] = {
		"companion_id":       "kaelen",
		"display_name":       "Kaelen",
		"class_id":           "fighter",
		"race_id":            "human",
		"personality":        "Gruff and taciturn, Kaelen speaks only when necessary — usually to point out danger or give blunt tactical advice.  Beneath the weathered armour lives a man who has seen too many friends buried, and quietly refuses to let it happen again.",
		"backstory":          "A veteran of three wars across the Borderlands, Kaelen left imperial service after his unit was sacrificed as a rearguard to cover a general's retreat.  He drifted south, selling his sword where honour seemed to exist, until rumours of the dungeon beneath zone_1 put coin in his palm and a purpose back in his chest.",
		"recruit_zone":       "zone_1",
		"recruit_dialogue_id":"recruit_kaelen",
		"romanceable":        true,
		"gift_loved": [
			"iron_longsword",
			"steel_longsword",
		],
		"gift_liked": [
			"material_iron",   # any material_iron* item
			"type:weapon",     # any weapon
		],
		"gift_disliked": [
			"type:cloth",      # cloth armour / cloth items
		],
		"base_stats": {
			"str": 16, "dex": 12, "con": 14,
			"int": 8,  "wis": 10, "cha": 10
		},
	}

	# ------------------------------------------------------------------ #
	#  LYRA — Elf Wizard                                                   #
	# ------------------------------------------------------------------ #
	companions["lyra"] = {
		"companion_id":       "lyra",
		"display_name":       "Lyra",
		"class_id":           "wizard",
		"race_id":            "elf",
		"personality":        "Lyra approaches every dungeon like a library she hasn't catalogued yet.  Endlessly curious, gently sarcastic, and prone to stopping mid-combat to sketch a rune she's spotted — she is also alarmingly accurate when it counts.",
		"backstory":          "Expelled from the Arcanium for 'unsanctioned temporal experiments', Lyra maps dangerous ruins in exchange for first access to any texts found inside.  Her notebooks contain three languages humans haven't invented yet.  She doesn't explain how.",
		"recruit_zone":       "zone_1",
		"recruit_dialogue_id":"recruit_lyra",
		"romanceable":        true,
		"gift_loved": [
			"spellbook",
			"scroll_fireball",
			"scroll_lightning_bolt",
			"scroll_magic_missile",
		],
		"gift_liked": [
			"type:scroll",       # any scroll_* item
			"material_silk",     # material_silk* items
			"type:consumable",   # potions, etc.
		],
		"gift_disliked": [
			"type:weapon",       # weapons (she finds them crude)
		],
		"base_stats": {
			"str": 8,  "dex": 14, "con": 10,
			"int": 17, "wis": 12, "cha": 13
		},
	}

	# ------------------------------------------------------------------ #
	#  BROM — Dwarf Cleric                                                 #
	# ------------------------------------------------------------------ #
	companions["brom"] = {
		"companion_id":       "brom",
		"display_name":       "Brom",
		"class_id":           "cleric",
		"race_id":            "dwarf",
		"personality":        "Brom laughs first, patches wounds second, and asks the gods for forgiveness third.  He is constitutionally incapable of meeting a stranger without offering them a meal, and constitutionally incapable of leaving a fight without finishing it.",
		"backstory":          "Brom served as a battlefield healer for the Gravewardens until a lich's curse collapsed his entire unit's fortification.  He survived by hiding in a beer barrel for six days.  He considers this a miracle and a personal low point in roughly equal measure, and has been making amends by hitting undead very hard ever since.",
		"recruit_zone":       "zone_1",
		"recruit_dialogue_id":"recruit_brom",
		"romanceable":        false,
		"gift_loved": [
			"cooked_meat",
			"bread",
			"warhammer",
			"iron_warhammer",
			"steel_warhammer",
		],
		"gift_liked": [
			"type:consumable",   # food & potions
		],
		"gift_disliked": [
			"type:scroll",       # "Books don't stop bleeding, lad."
		],
		"base_stats": {
			"str": 14, "dex": 8,  "con": 16,
			"int": 10, "wis": 15, "cha": 12
		},
	}

	# ------------------------------------------------------------------ #
	#  WHISPER — Halfling Rogue                                            #
	# ------------------------------------------------------------------ #
	companions["whisper"] = {
		"companion_id":       "whisper",
		"display_name":       "Whisper",
		"class_id":           "rogue",
		"race_id":            "halfling",
		"personality":        "Whisper has an opinion on everything and shares it whether requested or not — usually in a tone that suggests she's already three steps ahead of everyone else and is mildly disappointed by this.  She is rarely wrong, which she finds almost as exhausting as everyone else does.",
		"backstory":          "Whisper built a lucrative courier network inside the Borderlands underworld before a client decided dead couriers don't talk.  She dismantled his operation in a single night, donated his treasury to a halfling orphanage, and has been scouting dungeons 'professionally' ever since — mostly because it's the only job where moral ambiguity is in the contract.",
		"recruit_zone":       "zone_1",
		"recruit_dialogue_id":"recruit_whisper",
		"romanceable":        false,
		"gift_loved": [
			"dagger",
			"iron_dagger",
			"steel_dagger",
			"thieves_tools",
			"trinket_lucky_coin",
		],
		"gift_liked": [
			"type:misc",         # trinkets, tools
		],
		"gift_disliked": [
			"type:armor",        # "This slows me down."
		],
		"base_stats": {
			"str": 8,  "dex": 17, "con": 10,
			"int": 13, "wis": 12, "cha": 14
		},
	}

	return companions
