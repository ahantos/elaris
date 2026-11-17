extends RefCounted
# tools/content_validator.gd - finds content that points at ids which do not exist.
#
# Content lives in code registries that refer to each other by string id. Nothing
# checks those strings until the moment they are used, so a typo or a missing
# definition stays silent until a player reaches it. This walks every registry
# and returns one plain sentence per dangling reference.
#
# Called by tools/smoke_test.gd. Managers are fetched from the tree so the file
# also loads when started from a --script run (see the note in smoke_test.gd).

const STATIONS: Array = ["forge", "alchemy_table", "enchanting_table", "cooking_fire"]

# Classes the design plans but the game does not have yet. Spells may list them.
const FUTURE_CLASS_IDS: Array = ["ranger", "paladin", "warlock", "bard"]

static func find_issues(root: Node) -> Array:
	var issues: Array = []
	var items = root.get_node("ItemDatabase")
	var recipes = root.get_node("RecipeDatabase")
	var loot = root.get_node("LootManager")
	var quests = root.get_node("QuestManager")
	var dialogues = root.get_node("DialogueManager")
	var factions = root.get_node("FactionManager")
	var zones = root.get_node("ZoneManager")
	var companions = root.get_node("CompanionManager")
	var spells = root.get_node("SpellDatabase")
	var effects = root.get_node("StatusEffectManager")
	var events = root.get_node("WorldEventManager")
	var classes = root.get_node("ClassDatabase")
	var races = root.get_node("RaceDatabase")
	var world = root.get_node_or_null("World")

	var enemy_types: Array = ["any"]
	if world != null:
		enemy_types.append_array(world.ENEMY_TYPE_DEFS.keys())
	var biomes: Array = RoomLibrary.get_available_biomes()

	# --- recipes ---
	for recipe in recipes.get_all_recipes():
		var rid := str(recipe.get("recipe_id", "?"))
		if not str(recipe.get("station", "")) in STATIONS:
			issues.append("recipe %s: unknown station '%s'" % [rid, str(recipe.get("station", ""))])
		for input in recipe.get("inputs", []):
			_check_item(issues, "recipe %s: input item" % rid, items, str(input.get("item_id", "")))
		if not recipe.get("is_enchant", false):
			_check_item(issues, "recipe %s: output item" % rid, items, str(recipe.get("output_item_id", "")))

	# --- loot tables ---
	for table_id in loot.loot_tables:
		for entry in loot.loot_tables[table_id].get("entries", []):
			if entry.has("item_id"):
				_check_item(issues, "loot table %s: item" % table_id, items, str(entry.item_id))
	for category in ["weapon", "armor", "material", "consumable"]:
		for item in items.get_loot_candidates(category):
			if item.material != null and not item.material.is_obtainable():
				issues.append("loot category %s: item '%s' is made of %s, which cannot be obtained yet" % [
					category, item.item_id, item.material.material_id])

	# --- class starting kits ---
	for class_id in classes.get_all_class_ids():
		var class_data = classes.get_class_data(class_id)
		for item_id in class_data.starting_equipment_list:
			_check_item(issues, "class %s: starting item" % class_id, items, str(item_id))

	# --- quests ---
	for quest_id in quests.quest_definitions:
		var quest: Dictionary = quests.quest_definitions[quest_id]
		for objective in quest.get("objectives", []):
			var kind := str(objective.get("type", ""))
			var target := str(objective.get("target_id", ""))
			match kind:
				"kill":
					if not target in enemy_types:
						issues.append("quest %s: kill target '%s' is not a spawnable enemy type" % [quest_id, target])
				"talk":
					if not dialogues.dialogues.has(target):
						issues.append("quest %s: talk target '%s' has no dialogue" % [quest_id, target])
				"collect":
					_check_item(issues, "quest %s: collect item" % quest_id, items, target)
				"reach":
					if not zones.zones.has(target):
						issues.append("quest %s: reach target '%s' is not a zone" % [quest_id, target])
				_:
					issues.append("quest %s: unknown objective type '%s'" % [quest_id, kind])
		var rewards: Dictionary = quest.get("rewards", {})
		for entry in rewards.get("items", []):
			_check_item(issues, "quest %s: reward item" % quest_id, items, str(entry.get("item_id", "")))
		for faction_id in rewards.get("reputation", {}):
			if not factions.factions.has(faction_id):
				issues.append("quest %s: reward faction '%s' does not exist" % [quest_id, str(faction_id)])
		var next_id := str(quest.get("next_quest_id", ""))
		if next_id != "" and not quests.quest_definitions.has(next_id):
			issues.append("quest %s: next quest '%s' does not exist" % [quest_id, next_id])
		var quest_faction := str(quest.get("faction_id", ""))
		if quest_faction != "" and not factions.factions.has(quest_faction):
			issues.append("quest %s: faction '%s' does not exist" % [quest_id, quest_faction])

	# --- dialogues ---
	for dialogue_id in dialogues.dialogues:
		var dialogue: Dictionary = dialogues.dialogues[dialogue_id]
		var nodes: Dictionary = dialogue.get("nodes", {})
		if not nodes.has(str(dialogue.get("start_node", "root"))):
			issues.append("dialogue %s: start node '%s' is missing" % [dialogue_id, str(dialogue.get("start_node", "root"))])
		for node_id in nodes:
			for choice in nodes[node_id].get("choices", []):
				var targets: Array = [str(choice.get("next", ""))]
				if choice.has("skill_check"):
					targets.append(str(choice.skill_check.get("success_next", "")))
					targets.append(str(choice.skill_check.get("failure_next", "")))
				for target_node in targets:
					if target_node != "" and not nodes.has(target_node):
						issues.append("dialogue %s/%s: choice leads to missing node '%s'" % [dialogue_id, node_id, target_node])
				if choice.has("condition"):
					_check_reference(issues, "dialogue %s/%s condition" % [dialogue_id, node_id], choice.condition,
						items, quests, factions, companions)
				for effect in choice.get("effects", []):
					_check_reference(issues, "dialogue %s/%s effect" % [dialogue_id, node_id], effect,
						items, quests, factions, companions)

	# --- companions ---
	for companion_id in companions.companion_definitions:
		var definition: Dictionary = companions.companion_definitions[companion_id]
		if classes.get_class_data(str(definition.get("class_id", ""))) == null:
			issues.append("companion %s: class '%s' does not exist" % [companion_id, str(definition.get("class_id", ""))])
		if races.get_race_data(str(definition.get("race_id", ""))) == null:
			issues.append("companion %s: race '%s' does not exist" % [companion_id, str(definition.get("race_id", ""))])
		var recruit_zone := str(definition.get("recruit_zone", ""))
		if recruit_zone != "" and not zones.zones.has(recruit_zone):
			issues.append("companion %s: recruit zone '%s' does not exist" % [companion_id, recruit_zone])
		var recruit_dialogue := str(definition.get("recruit_dialogue_id", ""))
		if recruit_dialogue != "" and not dialogues.dialogues.has(recruit_dialogue):
			issues.append("companion %s: recruit dialogue '%s' is not defined" % [companion_id, recruit_dialogue])
		for list_key in ["gift_loved", "gift_liked", "gift_disliked"]:
			for token in definition.get(list_key, []):
				var gift := str(token)
				if gift.begins_with("type:") or gift.begins_with("material_"):
					continue  # category tokens / prefixes, not single item ids
				_check_item(issues, "companion %s: %s item" % [companion_id, list_key], items, gift)

	# --- zones ---
	for zone_id in zones.zones:
		var biome := str(zones.zones[zone_id].get("biome", ""))
		if not biome in biomes:
			issues.append("zone %s: biome '%s' has no room templates" % [zone_id, biome])

	# --- spells ---
	var effect_ids: Array = effects.get_all_effect_ids()
	var class_ids: Array = classes.get_all_class_ids()
	for spell in spells.get_all_spells():
		var spell_id := str(spell.get("spell_id", "?"))
		var applied: Dictionary = spell.get("applies_effect", {})
		if not applied.is_empty() and not str(applied.get("effect_id", "")) in effect_ids:
			issues.append("spell %s: applies unknown effect '%s'" % [spell_id, str(applied.get("effect_id", ""))])
		for class_id in spell.get("classes", []):
			if not class_id in class_ids and not class_id in FUTURE_CLASS_IDS:
				issues.append("spell %s: unknown class '%s'" % [spell_id, str(class_id)])

	# --- world events ---
	for event_id in events.random_events:
		var event_effects: Dictionary = events.random_events[event_id].get("effects", {})
		for entry in event_effects.get("items", []):
			_check_item(issues, "world event %s: item" % event_id, items, str(entry.get("item_id", "")))
		var status: Dictionary = event_effects.get("status_effect", {})
		if not status.is_empty() and not str(status.get("effect_id", "")) in effect_ids:
			issues.append("world event %s: unknown status effect '%s'" % [event_id, str(status.get("effect_id", ""))])

	issues.sort()
	return issues

static func _check_reference(issues: Array, where: String, entry: Dictionary, items, quests, factions, companions):
	"""Shared id checks for dialogue conditions and effects."""
	if entry.has("quest_id") and not quests.quest_definitions.has(str(entry.quest_id)):
		issues.append("%s: quest '%s' does not exist" % [where, str(entry.quest_id)])
	if entry.has("item_id"):
		_check_item(issues, "%s: item" % where, items, str(entry.item_id))
	if entry.has("faction_id") and str(entry.faction_id) != "random" and not factions.factions.has(str(entry.faction_id)):
		issues.append("%s: faction '%s' does not exist" % [where, str(entry.faction_id)])
	if entry.has("companion_id") and not companions.companion_definitions.has(str(entry.companion_id)):
		issues.append("%s: companion '%s' does not exist" % [where, str(entry.companion_id)])

static func _check_item(issues: Array, where: String, items, item_id: String):
	"""An item id content refers to must name an item, by the id the database
	knows it by (not one written with a renamed material: comparisons by id
	would never match), and the item must be made of a material that can be
	obtained."""
	var item = items.get_item(item_id)
	if item == null:
		issues.append("%s '%s' does not exist" % [where, item_id])
		return
	if item.item_id != item_id:
		issues.append("%s '%s' is a retired id: write '%s'" % [where, item_id, item.item_id])
	if item.material != null and not item.material.is_obtainable():
		issues.append("%s '%s' is made of %s, which cannot be obtained yet" % [where, item_id, item.material.material_id])
