# event_bus.gd
# AutoLoad singleton - central event hub for decoupled communication
extends Node

# === COMBAT EVENTS ===
signal combat_started(enemies: Array)
signal combat_ended(victory: bool)
signal turn_started(character)
signal turn_ended(character)
signal damage_dealt(attacker, target, amount, is_critical)
signal character_died(character)
signal enemy_died(enemy)

# === PLAYER EVENTS ===
signal player_moved(old_pos: Vector2i, new_pos: Vector2i)
signal player_hp_changed(current_hp: int, max_hp: int)
signal player_leveled_up(new_level: int)
signal player_gained_xp(amount: int)

# === ITEM EVENTS ===
signal item_picked_up(item_instance)
signal item_dropped(item_instance)
signal item_equipped(item_instance, slot: String)
signal item_unequipped(item_instance, slot: String)
signal item_durability_changed(item_instance, current: int, max: int)
signal item_broken(item_instance)

# === INVENTORY EVENTS ===
signal inventory_changed()
signal weight_changed(current_weight: float, max_weight: float)
signal equipment_changed(character: CharacterStats)  # NEW - for character screen updates
signal slots_changed(used_slots: int, max_slots: int)  # NEW - for slot-based encumbrance
signal gold_changed(amount: int)  # NEW - for gold updates

# === UI EVENTS ===
signal ui_notification(message: String, type: String)  # type: "info", "warning", "error", "success"
signal tooltip_show(text: String, position: Vector2)
signal tooltip_hide()

# === WORLD EVENTS ===
signal dungeon_generated()
signal dungeon_regenerated()
signal location_discovered(location_name: String)
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

# === FACTION EVENTS ===
signal reputation_changed(faction_id: String, old_value: int, new_value: int)
signal faction_status_changed(faction_id: String, new_status: String)

# === GAME STATE EVENTS ===
signal game_paused()
signal game_unpaused()
signal game_saved(slot: int)
signal game_loaded(slot: int)

# === STATUS EFFECT EVENTS ===
# target is a Node (GridCharacter / Enemy / Companion)
signal status_effect_applied(target, effect_id: String, duration: int)
signal status_effect_removed(target, effect_id: String)
signal status_effect_ticked(target, effect_id: String, amount: int)
signal reaction_triggered(reactor, reaction_id: String, trigger_source)

# === PROGRESSION EVENTS ===
# stats is a CharacterStats
signal character_created(stats)
signal ability_score_increased(stats, stat: String, new_value: int)
signal skill_check_made(stats, skill: String, dc: int, success: bool)

# === MAGIC EVENTS ===
# caster is a Node; stats is a CharacterStats
signal spell_cast(caster, spell_id: String, targets: Array)
signal spell_learned(stats, spell_id: String)
signal spell_slot_used(stats, slot_level: int, remaining: int)
signal spell_slots_restored(stats)
signal concentration_started(caster, spell_id: String)
signal concentration_broken(caster, spell_id: String)

# === LOOT EVENTS ===
signal loot_dropped(source, items: Array)  # items: Array of item instance Dictionaries
signal item_used(item_instance, user)

# === CRAFTING EVENTS ===
signal item_crafted(recipe_id: String, item_instance)
signal recipe_learned(recipe_id: String)
signal material_gathered(material_id: String, count: int)
signal item_repaired(item_instance)
signal item_enchanted(item_instance, enchantment_id: String)

# === DIALOGUE EVENTS ===
signal dialogue_started(npc_id: String, dialogue_id: String)
signal dialogue_ended(npc_id: String, dialogue_id: String)
signal dialogue_choice_made(dialogue_id: String, node_id: String, choice_index: int)

# === QUEST EVENTS (see also WORLD EVENTS above) ===
signal quest_available(quest_id: String)
signal quest_advanced(quest_id: String, objective_id: String, progress: int, required: int)

# === WORLD EVENT / CRISIS / ZONE EVENTS ===
signal random_event_triggered(event_id: String)
signal crisis_phase_changed(crisis_id: String, phase: int)
signal zone_changed(old_zone_id: String, new_zone_id: String)

# === COMPANION EVENTS ===
signal companion_recruited(companion_id: String)
signal companion_dismissed(companion_id: String)
signal relationship_changed(companion_id: String, old_value: int, new_value: int)
signal romance_status_changed(companion_id: String, status: String)

# === REST / TIME EVENTS ===
signal rest_taken(rest_type: String)  # "short" or "long"

# === UI PANEL EVENTS ===
signal ui_panel_opened(panel_id: String)
signal ui_panel_closed(panel_id: String)

# === HELPER FUNCTIONS ===

func notify(message: String, type: String = "info"):
	"""Send a UI notification"""
	ui_notification.emit(message, type)

func notify_info(message: String):
	"""Send info notification (white)"""
	notify(message, "info")

func notify_success(message: String):
	"""Send success notification (green)"""
	notify(message, "success")

func notify_warning(message: String):
	"""Send warning notification (yellow)"""
	notify(message, "warning")

func notify_error(message: String):
	"""Send error notification (red)"""
	notify(message, "error")
