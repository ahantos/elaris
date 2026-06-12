# character_builder.gd
# Static factory that assembles ready-to-play CharacterStats from class + race definitions.
# Used by character creation UI (player) and CompanionManager (companions).
extends RefCounted
class_name CharacterBuilder

static func build(class_id: String, race_id: String, base_stats: Dictionary, character_name: String = "Hero") -> CharacterStats:
	"""Build a CharacterStats from a class id, race id and base ability scores
	({"str": 15, "dex": 14, ...}). Applies class saving throws / skill picks /
	proficiencies and racial bonuses / speed / traits, then emits
	EventBus.character_created. character_uid defaults to "player" - callers
	building companions must override it afterwards ("companion_<id>")."""
	var stats = CharacterStats.new(base_stats)
	stats.character_uid = "player"
	stats.character_name = character_name
	stats.class_id = class_id
	stats.race_id = race_id

	_apply_class(stats, class_id)
	_apply_race(stats, race_id)

	# Final pass: class hit die + racial CON bonus are both in by now
	stats.recalculate_derived_stats()
	stats.current_hp = stats.max_hp
	stats.experience_to_next_level = CharacterStats.get_xp_for_level(stats.level + 1)

	print("CharacterBuilder: built '", character_name, "' (", class_id, " / ", race_id,
		") - HP ", stats.max_hp, ", AC ", stats.armor_class,
		", skills ", stats.skill_proficiencies)

	EventBus.character_created.emit(stats)
	return stats

static func build_monster(monster_name: String, level: int, base_stats: Dictionary) -> CharacterStats:
	"""Build classless monster stats: d8 hit die, HP scaled deterministically by level.
	Does NOT emit character_created (that signal is for player/companion creation)."""
	var stats = CharacterStats.new(base_stats)
	stats.character_uid = "monster_" + monster_name.to_lower().replace(" ", "_")
	stats.character_name = monster_name
	stats.default_hit_die_sides = 8
	stats.level = clampi(level, 1, CharacterStats.MAX_LEVEL)
	stats.recalculate_derived_stats()
	stats.current_hp = stats.max_hp
	stats.experience_to_next_level = CharacterStats.get_xp_for_level(stats.level + 1)

	print("CharacterBuilder: built monster '", monster_name, "' (level ", stats.level,
		") - HP ", stats.max_hp, ", AC ", stats.armor_class)
	return stats

static func _apply_class(stats: CharacterStats, class_id: String):
	"""Apply class data: saving throw proficiencies, placeholder skill picks
	(first N of the class's choices), weapon/armor/tool proficiencies."""
	if class_id == "":
		return
	var class_data = ClassDatabase.get_class_data(class_id)
	if not class_data:
		push_error("CharacterBuilder: unknown class_id '%s'" % class_id)
		return

	# Saving throw proficiencies
	for save_stat in class_data.saving_throw_proficiencies:
		stats.set_save_proficiency(save_stat, true)

	# Skill proficiencies: placeholder picks = first N choices (UI choice comes later)
	var pick_count = mini(class_data.skill_proficiency_count, class_data.skill_proficiency_choices.size())
	for i in range(pick_count):
		stats.add_skill_proficiency(class_data.skill_proficiency_choices[i])

	# Weapon / armor / tool proficiencies
	for weapon_type in class_data.weapon_proficiencies:
		stats.add_weapon_proficiency(weapon_type)
	for armor_type in class_data.armor_proficiencies:
		stats.add_armor_proficiency(armor_type)
	for tool_id in class_data.tool_proficiencies:
		stats.add_tool_proficiency(tool_id)

static func _apply_race(stats: CharacterStats, race_id: String):
	"""Apply race data: ability bonuses + speed (via RaceData.apply_to_character_stats),
	skill/weapon/tool proficiencies and racial traits."""
	if race_id == "":
		return
	var race_data = RaceDatabase.get_race_data(race_id)
	if not race_data:
		push_error("CharacterBuilder: unknown race_id '%s'" % race_id)
		return

	# Ability score bonuses + movement speed (+ recalculation)
	race_data.apply_to_character_stats(stats)

	# Racial proficiencies
	for skill_id in race_data.skill_proficiencies:
		stats.add_skill_proficiency(skill_id)
	for weapon_type in race_data.weapon_proficiencies:
		stats.add_weapon_proficiency(weapon_type)
	for armor_type in race_data.armor_proficiencies:
		stats.add_armor_proficiency(armor_type)
	for tool_id in race_data.tool_proficiencies:
		stats.add_tool_proficiency(tool_id)

	# Racial traits
	for trait_id in race_data.racial_traits:
		if not stats.racial_traits.has(trait_id):
			stats.racial_traits.append(trait_id)
