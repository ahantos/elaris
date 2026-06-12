# crafting_manager.gd
# AutoLoad singleton - crafting operations (craft, repair, enchant) against RecipeDatabase,
# consuming/producing items through InventoryManager and ItemDatabase.
# Enchant recipes are SPECIAL: instead of creating a new item they call
# SpellManager.enchant_item(instance, plus_level) on the player's equipped item in the
# recipe's enchant_slot. If SpellManager doesn't have that method yet (stub era), the magic
# modifier is set directly (capped at +3) and item_enchanted is emitted.
# Repair requires 1× material_<item.material.material_id> + tier-scaled gold cost.
extends Node

# Recipes the player has learned (Array of recipe_id Strings)
var known_recipes: Array = []

# Tier -> gold cost multiplier for repair
const REPAIR_GOLD_BY_TIER := {0: 5, 1: 15, 2: 40, 3: 150, 4: 500}

func _ready():
	# Seed auto_known recipes after RecipeDatabase is guaranteed ready.
	# RecipeDatabase is earlier in the autoload order so _ready has already run,
	# but we use call_deferred for safety.
	call_deferred("_seed_auto_known")

func _seed_auto_known():
	"""Learn all auto_known recipes at game start."""
	var seeded: int = 0
	for recipe in RecipeDatabase.get_all_recipes():
		if recipe.get("auto_known", false):
			var rid: String = str(recipe.get("recipe_id", ""))
			if not known_recipes.has(rid):
				known_recipes.append(rid)
				seeded += 1
	print("Crafting: known %d recipes after auto-seed" % known_recipes.size())

# ---------------------------------------------------------------------------
#  RECIPE KNOWLEDGE
# ---------------------------------------------------------------------------

func learn_recipe(recipe_id: String) -> bool:
	"""Teach the player a recipe. Returns false if already known or recipe doesn't exist."""
	if knows_recipe(recipe_id):
		return false
	var recipe: Dictionary = RecipeDatabase.get_recipe(recipe_id)
	if recipe.is_empty():
		push_error("Crafting: learn_recipe — unknown recipe_id '%s'" % recipe_id)
		return false
	known_recipes.append(recipe_id)
	EventBus.recipe_learned.emit(recipe_id)
	print("Crafting: learned recipe '%s'" % recipe_id)
	return true

func knows_recipe(recipe_id: String) -> bool:
	"""Return true if the player knows this recipe."""
	return known_recipes.has(recipe_id)

# ---------------------------------------------------------------------------
#  CRAFTING VALIDATION
# ---------------------------------------------------------------------------

func can_craft(recipe_id: String) -> Dictionary:
	"""Returns {ok: bool, missing: Array of {item_id, needed, have, reason?}}.
	   Checks: recipe known, player level, inputs in inventory, gold.
	   For enchant recipes, also checks that a suitable equipped item exists.
	"""
	var result: Dictionary = {"ok": false, "missing": []}

	if not knows_recipe(recipe_id):
		result.missing.append({"item_id": "", "needed": 0, "have": 0, "reason": "Recipe not learned"})
		return result

	var recipe: Dictionary = RecipeDatabase.get_recipe(recipe_id)
	if recipe.is_empty():
		result.missing.append({"item_id": "", "needed": 0, "have": 0, "reason": "Recipe not found"})
		return result

	# --- player level check ---
	var req_level: int = recipe.get("required_player_level", 1)
	var player_level: int = _get_player_level()
	if player_level < req_level:
		result.missing.append({
			"item_id": "",
			"needed":  req_level,
			"have":    player_level,
			"reason":  "Player level too low (need %d, have %d)" % [req_level, player_level],
		})

	# --- input item checks ---
	for inp in recipe.get("inputs", []):
		var inp_dict: Dictionary = inp as Dictionary
		var item_id: String = str(inp_dict.get("item_id", ""))
		var needed: int     = int(inp_dict.get("count", 0))
		var have: int       = _count_item_in_inventory(item_id)
		if have < needed:
			result.missing.append({"item_id": item_id, "needed": needed, "have": have})

	# --- gold check ---
	var gold_cost: int = recipe.get("gold_cost", 0)
	if gold_cost > 0 and not InventoryManager.has_gold(gold_cost):
		result.missing.append({
			"item_id": "gold",
			"needed":  gold_cost,
			"have":    InventoryManager.gold,
			"reason":  "Not enough gold",
		})

	# --- enchant-specific: need equipped item in the target slot ---
	if recipe.get("is_enchant", false):
		var slot: String = recipe.get("enchant_slot", "main_hand")
		var player: Node = _get_player()
		var equipped: Dictionary = {}
		if player and player.get("stats") and player.stats:
			equipped = InventoryManager.get_equipped_item(player.stats, slot)
		if equipped.is_empty():
			result.missing.append({
				"item_id": "",
				"needed":  1,
				"have":    0,
				"reason":  "No item equipped in '%s' slot to enchant" % slot,
			})
		else:
			# Cap check: already at +3?
			var cur_magic: int = int(equipped.get("magic_modifier", 0))
			var plus_level: int = int(recipe.get("plus_level", 1))
			if cur_magic + plus_level > 3:
				result.missing.append({
					"item_id": "",
					"needed":  1,
					"have":    0,
					"reason":  "Item already at maximum enchantment (+%d); adding +%d would exceed cap of +3" % [cur_magic, plus_level],
				})

	result.ok = result.missing.is_empty()
	return result

# ---------------------------------------------------------------------------
#  CRAFTING EXECUTION
# ---------------------------------------------------------------------------

func craft(recipe_id: String) -> Dictionary:
	"""Craft a recipe: validates, consumes inputs + gold, produces output or enchants item.
	   Returns the crafted item instance on success, or {} on failure.
	   NEVER consumes inputs before full validation (contracts guarantee).
	"""
	var check: Dictionary = can_craft(recipe_id)
	if not check.ok:
		var reasons: Array = []
		for m in check.missing:
			if m.has("reason"):
				reasons.append(m.reason)
			elif m.item_id != "":
				reasons.append("Need %d× %s (have %d)" % [m.needed, m.item_id, m.have])
		var msg: String = "; ".join(reasons) if not reasons.is_empty() else "Cannot craft"
		EventBus.ui_notification.emit(msg, "warning")
		print("Crafting: cannot craft '%s' — %s" % [recipe_id, msg])
		return {}

	var recipe: Dictionary = RecipeDatabase.get_recipe(recipe_id)

	# Handle enchant recipes specially
	if recipe.get("is_enchant", false):
		return _execute_enchant(recipe)

	# --- verify output item exists BEFORE consuming inputs ---
	var output_id: String = recipe.get("output_item_id", "")
	if output_id == "":
		push_error("Crafting: recipe '%s' has no output_item_id" % recipe_id)
		return {}
	var item_data: ItemData = ItemDatabase.get_item(output_id)
	if item_data == null:
		push_error("Crafting: output item '%s' not found in ItemDatabase — A1 catalog gap; aborting without consuming inputs" % output_id)
		return {}

	# --- consume inputs ---
	_consume_inputs(recipe)

	# --- consume gold ---
	var gold_cost: int = recipe.get("gold_cost", 0)
	if gold_cost > 0:
		InventoryManager.remove_gold(gold_cost)

	# --- produce output ---
	var output_count: int = recipe.get("output_count", 1)
	var last_instance: Dictionary = {}
	for _i in range(max(1, output_count)):
		var instance: Dictionary = ItemDatabase.create_item_instance(output_id, ItemDatabase.roll_item_quality(), 0)
		if instance.is_empty():
			push_error("Crafting: create_item_instance failed for '%s'" % output_id)
			continue
		InventoryManager.add_item(instance)
		last_instance = instance

	if last_instance.is_empty():
		push_error("Crafting: production of '%s' yielded no instances" % output_id)
		return {}

	EventBus.item_crafted.emit(recipe_id, last_instance)
	EventBus.ui_notification.emit("Crafted: %s" % recipe.get("display_name", output_id), "success")
	print("Crafting: crafted '%s' → '%s'" % [recipe_id, output_id])
	return last_instance

# ---------------------------------------------------------------------------
#  ENCHANT EXECUTION  (special recipe kind)
# ---------------------------------------------------------------------------

func _execute_enchant(recipe: Dictionary) -> Dictionary:
	"""Execute an enchant recipe: modifies the equipped item in enchant_slot.
	   Calls SpellManager.enchant_item if available; otherwise sets magic_modifier directly.
	   Returns the modified item instance or {} on failure.
	"""
	var slot: String    = str(recipe.get("enchant_slot", "main_hand"))
	var plus_level: int = int(recipe.get("plus_level", 1))
	var recipe_id: String = str(recipe.get("recipe_id", ""))

	var player: Node = _get_player()
	if player == null or not player.get("stats") or player.stats == null:
		push_error("Crafting: enchant — no player stats available")
		return {}

	var equipped: Dictionary = InventoryManager.get_equipped_item(player.stats, slot)
	if equipped.is_empty():
		push_error("Crafting: enchant — nothing equipped in '%s'" % slot)
		return {}

	# Consume inputs + gold AFTER confirming target exists
	_consume_inputs(recipe)
	var gold_cost: int = recipe.get("gold_cost", 0)
	if gold_cost > 0:
		InventoryManager.remove_gold(gold_cost)

	if SpellManager.has_method("enchant_item"):
		SpellManager.enchant_item(equipped, plus_level)
	else:
		# Fallback: set magic_modifier directly, cap at +3
		var cur: int = int(equipped.get("magic_modifier", 0))
		equipped["magic_modifier"] = min(cur + plus_level, 3)
		if equipped.has("item_data") and equipped.item_data != null:
			equipped.item_data.is_magical = true

	var enchantment_id: String = "plus%d" % int(equipped.get("magic_modifier", plus_level))
	EventBus.item_enchanted.emit(equipped, enchantment_id)
	var item_name_str: String = "item"
	if equipped.has("item_data") and equipped.item_data != null:
		item_name_str = equipped.item_data.item_name
	EventBus.ui_notification.emit(
		"Enchanted %s to +%d!" % [item_name_str, int(equipped.get("magic_modifier", plus_level))],
		"success"
	)
	print("Crafting: enchanted item in '%s' slot via recipe '%s'" % [slot, recipe_id])
	return equipped

# ---------------------------------------------------------------------------
#  REPAIR
# ---------------------------------------------------------------------------

func repair_item(item_instance: Dictionary) -> bool:
	"""Repair an item: requires 1× material_<item material> + tier-scaled gold.
	   Restores current_durability to max_durability.
	   Returns true on success.
	"""
	if item_instance.is_empty():
		push_error("Crafting: repair_item — empty instance")
		return false

	var idata = item_instance.get("item_data", null)
	if idata == null:
		push_error("Crafting: repair_item — instance has no item_data")
		return false

	# Already fully repaired?
	var cur_dur: int = item_instance.get("current_durability", 0)
	var max_dur: int = item_instance.get("max_durability", 0)
	if cur_dur >= max_dur:
		EventBus.ui_notification.emit("Item is already in full repair.", "info")
		return false

	# Determine material requirement
	var mat: MaterialData = null
	if idata is Dictionary:
		mat = idata.get("material", null)
	elif idata != null:
		mat = idata.material
	if mat == null:
		push_error("Crafting: repair_item — item has no material; cannot determine repair cost")
		return false

	var mat_item_id: String = "material_%s" % mat.material_id
	var tier_int: int = int(mat.tier)
	var gold_cost: int = REPAIR_GOLD_BY_TIER.get(tier_int, 5)

	# Validate
	if not InventoryManager.has_item(mat_item_id):
		EventBus.ui_notification.emit(
			"Repair requires 1× %s (material_%s)" % [mat.material_name, mat.material_id], "warning"
		)
		return false
	if not InventoryManager.has_gold(gold_cost):
		EventBus.ui_notification.emit(
			"Repair costs %d gold (you have %d)" % [gold_cost, InventoryManager.gold], "warning"
		)
		return false

	# Consume material (find first matching stack and remove one unit)
	var mat_instance: Dictionary = _find_first_item_instance(mat_item_id)
	if mat_instance.is_empty():
		push_error("Crafting: repair_item — could not locate material instance despite has_item=true")
		return false
	InventoryManager.remove_item(mat_instance.instance_id)
	InventoryManager.remove_gold(gold_cost)

	# Restore durability
	item_instance["current_durability"] = max_dur
	EventBus.item_repaired.emit(item_instance)
	EventBus.item_durability_changed.emit(item_instance, max_dur, max_dur)
	EventBus.ui_notification.emit("Item repaired!", "success")
	var repaired_id: String = "?"
	if idata is Resource:
		repaired_id = idata.item_id
	elif idata is Dictionary:
		repaired_id = str(idata.get("item_id", "?"))
	print("Crafting: repaired item '%s' (cost: 1× %s + %d gold)" % [repaired_id, mat_item_id, gold_cost])
	return true

# ---------------------------------------------------------------------------
#  PRIVATE HELPERS
# ---------------------------------------------------------------------------

func _get_player() -> Node:
	"""Safe access to GameManager.player — may be null headless."""
	if Engine.has_singleton("GameManager"):
		return GameManager.player
	return null

func _get_player_level() -> int:
	"""Return player level, defaulting to 1 if unavailable.
	   CharacterStats is a Resource; use 'in' check + direct property access.
	"""
	var player: Node = _get_player()
	if player and player.get("stats") and player.stats:
		if "level" in player.stats:
			return int(player.stats.level)
	return 1

func _count_item_in_inventory(item_id: String) -> int:
	"""Count total units of item_id across all inventory stacks."""
	var total: int = 0
	for inst in InventoryManager.items:
		if inst.has("item_data") and inst.item_data != null:
			var id: String = ""
			if inst.item_data is Dictionary:
				id = inst.item_data.get("item_id", "")
			else:
				id = inst.item_data.item_id
			if id == item_id:
				total += int(inst.get("stack_count", 1))
	return total

func _find_first_item_instance(item_id: String) -> Dictionary:
	"""Return the first inventory instance whose item_data.item_id matches."""
	for inst in InventoryManager.items:
		if inst.has("item_data") and inst.item_data != null:
			var id: String = ""
			if inst.item_data is Dictionary:
				id = inst.item_data.get("item_id", "")
			else:
				id = inst.item_data.item_id
			if id == item_id:
				return inst
	return {}

func _consume_inputs(recipe: Dictionary):
	"""Remove all recipe inputs from inventory (one unit at a time via remove_item)."""
	for inp in recipe.get("inputs", []):
		var inp_dict: Dictionary = inp as Dictionary
		var item_id: String = str(inp_dict.get("item_id", ""))
		var count: int      = int(inp_dict.get("count", 0))
		for _i in range(count):
			var inst: Dictionary = _find_first_item_instance(item_id)
			if inst.is_empty():
				push_error("Crafting: _consume_inputs — ran out of '%s' mid-consume; inventory desync" % item_id)
				break
			InventoryManager.remove_item(inst.instance_id)

# ---------------------------------------------------------------------------
#  DATA EXPORT/IMPORT  (for saving)
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	"""Serialize crafting state for save. Schema: {known_recipes: [String, ...]}"""
	return {"known_recipes": known_recipes.duplicate()}

func from_dict(data: Dictionary):
	"""Restore crafting state from save."""
	known_recipes = data.get("known_recipes", [])
	print("Crafting: loaded %d known recipes from save" % known_recipes.size())
