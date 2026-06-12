# zone_1_quests.gd
# Static registry of every hand-authored Zone 1 quest (pure data, no state).
# QuestManager loads this once in _ready(). Owned by A6 (World & Story).
# Schema per docs/ARCHITECTURE_CONTRACTS.md section 3:
#   {quest_id, title, description, quest_type: "main"|"side"|"faction"|"procedural",
#    giver_npc_id,
#    objectives: [{objective_id, description, type: "kill"|"collect"|"reach"|"talk",
#                  target_id, required_count}],
#    rewards: {xp, gold, items: [{item_id, quality, magic, count}],
#              reputation: {faction_id: delta}},
#    next_quest_id, faction_id}
#
# Objective auto-advance sources (wired in QuestManager):
#   kill    <- EventBus.enemy_died        (target_id matches enemy.enemy_type, or "any")
#   collect <- EventBus.item_picked_up    (target_id matches item_data.item_id)
#   talk    <- EventBus.dialogue_ended    (target_id matches dialogue_id or npc_id)
#   reach   <- EventBus.zone_changed      (target_id matches the new zone_id)
extends RefCounted


static func get_definitions() -> Dictionary:
	"""Return {quest_id: quest definition Dictionary} for all Zone 1 quests."""
	var defs: Dictionary = {}

	# =========================================================================
	# MAIN CHAIN — Strange Tidings -> Whispers in the Barrows -> The Herald
	# =========================================================================

	defs["mq_01_strange_tidings"] = {
		"quest_id": "mq_01_strange_tidings",
		"title": "Strange Tidings",
		"description": "Reeve Marta of Brackenford wants the walking dead on the barrowfields put down — and Elder Senna of the Gravewardens in Mournstead warned of what stirs.",
		"quest_type": "main",
		"giver_npc_id": "reeve_marta",
		"objectives": [
			{
				"objective_id": "obj_kill_risen",
				"description": "Destroy risen skeletons on the barrowfields",
				"type": "kill",
				"target_id": "skeleton",
				"required_count": 3,
			},
			{
				"objective_id": "obj_warn_senna",
				"description": "Speak with Elder Senna in Mournstead",
				"type": "talk",
				"target_id": "elder_senna",
				"required_count": 1,
			},
		],
		"rewards": {
			"xp": 100,
			"gold": 25,
			"items": [],
			"reputation": {"gravewardens": 5},
		},
		"next_quest_id": "mq_02_whispers_in_the_barrows",
		"faction_id": "",
	}

	defs["mq_02_whispers_in_the_barrows"] = {
		"quest_id": "mq_02_whispers_in_the_barrows",
		"title": "Whispers in the Barrows",
		"description": "Elder Senna fears an old power stirs beneath the great barrow. Thin the ranks of the risen dead, and find the hooded stranger who has been watching the graves.",
		"quest_type": "main",
		"giver_npc_id": "elder_senna",
		"objectives": [
			{
				"objective_id": "obj_cull_dead",
				"description": "Cull the risen dead near the great barrow",
				"type": "kill",
				"target_id": "skeleton",
				"required_count": 5,
			},
			{
				"objective_id": "obj_find_stranger",
				"description": "Find and question the hooded stranger",
				"type": "talk",
				"target_id": "mysterious_stranger",
				"required_count": 1,
			},
		],
		"rewards": {
			"xp": 250,
			"gold": 50,
			"items": [{"item_id": "potion_healing", "quality": 0, "magic": 0, "count": 2}],
			"reputation": {"gravewardens": 10, "order_of_dawn": 5},
		},
		"next_quest_id": "mq_03_the_herald",
		"faction_id": "",
	}

	defs["mq_03_the_herald"] = {
		"quest_id": "mq_03_the_herald",
		"title": "The Herald of the Lich",
		"description": "The stranger named the thing raising the dead: a Herald, sent ahead of the old Lich King. Find it among the barrows and destroy it before its work is done.",
		"quest_type": "main",
		"giver_npc_id": "mysterious_stranger",
		"objectives": [
			{
				"objective_id": "obj_slay_herald",
				"description": "Slay the Herald of the Lich King",
				"type": "kill",
				"target_id": "boss",
				"required_count": 1,
			},
		],
		"rewards": {
			"xp": 500,
			"gold": 100,
			"items": [{"item_id": "iron_longsword", "quality": 1, "magic": 1, "count": 1}],
			"reputation": {"order_of_dawn": 10, "gravewardens": 10},
		},
		"next_quest_id": "",
		"faction_id": "",
	}

	# =========================================================================
	# SIDE QUESTS
	# =========================================================================

	defs["sq_pelts_for_winter"] = {
		"quest_id": "sq_pelts_for_winter",
		"title": "Pelts for Winter",
		"description": "Lyssa the tanner in Brackenford pays good coin for wolf pelts before the cold sets in. The wolves, regrettably, are still wearing them.",
		"quest_type": "side",
		"giver_npc_id": "trader_lyssa",
		"objectives": [
			{
				"objective_id": "obj_hunt_wolves",
				"description": "Cull wolves in the border forest",
				"type": "kill",
				"target_id": "wolf",
				"required_count": 4,
			},
			{
				"objective_id": "obj_gather_hides",
				"description": "Gather hides for the tannery",
				"type": "collect",
				"target_id": "material_hide",
				"required_count": 3,
			},
		],
		"rewards": {
			"xp": 80,
			"gold": 40,
			"items": [],
			"reputation": {"merchants_guild": 5},
		},
		"next_quest_id": "",
		"faction_id": "",
	}

	defs["sq_missing_shipment"] = {
		"quest_id": "sq_missing_shipment",
		"title": "The Missing Shipment",
		"description": "A guild wagon of iron ingots never reached Brackenford. Guildmaster Oswin wants the bandits responsible dead and the iron back in guild hands.",
		"quest_type": "side",
		"giver_npc_id": "guildmaster_oswin",
		"objectives": [
			{
				"objective_id": "obj_punish_bandits",
				"description": "Hunt down the bandits who took the wagon",
				"type": "kill",
				"target_id": "bandit",
				"required_count": 3,
			},
			{
				"objective_id": "obj_recover_iron",
				"description": "Recover the stolen iron ingots",
				"type": "collect",
				"target_id": "material_iron",
				"required_count": 2,
			},
		],
		"rewards": {
			"xp": 100,
			"gold": 60,
			"items": [{"item_id": "potion_healing", "quality": 0, "magic": 0, "count": 1}],
			"reputation": {"merchants_guild": 10},
		},
		"next_quest_id": "",
		"faction_id": "",
	}

	# =========================================================================
	# FACTION QUESTS — one per Zone 1 faction
	# =========================================================================

	defs["fq_merchants_toll_roads"] = {
		"quest_id": "fq_merchants_toll_roads",
		"title": "Clearing the Toll Roads",
		"description": "Bandits levy their own 'tolls' on the south road. The Merchants' Guild would like them removed from the road, and from the world.",
		"quest_type": "faction",
		"giver_npc_id": "guildmaster_oswin",
		"objectives": [
			{
				"objective_id": "obj_clear_roads",
				"description": "Remove the bandit toll-takers",
				"type": "kill",
				"target_id": "bandit",
				"required_count": 5,
			},
		],
		"rewards": {
			"xp": 120,
			"gold": 75,
			"items": [],
			"reputation": {"merchants_guild": 15},
		},
		"next_quest_id": "",
		"faction_id": "merchants_guild",
	}

	defs["fq_dawn_cleansing_flame"] = {
		"quest_id": "fq_dawn_cleansing_flame",
		"title": "The Cleansing Flame",
		"description": "The barrows vomit up bones faster than the Order's lances can burn them. Captain Aldric of Dawnwatch asks you to hack six of the risen back to stillness.",
		"quest_type": "faction",
		"giver_npc_id": "captain_aldric",
		"objectives": [
			{
				"objective_id": "obj_burn_dead",
				"description": "Destroy risen skeletons in the Order's name",
				"type": "kill",
				"target_id": "skeleton",
				"required_count": 6,
			},
		],
		"rewards": {
			"xp": 120,
			"gold": 30,
			"items": [{"item_id": "potion_healing", "quality": 0, "magic": 0, "count": 2}],
			"reputation": {"order_of_dawn": 15},
		},
		"next_quest_id": "",
		"faction_id": "order_of_dawn",
	}

	defs["fq_wardens_quiet_earth"] = {
		"quest_id": "fq_wardens_quiet_earth",
		"title": "Rites of the Quiet Earth",
		"description": "Goblins root through the old barrows for trinkets while the offering stones stand bare. Elder Senna asks for rite-loaves of bread for the stones, and for the grave-robbers stilled.",
		"quest_type": "faction",
		"giver_npc_id": "elder_senna",
		"objectives": [
			{
				"objective_id": "obj_gather_offerings",
				"description": "Gather rite-loaves of bread for the offering stones",
				"type": "collect",
				"target_id": "bread",
				"required_count": 2,
			},
			{
				"objective_id": "obj_still_robbers",
				"description": "Still the goblin grave-robbers",
				"type": "kill",
				"target_id": "goblin",
				"required_count": 3,
			},
		],
		"rewards": {
			"xp": 120,
			"gold": 30,
			"items": [{"item_id": "antidote", "quality": 0, "magic": 0, "count": 1}],
			"reputation": {"gravewardens": 15},
		},
		"next_quest_id": "",
		"faction_id": "gravewardens",
	}

	return defs
