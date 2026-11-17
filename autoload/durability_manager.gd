# durability_manager.gd
# AutoLoad singleton - how gear wears, what wear costs, and how it is mended.
# The design is section 8 of the plan ("Durability"); every number it uses is a
# dial in data/durability/durability_dials.gd.
#
# WHAT WEARS
# A weapon, a shield, body armour, a helmet and the pieces of the seven
# secondary slots (shoulder, back, wrist, hands, waist, legs, feet). Neck, rings
# and trinkets do not. Such an item instance carries:
#   notches               what is left; at 0 the piece is broken
#   notches_max           what it can hold now (ageing lowers it, never below 1)
#   notches_max_original  what it could hold when made: the material's count,
#                         plus one for masterforged craftsmanship, plus one for
#                         each plus of magic
#   marks                 steady wear towards the next lost notch
#   age                   rises with every notch repaired
#   debuffs, buffs        ids, see below
#   wear_names            what a notch lost without a debuff is called (flavour)
#   kills, kills_by_type, caster_kills, ever_broken   what the buffs count; only
#                         present once there is something to count
# A broken piece gives no bonus and a broken weapon cannot attack. Nothing is
# ever destroyed by wear.
#
# WHAT A LOST NOTCH COSTS
# Every second lost notch costs 1: to hit for a weapon, armour class for medium
# and heavy body armour (which still give at least +1 until they break). Light
# armour and shields keep their whole bonus until the last notch goes. A helmet
# and the secondary pieces give no armour class and lose nothing until broken.
#
# HOW A PIECE WEARS
#   Marks   end_fight(rounds): every piece used in the fight - a weapon that
#           attacked, anything worn by someone who was attacked - gains a mark
#           for every two rounds. At hardness x factor marks it loses a notch.
#   Blows   EventBus.attack_resolved: a critical hit takes a notch from the
#           target's shield, or without one from its body armour (two times in
#           three) or another worn piece; a natural 1 takes one from the
#           attacker's weapon. A two-handed or bludgeoning weapon takes two.
#           Where two pieces meet their hardness is compared: the harder
#           striker takes one more, and a piece harder by 2 takes a mark and no
#           notch. A magic piece may ignore a notch lost to a blow (never one
#           lost to marks).
# A debuff comes only with a lost notch and goes with any repair. A buff is
# earned from what the piece has lived through and stays. No debuff or buff
# ever changes marks or hardness.
#
# REPAIR
# repair() is the one function that mends: a field kit restores one notch and
# leaves the marks; a full repair (the smith, Phase 4) restores everything and
# clears them. The requests - repair, repair_all, salvage - are the
# CombatController's, which refuses them in a fight.
#
# Dice: _roll() is the only source of chance here. force_rolls() fixes what it
# gives, for checks.
extends Node

# The slots whose pieces wear, besides the hands
const WORN_SLOTS: Array[String] = ["head", "chest", "shoulder", "back", "wrist", "hands", "waist", "legs", "feet"]
const SECONDARY_SLOTS: Array[String] = ["shoulder", "back", "wrist", "hands", "waist", "legs", "feet"]

# What kind of piece an item is to these rules (get_piece_kind)
const KIND_WEAPON := "weapon"
const KIND_SHIELD := "shield"
const KIND_BODY := "body"
const KIND_HEAD := "head"
const KIND_SECONDARY := "secondary"

# What took a notch
const CAUSE_MARKS := "marks"
const CAUSE_CRITICAL := "critical"
const CAUSE_NATURAL_ONE := "natural_1"

const DEBUFF_CRACKED := "cracked"
const DEBUFF_BREACHED := "breached"
const DEBUFF_DENTED := "dented"
const DEBUFF_TORN := "torn"
const DEBUFF_CHIPPED := "chipped"

const BUFF_BATTLE_HONED := "battle_honed"
const BUFF_BLOOD_FORGED := "blood_forged"   # stored with what it was forged against: "blood_forged:goblin"
const BUFF_MAGE_TOUCHED := "mage_touched"
const BUFF_DRAGON_HARDENED := "dragon_hardened"

# What a notch lost without a debuff is called
const WEAR_NAME_DULLED := "dulled"
const WEAR_NAME_DENTED := "dented"
const WEAR_NAME_TORN := "torn"

# repair(): restore every lost notch
const ALL_NOTCHES: int = -1

const SOFT_KINDS: Array[String] = ["leather", "cloth"]
const DRAGON_HARDENED_TYPES: Array[String] = ["fire", "cold"]

# Off: nothing wears, nothing is earned and loot arrives whole. For checks that
# are not about wear, and for a simulator's control runs.
var wear_enabled: bool = true

# The fight being fought: which pieces were used in it, and by whom
var _fight_running: bool = false
var _used: Array = []  # [{instance, owner}]

# Results _roll() gives before it asks the generator (force_rolls)
var _forced_rolls: Array = []

func _ready():
	EventBus.attack_resolved.connect(_on_attack_resolved)
	EventBus.damage_incoming.connect(_on_damage_incoming)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.item_enchanted.connect(_on_item_enchanted)
	print("DurabilityManager initialized")

func reset():
	"""Back to a fresh game: no fight is being counted.
	Called by GameManager.reset_game_state()."""
	_fight_running = false
	_used.clear()
	_forced_rolls.clear()

# ============================================================================
# WHAT WEARS
# ============================================================================

func wears_item(item_data) -> bool:
	"""True for an item that wears: a weapon, a shield, or a piece for the head,
	the body or one of the seven secondary slots, made of a material"""
	if not (item_data is ItemData) or item_data.material == null:
		return false
	return item_data.is_weapon or item_data.is_shield() or item_data.equip_slot in WORN_SLOTS

func wears(item_instance) -> bool:
	"""True for an item instance that wears (see wears_item)"""
	return item_instance is Dictionary and wears_item(item_instance.get("item_data"))

func get_piece_kind(item_instance) -> String:
	"""What a wearing piece is to these rules: weapon, shield, body (whatever is
	worn on the chest), head or secondary. "" for anything that does not wear."""
	if not wears(item_instance):
		return ""
	var item_data: ItemData = item_instance.item_data
	if item_data.is_weapon:
		return KIND_WEAPON
	if item_data.is_shield():
		return KIND_SHIELD
	if item_data.equip_slot == "chest":
		return KIND_BODY
	if item_data.equip_slot == "head":
		return KIND_HEAD
	return KIND_SECONDARY

func get_original_max(item_data, quality: int = 0, magic: int = 0) -> int:
	"""The notches a piece can hold when it is made: its material's count, one
	more for masterforged craftsmanship, one more for each plus of magic"""
	if not wears_item(item_data):
		return 0
	var count: int = item_data.material.notches
	if quality > 0:
		count += DurabilityDials.masterforged_notches
	count += DurabilityDials.notches_per_magic_plus * maxi(0, magic)
	return maxi(1, count)

func init_instance(item_instance: Dictionary, notch_count: int = 0):
	"""Give a new item instance its durability fields, whole and unworn.
	notch_count, when given, replaces the count its material and making would
	give. Does nothing to an item that does not wear."""
	if not wears(item_instance):
		return
	var count: int = notch_count
	if count <= 0:
		count = get_original_max(item_instance.item_data, int(item_instance.get("quality_modifier", 0)),
			int(item_instance.get("magic_modifier", 0)))
	item_instance["notches_max_original"] = count
	item_instance["notches_max"] = count
	item_instance["notches"] = count
	item_instance["marks"] = 0
	item_instance["age"] = 0
	item_instance["debuffs"] = []
	item_instance["buffs"] = []
	item_instance["wear_names"] = []

func _ensure(item_instance: Dictionary):
	"""An instance put together without its durability fields gets them now"""
	if not item_instance.has("notches"):
		init_instance(item_instance)

func get_notches(item_instance) -> int:
	"""Notches the piece has left; 0 for a broken piece and for anything that does not wear"""
	if not wears(item_instance):
		return 0
	_ensure(item_instance)
	return int(item_instance.notches)

func get_max_notches(item_instance) -> int:
	"""Notches the piece can hold now"""
	if not wears(item_instance):
		return 0
	_ensure(item_instance)
	return int(item_instance.notches_max)

func get_lost_notches(item_instance) -> int:
	return get_max_notches(item_instance) - get_notches(item_instance)

func is_broken(item_instance) -> bool:
	"""True for a wearing piece with no notch left: it gives no bonus, and a weapon cannot attack"""
	return wears(item_instance) and get_notches(item_instance) <= 0

func is_on_last_notch(item_instance) -> bool:
	return wears(item_instance) and get_notches(item_instance) == 1

func gives_bonus(item_instance) -> bool:
	"""False only for a broken piece: whatever it gave, it gives no longer"""
	return not is_broken(item_instance)

func get_hardness(item_instance) -> int:
	"""The hardness of what the piece is made of"""
	if not wears(item_instance):
		return DurabilityDials.flesh_hardness
	return int(item_instance.item_data.material.hardness)

func get_marks(item_instance) -> int:
	if not wears(item_instance):
		return 0
	_ensure(item_instance)
	return int(item_instance.marks)

func get_marks_limit(item_instance) -> int:
	"""The marks at which the piece loses a notch: its hardness times the marks
	factor, which is slower for the seven secondary slots"""
	if not wears(item_instance):
		return 0
	var factor: int = DurabilityDials.marks_factor
	if get_piece_kind(item_instance) == KIND_SECONDARY:
		factor = DurabilityDials.marks_factor_secondary
	return maxi(1, get_hardness(item_instance) * factor)

func get_debuffs(item_instance) -> Array:
	if not wears(item_instance):
		return []
	_ensure(item_instance)
	return item_instance.debuffs

func get_buffs(item_instance) -> Array:
	if not wears(item_instance):
		return []
	_ensure(item_instance)
	return item_instance.buffs

func has_debuff(item_instance, debuff_id: String) -> bool:
	return debuff_id in get_debuffs(item_instance)

func has_buff(item_instance, buff_id: String) -> bool:
	"""True when the piece has the buff; for Blood-Forged, against any kind"""
	for buff in get_buffs(item_instance):
		if str(buff) == buff_id or str(buff).begins_with(buff_id + ":"):
			return true
	return false

# ============================================================================
# WHAT WEAR COSTS
# ============================================================================

func get_attack_penalty(item_instance) -> int:
	"""What a weapon's lost notches take from its attack rolls: 1 for every second one"""
	if get_piece_kind(item_instance) != KIND_WEAPON:
		return 0
	return int(get_lost_notches(item_instance) / maxi(1, DurabilityDials.lost_notches_per_penalty))

func get_armor_penalty(item_instance) -> int:
	"""What a body armour's lost notches take from the armour class it gives:
	1 for every second one for medium and heavy armour, nothing for light.
	How far the wearer's armour class may fall is the wearer's to say
	(CharacterStats.get_armor_class_breakdown)."""
	if get_piece_kind(item_instance) != KIND_BODY or not item_instance.item_data.armor_type in ["medium", "heavy"]:
		return 0
	return int(get_lost_notches(item_instance) / maxi(1, DurabilityDials.lost_notches_per_penalty))

func get_gear_armor_class_loss(item_instance) -> int:
	"""The armour class a body armour or shield has lost, taken on its own: all
	it gave when broken; for medium and heavy armour 1 for every second lost
	notch, leaving at least +1. For a creature whose armour is part of its stat
	block (Enemy.get_gear_armor_class_loss)."""
	var kind: String = get_piece_kind(item_instance)
	if kind != KIND_BODY and kind != KIND_SHIELD:
		return 0
	var item_data: ItemData = item_instance.item_data
	var bonus: int = ItemDatabase.get_instance_bonus(item_instance)
	if kind == KIND_SHIELD:
		bonus += item_data.armor_class_bonus
	else:
		bonus += maxi(0, item_data.armor_base - CharacterStats.UNARMORED_AC)
	if is_broken(item_instance):
		return bonus
	return mini(get_armor_penalty(item_instance), maxi(0, bonus - DurabilityDials.armor_bonus_floor))

func get_attack_bonus(item_instance) -> int:
	"""What a weapon's buffs add to its attack rolls: Battle-Honed"""
	if get_piece_kind(item_instance) != KIND_WEAPON or not has_buff(item_instance, BUFF_BATTLE_HONED):
		return 0
	return DurabilityDials.battle_honed_attack_bonus

func get_damage_penalty(item_instance) -> int:
	"""What a weapon's debuffs take from its damage: Chipped"""
	if get_piece_kind(item_instance) != KIND_WEAPON or not has_debuff(item_instance, DEBUFF_CHIPPED):
		return 0
	return DurabilityDials.chipped_damage_penalty

func get_damage_bonus_against(item_instance, target) -> int:
	"""What a weapon's buffs add to its damage against one target: Blood-Forged
	against the kind of creature it was forged on, Mage-Touched against a
	spellcaster"""
	if get_piece_kind(item_instance) != KIND_WEAPON or not is_instance_valid(target):
		return 0
	var bonus: int = 0
	var creature: String = _creature_kind(target)
	if creature != "" and ("%s:%s" % [BUFF_BLOOD_FORGED, creature]) in get_buffs(item_instance):
		bonus += DurabilityDials.blood_forged_damage
	if has_buff(item_instance, BUFF_MAGE_TOUCHED) and _is_spellcaster(target):
		bonus += DurabilityDials.mage_touched_damage
	return bonus

func pieces_have_debuff(pieces: Array, debuff_id: String) -> bool:
	"""True when any of the pieces carries the debuff. A debuff is one penalty
	for its wearer however many pieces carry it."""
	for piece in pieces:
		if has_debuff(piece, debuff_id):
			return true
	return false

func get_critical_threshold(target, natural_twenty: int = 20) -> int:
	"""The lowest natural d20 that is a critical hit on the target: one lower
	while it wears a breached piece"""
	if is_instance_valid(target) and target is Combatant and pieces_have_debuff(target.get_wear_pieces(), DEBUFF_BREACHED):
		return natural_twenty - DurabilityDials.breached_critical_range
	return natural_twenty

func get_speed_penalty_tiles(pieces: Array) -> int:
	"""Tiles of movement the wearer of these pieces loses: Dented"""
	return DurabilityDials.dented_speed_tiles if pieces_have_debuff(pieces, DEBUFF_DENTED) else 0

func get_armor_class_modifier(target, damage_type: String = "") -> int:
	"""What wear and buffs change about the target's armour class at the moment
	of an attack, beyond what its stats already hold: the armour class a
	creature's own armour has lost (a party member's is in its stats), and
	Dragon-Hardened body armour against fire and cold"""
	if not is_instance_valid(target) or not (target is Combatant):
		return 0
	var modifier: int = -target.get_gear_armor_class_loss()
	if damage_type in DRAGON_HARDENED_TYPES:
		for piece in target.get_wear_pieces():
			if get_piece_kind(piece) == KIND_BODY and has_buff(piece, BUFF_DRAGON_HARDENED) and not is_broken(piece):
				modifier += DurabilityDials.dragon_hardened_armor_class
				break
	return modifier

# ============================================================================
# WORDS: what the tooltip, the sheet, the readout and the log say
# ============================================================================

func get_condition_text(item_instance) -> String:
	"""'3 of 4 notches, wear 2 of 15', or 'BROKEN'"""
	if not wears(item_instance):
		return ""
	if is_broken(item_instance):
		return "BROKEN - gives nothing until repaired"
	return "%d of %d notches, wear %d of %d" % [get_notches(item_instance), get_max_notches(item_instance),
		get_marks(item_instance), get_marks_limit(item_instance)]

func get_debuff_text(debuff_id: String) -> String:
	"""A debuff and its one penalty, as the player reads it"""
	match debuff_id:
		DEBUFF_CRACKED:
			return "Cracked: breaks on the next critical hit against it, or natural 1 with it"
		DEBUFF_BREACHED:
			return "Breached: attackers score critical hits on %d-20 against the wearer" % (20 - DurabilityDials.breached_critical_range)
		DEBUFF_DENTED:
			return "Dented: %d tile less movement" % DurabilityDials.dented_speed_tiles
		DEBUFF_TORN:
			return "Torn: hits on the wearer deal +%d damage" % DurabilityDials.torn_extra_damage
		DEBUFF_CHIPPED:
			return "Chipped: -%d damage" % DurabilityDials.chipped_damage_penalty
	return debuff_id.capitalize()

func get_buff_text(buff_id: String) -> String:
	"""A buff and its bonus, as the player reads it"""
	var base: String = buff_id.get_slice(":", 0)
	match base:
		BUFF_BATTLE_HONED:
			return "Battle-Honed: +%d to hit" % DurabilityDials.battle_honed_attack_bonus
		BUFF_BLOOD_FORGED:
			return "Blood-Forged: +%d damage against every %s" % [DurabilityDials.blood_forged_damage, buff_id.get_slice(":", 1).replace("_", " ")]
		BUFF_MAGE_TOUCHED:
			return "Mage-Touched: +%d damage against spellcasters" % DurabilityDials.mage_touched_damage
		BUFF_DRAGON_HARDENED:
			return "Dragon-Hardened: +%d armour class against fire and cold" % DurabilityDials.dragon_hardened_armor_class
	return buff_id.capitalize()

func get_debuff_lines(item_instance) -> Array[String]:
	var lines: Array[String] = []
	for debuff in get_debuffs(item_instance):
		lines.append(get_debuff_text(str(debuff)))
	return lines

func get_buff_lines(item_instance) -> Array[String]:
	var lines: Array[String] = []
	for buff in get_buffs(item_instance):
		lines.append(get_buff_text(str(buff)))
	return lines

func get_wear_names(item_instance) -> Array[String]:
	"""What the piece's plain lost notches are called - dulled, dented, torn.
	Flavour only: a name that is also a debuff on the piece is left to the debuff."""
	var names: Array[String] = []
	if not wears(item_instance):
		return names
	_ensure(item_instance)
	for wear_name in item_instance.wear_names:
		if not has_debuff(item_instance, str(wear_name)) and not names.has(str(wear_name)):
			names.append(str(wear_name))
	return names

func get_attack_notes(item_instance, target = null) -> Array[String]:
	"""What the wear and the buffs of a weapon do to an attack with it, and what
	the target's torn gear adds: lines for the attack readout"""
	var notes: Array[String] = []
	var penalty: int = get_attack_penalty(item_instance)
	if penalty > 0:
		notes.append("Worn weapon, %d notches lost: -%d to hit" % [get_lost_notches(item_instance), penalty])
	if get_damage_penalty(item_instance) > 0:
		notes.append(get_debuff_text(DEBUFF_CHIPPED))
	if has_debuff(item_instance, DEBUFF_CRACKED):
		notes.append("Cracked: breaks on a natural 1")
	if get_attack_bonus(item_instance) > 0:
		notes.append(get_buff_text(BUFF_BATTLE_HONED))
	var against: int = get_damage_bonus_against(item_instance, target)
	if against > 0:
		notes.append("Blood-Forged or Mage-Touched: +%d damage against this enemy" % against)
	if is_instance_valid(target) and target is Combatant:
		if pieces_have_debuff(target.get_wear_pieces(), DEBUFF_TORN):
			notes.append("Its torn armour: +%d damage" % DurabilityDials.torn_extra_damage)
		if pieces_have_debuff(target.get_wear_pieces(), DEBUFF_BREACHED):
			notes.append("Its breached armour: critical hit on %d-20" % (20 - DurabilityDials.breached_critical_range))
	return notes

func get_wearer_notes(pieces: Array) -> Array[String]:
	"""What the debuffs on a wearer's gear cost it, a line for each: for the
	character sheet, under the armour class"""
	var notes: Array[String] = []
	for debuff in [DEBUFF_BREACHED, DEBUFF_TORN, DEBUFF_DENTED]:
		for piece in pieces:
			if has_debuff(piece, debuff):
				notes.append("%s - %s" % [ItemDatabase.get_instance_name(piece), get_debuff_text(debuff)])
				break
	return notes

func get_warnings(pieces: Array) -> Array:
	"""The pieces in use that are broken or on their last notch, worst first:
	[{instance, name, broken, text}]. What the HUD warns about."""
	var warnings: Array = []
	for want_broken in [true, false]:
		for piece in pieces:
			if not wears(piece) or is_broken(piece) != want_broken or (not want_broken and not is_on_last_notch(piece)):
				continue
			var piece_name: String = ItemDatabase.get_instance_name(piece)
			warnings.append({"instance": piece, "name": piece_name, "broken": want_broken,
				"text": "%s: %s" % [piece_name, "BROKEN" if want_broken else "last notch"]})
	return warnings

# ============================================================================
# WEAR: taking notches and adding marks
# ============================================================================

func add_marks(item_instance, count: int, owner = null) -> Dictionary:
	"""Add wear marks to a piece. At its limit the piece loses a notch and the
	marks start again; nothing resists that. Returns {marks_added, notches_lost,
	broken}. A broken piece wears no further."""
	var report: Dictionary = {"marks_added": 0, "notches_lost": 0, "broken": false}
	if not wears(item_instance) or count <= 0 or is_broken(item_instance):
		return report
	item_instance["marks"] = get_marks(item_instance) + count
	report["marks_added"] = count
	var limit: int = get_marks_limit(item_instance)
	while int(item_instance.marks) >= limit and int(item_instance.notches) > 0:
		item_instance["marks"] = int(item_instance.marks) - limit
		report["notches_lost"] += _take_notches(item_instance, 1)
	if int(report.notches_lost) > 0:
		report["broken"] = is_broken(item_instance)
		if report.broken:
			item_instance["marks"] = 0
		_name_wear(item_instance, CAUSE_MARKS)
		_announce_loss(item_instance, owner, int(report.notches_lost), CAUSE_MARKS, [])
		_refresh_owner(owner)
	return report

func lose_notches(item_instance, count: int, cause: String, owner = null, damage_type: String = "") -> Dictionary:
	"""Take notches from a piece for a cause, with the debuffs the cause brings.
	No hardness is compared and nothing is resisted here: a blow goes through
	strike(). Returns {notches_lost, debuffs, broken}."""
	var report: Dictionary = {"notches_lost": 0, "debuffs": [], "broken": false}
	if not wears(item_instance) or count <= 0 or is_broken(item_instance):
		return report
	var lost: int = _take_notches(item_instance, count)
	report["notches_lost"] = lost
	report["broken"] = is_broken(item_instance)
	var gained: Array = []
	for debuff in _debuffs_for(item_instance, cause, damage_type, lost):
		if not has_debuff(item_instance, debuff):
			item_instance.debuffs.append(debuff)
			gained.append(debuff)
	report["debuffs"] = gained
	if gained.is_empty():
		_name_wear(item_instance, cause)
	_announce_loss(item_instance, owner, lost, cause, gained)
	_refresh_owner(owner)
	return report

func strike(item_instance, owner, base_notches: int, other_hardness: int, cause: String, damage_type: String = "") -> Dictionary:
	"""A blow lands on a piece: a critical hit on a shield or armour, or the
	weapon's own natural 1. In order: a cracked piece breaks; the hardness of
	the two that met is compared (other_hardness below 0: nothing to compare
	with); a magic piece may ignore each notch; what is left is lost, with its
	debuffs. Returns {outcome ("lost" | "broke" | "marked" | "resisted" |
	"none"), notches_lost, marks_added, resisted, debuffs, broken}."""
	var report: Dictionary = {"outcome": "none", "notches_lost": 0, "marks_added": 0, "resisted": 0, "debuffs": [], "broken": false}
	if not wears(item_instance) or is_broken(item_instance):
		return report
	_ensure(item_instance)

	if has_debuff(item_instance, DEBUFF_CRACKED):
		report["notches_lost"] = _take_notches(item_instance, int(item_instance.notches))
		report["outcome"] = "broke"
		report["broken"] = true
		_announce("break", item_instance, owner, "%s was cracked and breaks. It gives nothing until it is repaired." % _piece_label(item_instance, owner), "error")
		_refresh_owner(owner)
		return report

	var loss: int = base_notches
	if other_hardness >= 0:
		var own_hardness: int = get_hardness(item_instance)
		if other_hardness - own_hardness >= DurabilityDials.hardness_gap:
			loss += DurabilityDials.harder_striker_notches
		elif own_hardness - other_hardness >= DurabilityDials.hardness_gap:
			var marked: Dictionary = add_marks(item_instance, DurabilityDials.harder_piece_marks, owner)
			report["outcome"] = "marked"
			report["marks_added"] = int(marked.marks_added)
			report["notches_lost"] = int(marked.notches_lost)
			report["broken"] = bool(marked.broken)
			_announce("mark", item_instance, owner, "%s is too hard to notch: a wear mark instead." % _piece_label(item_instance, owner), "info", false)
			return report

	var chance: float = get_resist_chance(item_instance)
	if chance > 0.0:
		for i in range(loss):
			if _roll() < chance:
				report["resisted"] += 1
		loss -= int(report.resisted)
	if loss <= 0:
		report["outcome"] = "resisted"
		_announce("resist", item_instance, owner, "%s shrugs the blow off: its magic holds." % _piece_label(item_instance, owner), "info", false)
		return report

	var lost: Dictionary = lose_notches(item_instance, loss, cause, owner, damage_type)
	report["outcome"] = "lost"
	report["notches_lost"] = int(lost.notches_lost)
	report["debuffs"] = lost.debuffs
	report["broken"] = bool(lost.broken)
	return report

func get_resist_chance(item_instance) -> float:
	"""The chance of a magic piece to ignore a notch lost to a blow"""
	var chances: Array[float] = DurabilityDials.magic_resist_chance
	if not wears(item_instance) or chances.is_empty():
		return 0.0
	return chances[clampi(ItemDatabase.get_instance_magic_bonus(item_instance), 0, chances.size() - 1)]

func _take_notches(item_instance: Dictionary, count: int) -> int:
	"""Lower the notch count; returns how many went. Remembers a break."""
	_ensure(item_instance)
	var lost: int = clampi(count, 0, int(item_instance.notches))
	if lost <= 0:
		return 0
	item_instance["notches"] = int(item_instance.notches) - lost
	EventBus.item_durability_changed.emit(item_instance, int(item_instance.notches), int(item_instance.notches_max))
	if int(item_instance.notches) <= 0:
		item_instance["ever_broken"] = true
		EventBus.item_broken.emit(item_instance)
	return lost

func _debuffs_for(item_instance: Dictionary, cause: String, damage_type: String, notches_lost: int) -> Array:
	"""The debuffs a lost notch brings, by what took it. None without a notch."""
	var found: Array = []
	if notches_lost <= 0:
		return found
	var kind: String = get_piece_kind(item_instance)
	if cause != CAUSE_MARKS and notches_lost >= DurabilityDials.cracked_notches:
		found.append(DEBUFF_CRACKED)
	if cause == CAUSE_CRITICAL:
		var is_armor: bool = kind in [KIND_BODY, KIND_HEAD, KIND_SECONDARY]
		if damage_type == "piercing" and is_armor:
			found.append(DEBUFF_BREACHED)
		if damage_type == "bludgeoning" and (is_armor or kind == KIND_SHIELD):
			found.append(DEBUFF_DENTED)
		if damage_type == "slashing" and kind != KIND_WEAPON and item_instance.item_data.material.get_kind() in SOFT_KINDS:
			found.append(DEBUFF_TORN)
	elif cause == CAUSE_NATURAL_ONE and kind == KIND_WEAPON:
		found.append(DEBUFF_CHIPPED)
	return found

func _name_wear(item_instance: Dictionary, _cause: String):
	"""Record what a notch lost without a debuff is called: a weapon is dulled,
	leather and cloth are torn, anything else is dented"""
	var wear_name: String = WEAR_NAME_DENTED
	if get_piece_kind(item_instance) == KIND_WEAPON:
		wear_name = WEAR_NAME_DULLED
	elif item_instance.item_data.material.get_kind() in SOFT_KINDS:
		wear_name = WEAR_NAME_TORN
	if not item_instance.wear_names.has(wear_name):
		item_instance.wear_names.append(wear_name)

# ============================================================================
# FIGHTS: marks by the length of the fight
# ============================================================================

func begin_fight():
	"""A fight starts: from now on, note which pieces are used in it. Called
	by the CombatController."""
	_used.clear()
	_fight_running = true

func end_fight(rounds: int) -> Dictionary:
	"""The fight is over after so many rounds: every piece used in it gains its
	marks, one for every two rounds, rounded up. Called by the CombatController.
	Returns {marks (what each piece gained), pieces (how many gained them),
	notches_lost}."""
	var report: Dictionary = {"marks": 0, "pieces": 0, "notches_lost": 0}
	var used: Array = _used.duplicate()
	_used.clear()
	var was_running: bool = _fight_running
	_fight_running = false
	if not was_running or not wear_enabled or rounds <= 0:
		return report
	var marks: int = get_marks_for_rounds(rounds)
	report["marks"] = marks
	for entry in used:
		var owner = entry.owner if is_instance_valid(entry.owner) else null
		var result: Dictionary = add_marks(entry.instance, marks, owner)
		if int(result.marks_added) > 0:
			report["pieces"] += 1
		report["notches_lost"] += int(result.notches_lost)
	if int(report.pieces) > 0:
		_announce("fight", {}, null, "The fight lasted %d %s: %d wear %s on each of the %d pieces used." % [rounds,
			"round" if rounds == 1 else "rounds", marks, "mark" if marks == 1 else "marks", int(report.pieces)], "info", false)
	return report

func get_marks_for_rounds(rounds: int) -> int:
	"""The marks a fight of so many rounds gives each piece used in it"""
	if rounds <= 0:
		return 0
	return int(ceil(float(rounds) / float(maxi(1, DurabilityDials.rounds_per_mark))))

func is_used_in_fight(item_instance) -> bool:
	"""True when the piece has been used in the fight being fought"""
	for entry in _used:
		if is_same(entry.instance, item_instance):
			return true
	return false

func _note_used(item_instance, owner):
	if not _fight_running or not wears(item_instance) or is_used_in_fight(item_instance):
		return
	_used.append({"instance": item_instance, "owner": owner})

# ============================================================================
# THE HOOKS
# ============================================================================

func _on_attack_resolved(event: Dictionary):
	"""An attack roll was made. The weapon that made it was used, and so was
	everything its target wears; a critical hit and a natural 1 take notches."""
	if not wear_enabled:
		return
	var attacker = event.get("attacker")
	var target = event.get("target")
	var weapon_instance = event.get("weapon_instance", {})
	if weapon_instance is Dictionary and not weapon_instance.is_empty():
		_note_used(weapon_instance, attacker)
	if is_instance_valid(target) and target is Combatant:
		for piece in target.get_wear_pieces():
			if get_piece_kind(piece) != KIND_WEAPON:
				_note_used(piece, target)

	if event.get("is_fumble", false):
		_resolve_natural_one(event)
	elif event.get("is_crit", false) and event.get("hit", false):
		_resolve_critical(event)

func _resolve_natural_one(event: Dictionary):
	"""A natural 1: a notch from the attacker's weapon. A melee weapon is
	measured against what it was swung at; a bow or crossbow met nothing."""
	var weapon_instance = event.get("weapon_instance", {})
	if not wears(weapon_instance) or is_broken(weapon_instance):
		return
	var other_hardness: int = -1
	if not event.get("is_ranged", false):
		other_hardness = get_struck_hardness(event.get("target"))
	strike(weapon_instance, event.get("attacker"), DurabilityDials.natural_one_notches, other_hardness, CAUSE_NATURAL_ONE,
		str(event.get("damage_type", "")))

func _resolve_critical(event: Dictionary):
	"""A critical hit: a notch from the target's shield, or its armour; two
	from a two-handed weapon or one that deals bludgeoning damage"""
	var target = event.get("target")
	if not is_instance_valid(target) or not (target is Combatant):
		return
	var piece: Dictionary = pick_struck_piece(target)
	if piece.is_empty():
		return
	var damage_type: String = str(event.get("damage_type", ""))
	var notches: int = DurabilityDials.critical_notches
	if is_heavy_blow(event):
		notches = DurabilityDials.heavy_blow_notches
	strike(piece, target, notches, get_striker_hardness(event), CAUSE_CRITICAL, damage_type)

func is_heavy_blow(event: Dictionary) -> bool:
	"""True for a blow with a two-handed weapon, or with a weapon that deals
	bludgeoning damage. A bare fist is no weapon."""
	if str(event.get("kind", "")) != CombatManager.KIND_WEAPON:
		return false
	return bool(event.get("two_handed", false)) or str(event.get("damage_type", "")) == "bludgeoning"

func pick_struck_piece(target) -> Dictionary:
	"""The piece a critical hit on the target lands on: its shield in hand;
	without one its body armour two times in three and another worn piece,
	picked at random, one time in three - the body armour when nothing else is
	worn. A broken piece stops nothing more. {} when the blow finds nothing."""
	var body: Dictionary = {}
	var others: Array = []
	for piece in target.get_wear_pieces():
		if is_broken(piece):
			continue
		match get_piece_kind(piece):
			KIND_SHIELD:
				return piece
			KIND_BODY:
				body = piece
			KIND_HEAD, KIND_SECONDARY:
				others.append(piece)
	var on_body: bool = _roll() * DurabilityDials.critical_spread < DurabilityDials.critical_body_share
	if on_body or others.is_empty():
		return body
	return others[clampi(int(_roll() * others.size()), 0, others.size() - 1)]

func get_striker_hardness(event: Dictionary) -> int:
	"""How hard what struck is: the weapon's material, a creature's own claws
	or teeth, a bare fist. -1 for a spell: no piece struck."""
	if str(event.get("kind", "")) == CombatManager.KIND_SPELL:
		return -1
	var weapon_instance = event.get("weapon_instance", {})
	if wears(weapon_instance):
		return get_hardness(weapon_instance)
	var weapon = event.get("weapon")
	if weapon is ItemData and weapon.material != null:
		return int(weapon.material.hardness)
	var attacker = event.get("attacker")
	if str(event.get("kind", "")) == CombatManager.KIND_WEAPON and is_instance_valid(attacker) and attacker is Combatant:
		return attacker.get_natural_weapon_hardness()
	return DurabilityDials.flesh_hardness

func get_struck_hardness(target) -> int:
	"""How hard what a swing at the target meets is: its shield, else its body
	armour, else its hide"""
	if not is_instance_valid(target) or not (target is Combatant):
		return DurabilityDials.flesh_hardness
	var body: Dictionary = {}
	for piece in target.get_wear_pieces():
		if is_broken(piece):
			continue
		var kind: String = get_piece_kind(piece)
		if kind == KIND_SHIELD:
			return get_hardness(piece)
		if kind == KIND_BODY:
			body = piece
	return get_hardness(body) if not body.is_empty() else target.get_hide_hardness()

func _on_damage_incoming(event: Dictionary):
	"""Damage of an attack that hit: +1 against a wearer of torn gear; +1 from a
	Blood-Forged or Mage-Touched weapon against what it was forged on"""
	var context: Dictionary = event.get("context", {})
	if not context.get("attack_roll", false) or int(event.get("amount", 0)) <= 0:
		return
	var target = event.get("target")
	var extra: int = 0
	if is_instance_valid(target) and target is Combatant and pieces_have_debuff(target.get_wear_pieces(), DEBUFF_TORN):
		extra += DurabilityDials.torn_extra_damage
	extra += get_damage_bonus_against(context.get("weapon_instance", {}), target)
	if extra != 0:
		event["amount"] = int(event.amount) + extra

func _on_damage_applied(event: Dictionary):
	"""A kill with a weapon is counted on the weapon. Body armour whose wearer
	lives through a breath weapon is Dragon-Hardened."""
	if not wear_enabled:
		return
	var context: Dictionary = event.get("context", {})
	var target = event.get("target")
	if event.get("killed", false) and str(event.get("kind", "")) == CombatManager.KIND_WEAPON:
		record_kill(context.get("weapon_instance", {}), target, event.get("source"))
	if context.get("breath_weapon", false) and not event.get("killed", false):
		record_breath_weapon_survived(target)

func record_kill(weapon_instance, target, owner = null):
	"""Count a kill on the weapon that made it, and give the weapon what its
	kills have earned: Battle-Honed, Blood-Forged, Mage-Touched"""
	if get_piece_kind(weapon_instance) != KIND_WEAPON:
		return
	_ensure(weapon_instance)
	weapon_instance["kills"] = int(weapon_instance.get("kills", 0)) + 1
	var creature: String = _creature_kind(target)
	if creature != "":
		var by_type: Dictionary = weapon_instance.get("kills_by_type", {})
		by_type[creature] = int(by_type.get(creature, 0)) + 1
		weapon_instance["kills_by_type"] = by_type
		if int(by_type[creature]) >= DurabilityDials.blood_forged_kills:
			_earn(weapon_instance, "%s:%s" % [BUFF_BLOOD_FORGED, creature], owner)
	if _is_spellcaster(target):
		weapon_instance["caster_kills"] = int(weapon_instance.get("caster_kills", 0)) + 1
		if int(weapon_instance.caster_kills) >= DurabilityDials.mage_touched_kills:
			_earn(weapon_instance, BUFF_MAGE_TOUCHED, owner)
	if int(weapon_instance.kills) >= DurabilityDials.battle_honed_kills and not weapon_instance.get("ever_broken", false):
		_earn(weapon_instance, BUFF_BATTLE_HONED, owner)

func record_breath_weapon_survived(wearer):
	"""The wearer has lived through a breath weapon: its body armour is
	Dragon-Hardened. Damage dealt with breath_weapon in its context calls this;
	nothing breathes yet."""
	if not is_instance_valid(wearer) or not (wearer is Combatant) or not wearer.is_alive():
		return
	for piece in wearer.get_wear_pieces():
		if get_piece_kind(piece) == KIND_BODY and not is_broken(piece):
			_earn(piece, BUFF_DRAGON_HARDENED, wearer)

func _earn(item_instance: Dictionary, buff_id: String, owner = null):
	"""Give a piece a buff it does not have yet, and say so"""
	_ensure(item_instance)
	if buff_id in item_instance.buffs:
		return
	item_instance.buffs.append(buff_id)
	_announce("buff", item_instance, owner, "%s has earned a name. %s." % [_piece_label(item_instance, owner), get_buff_text(buff_id)],
		"success", true, {"buff": buff_id})
	_refresh_owner(owner)

func _on_item_enchanted(item_instance, _enchantment_id: String):
	"""A plus of magic adds a notch: the piece's maximum follows its magic"""
	if not wears(item_instance):
		return
	_ensure(item_instance)
	var original: int = get_original_max(item_instance.item_data, int(item_instance.get("quality_modifier", 0)),
		int(item_instance.get("magic_modifier", 0)))
	var gained: int = original - int(item_instance.notches_max_original)
	if gained == 0:
		return
	item_instance["notches_max_original"] = original
	item_instance["notches_max"] = maxi(1, int(item_instance.notches_max) + gained)
	item_instance["notches"] = clampi(int(item_instance.notches) + maxi(0, gained), 0, int(item_instance.notches_max))

func _creature_kind(target) -> String:
	"""What kind of creature a combatant is, for the kills a weapon counts"""
	if is_instance_valid(target) and "enemy_type" in target:
		return str(target.enemy_type)
	return ""

func _is_spellcaster(target) -> bool:
	return is_instance_valid(target) and target is Combatant and target.stats != null and SpellManager.is_caster(target.stats)

# ============================================================================
# REPAIR, SALVAGE, AGEING
# ============================================================================

func repair(item_instance, notches_to_restore: int = ALL_NOTCHES, clear_marks: bool = false) -> Dictionary:
	"""Mend a piece. A field kit restores one notch and leaves the marks; a full
	repair restores every notch (ALL_NOTCHES) and clears them. Any repair
	clears the piece's debuffs. The piece ages by one for every notch restored,
	and every so much age costs it one maximum notch, never the last.
	What a repair costs is the caller's business.
	Returns {restored, aged (maximum notches lost to age), notches, notches_max}."""
	var report: Dictionary = {"restored": 0, "aged": 0, "notches": 0, "notches_max": 0}
	if not wears(item_instance):
		return report
	_ensure(item_instance)
	var missing: int = int(item_instance.notches_max) - int(item_instance.notches)
	var restored: int = missing if notches_to_restore < 0 else mini(notches_to_restore, missing)
	item_instance["notches"] = int(item_instance.notches) + restored
	item_instance["age"] = int(item_instance.age) + restored * DurabilityDials.age_per_repaired_notch
	item_instance.debuffs.clear()
	if clear_marks:
		item_instance["marks"] = 0

	var aged_max: int = get_aged_max(item_instance)
	if aged_max < int(item_instance.notches_max):
		report["aged"] = int(item_instance.notches_max) - aged_max
		item_instance["notches_max"] = aged_max
		item_instance["notches"] = mini(int(item_instance.notches), aged_max)
	if int(item_instance.notches) >= int(item_instance.notches_max):
		item_instance.wear_names.clear()

	report["restored"] = restored
	report["notches"] = int(item_instance.notches)
	report["notches_max"] = int(item_instance.notches_max)
	EventBus.item_durability_changed.emit(item_instance, int(item_instance.notches), int(item_instance.notches_max))
	EventBus.item_repaired.emit(item_instance)
	return report

func get_aged_max(item_instance) -> int:
	"""The notches a piece of its age can hold: its original maximum less one
	for every age_factor times that maximum in age, never fewer than 1"""
	if not wears(item_instance):
		return 0
	_ensure(item_instance)
	var original: int = int(item_instance.notches_max_original)
	var per_notch: int = maxi(1, DurabilityDials.age_factor * original)
	return maxi(1, original - int(int(item_instance.age) / per_notch))

func find_repair_kit() -> Dictionary:
	"""A repair kit in the party's pack, or {}"""
	for carried in InventoryManager.items:
		if carried.item_data.item_id == ItemDatabase.REPAIR_KIT_ID:
			return carried
	return {}

func count_repair_kits() -> int:
	"""How many repair kits the party's pack holds"""
	var kit: Dictionary = find_repair_kit()
	return 0 if kit.is_empty() else int(kit.get("stack_count", 1))

func find_scrap(item_instance) -> Dictionary:
	"""The scrap in the party's pack a kit would patch the piece with: of the
	piece's kind (metal, wood, leather, cloth) and at least as hard, and of
	those the softest - the cheaper when two are as hard. {} when there is none."""
	if not wears(item_instance):
		return {}
	var material: MaterialData = item_instance.item_data.material
	var best: Dictionary = {}
	for carried in InventoryManager.items:
		var scrap: MaterialData = carried.item_data.material
		if not ItemDatabase.is_scrap(carried.item_data) or scrap == null:
			continue
		if scrap.get_kind() != material.get_kind() or scrap.hardness < material.hardness:
			continue
		if int(carried.get("stack_count", 1)) < DurabilityDials.kit_scrap_units:
			continue
		if best.is_empty() or _softer(scrap, best.item_data.material):
			best = carried
	return best

func _softer(a: MaterialData, b: MaterialData) -> bool:
	"""True when scrap of a goes before scrap of b: softer, then cheaper, then by id"""
	if a.hardness != b.hardness:
		return a.hardness < b.hardness
	if not is_equal_approx(a.price_multiplier, b.price_multiplier):
		return a.price_multiplier < b.price_multiplier
	return a.material_id < b.material_id

func get_repair_refusal(item_instance) -> String:
	"""Why a repair kit cannot mend the piece right now, or "" when it can"""
	if not wears(item_instance):
		return "That does not wear, so there is nothing to repair"
	var piece_name: String = ItemDatabase.get_instance_name(item_instance)
	if get_lost_notches(item_instance) <= 0:
		return "%s has every notch it can hold" % piece_name
	if find_repair_kit().is_empty():
		return "No repair kit in the pack"
	if find_scrap(item_instance).is_empty():
		var material: MaterialData = item_instance.item_data.material
		return "No scrap to patch %s: it takes %s scrap of hardness %d or more" % [piece_name, material.get_kind(), material.hardness]
	return ""

func repair_with_kit(item_instance, owner = null) -> Dictionary:
	"""Mend a piece in the field: one repair kit and one unit of suitable scrap
	from the pack restore one notch. The marks stay. Returns {ok, reason,
	restored, aged, scrap_name}; a refusal uses nothing up."""
	var refusal: String = get_repair_refusal(item_instance)
	if refusal != "":
		return {"ok": false, "reason": refusal, "restored": 0, "aged": 0, "scrap_name": ""}
	var scrap: Dictionary = find_scrap(item_instance)
	var scrap_name: String = scrap.item_data.item_name
	for unit in range(DurabilityDials.kit_scrap_units):
		InventoryManager.remove_item(scrap.instance_id)
	InventoryManager.remove_item(find_repair_kit().instance_id)

	var mended: Dictionary = repair(item_instance, DurabilityDials.kit_notches, false)
	var piece_name: String = ItemDatabase.get_instance_name(item_instance)
	_announce("repair", item_instance, owner, "%s repaired with %s: %d of %d notches." % [piece_name, scrap_name,
		int(mended.notches), int(mended.notches_max)], "success")
	if int(mended.aged) > 0:
		_announce("age", item_instance, owner, "%s has aged: it holds %d %s at most now." % [piece_name, int(mended.notches_max),
			"notch" if int(mended.notches_max) == 1 else "notches"], "warning")
	_refresh_owner(owner)
	return {"ok": true, "reason": "", "restored": int(mended.restored), "aged": int(mended.aged), "scrap_name": scrap_name}

func get_repairable_pieces(character: CharacterStats) -> Array:
	"""Everything the character has equipped that has lost a notch, the worst
	off first: the piece with the smallest share of its notches left"""
	var pieces: Array = []
	for piece in InventoryManager.get_all_equipped_items(character):
		if wears(piece) and get_lost_notches(piece) > 0:
			pieces.append(piece)
	pieces.sort_custom(func(a, b): return float(get_notches(a)) / get_max_notches(a) < float(get_notches(b)) / get_max_notches(b))
	return pieces

func get_repair_all_refusal(character: CharacterStats) -> String:
	"""Why repair_all would mend nothing, or "" when it would mend something"""
	var pieces: Array = get_repairable_pieces(character)
	if pieces.is_empty():
		return "Nothing worn needs repair"
	for piece in pieces:
		if get_repair_refusal(piece) == "":
			return ""
	return get_repair_refusal(pieces[0])

func repair_all(character: CharacterStats, owner = null) -> Dictionary:
	"""Work through everything the character has equipped, a notch at a time and
	the worst piece first, while kits and suitable scrap last. Returns {ok,
	reason, restored (notches), pieces (how many were mended)}."""
	var refusal: String = get_repair_all_refusal(character)
	if refusal != "":
		return {"ok": false, "reason": refusal, "restored": 0, "pieces": 0}
	var restored: int = 0
	var mended: Array = []
	var going: bool = true
	while going:
		going = false
		for piece in get_repairable_pieces(character):
			var result: Dictionary = repair_with_kit(piece, owner)
			if result.ok:
				restored += int(result.restored)
				if not mended.has(piece.get("instance_id", "")):
					mended.append(piece.get("instance_id", ""))
				going = true
				break
	return {"ok": true, "reason": "", "restored": restored, "pieces": mended.size()}

func get_salvage_refusal(item_instance) -> String:
	"""Why an item cannot be salvaged, or "" when it can: a wearing piece from
	the pack"""
	if not wears(item_instance):
		return "Only weapons, shields and armour can be salvaged"
	if InventoryManager.get_item(str(item_instance.get("instance_id", ""))).is_empty():
		return "Take it off first: only what is in the pack can be salvaged"
	return ""

func get_salvage_yield(item_instance) -> int:
	"""Units of scrap a piece gives: more for a body armour or a two-handed weapon"""
	if not wears(item_instance):
		return 0
	var item_data: ItemData = item_instance.item_data
	if get_piece_kind(item_instance) == KIND_BODY or (item_data.is_weapon and item_data.is_two_handed):
		return DurabilityDials.salvage_units_large
	return DurabilityDials.salvage_units

func salvage(item_instance, owner = null) -> Dictionary:
	"""Turn a piece from the pack into scrap of its material. Returns {ok,
	reason, scrap_id, units}."""
	var refusal: String = get_salvage_refusal(item_instance)
	if refusal != "":
		return {"ok": false, "reason": refusal, "scrap_id": "", "units": 0}
	var units: int = get_salvage_yield(item_instance)
	var scrap_id: String = ItemDatabase.scrap_item_id(item_instance.item_data.material.material_id)
	var scrap: Dictionary = ItemDatabase.create_item_instance(scrap_id)
	if scrap.is_empty():
		return {"ok": false, "reason": "Nothing can be made of that", "scrap_id": "", "units": 0}
	scrap["stack_count"] = units
	var piece_name: String = ItemDatabase.get_instance_name(item_instance)
	InventoryManager.remove_item(item_instance.instance_id)
	InventoryManager.add_item_or_drop(scrap)
	_announce("salvage", item_instance, owner, "%s salvaged: %d %s." % [piece_name, units, scrap.item_data.item_name], "success")
	return {"ok": true, "reason": "", "scrap_id": scrap_id, "units": units}

# ============================================================================
# LOOT
# ============================================================================

func wear_looted(item_instance):
	"""Looted gear arrives worn: it has lost, at random, from none to half of its notches"""
	if not wear_enabled or not wears(item_instance):
		return
	_ensure(item_instance)
	var most: int = int(floor(int(item_instance.notches_max) * DurabilityDials.looted_lost_share))
	var lost: int = clampi(int(_roll() * (most + 1)), 0, most)
	item_instance["notches"] = int(item_instance.notches_max) - lost
	if lost > 0:
		_name_wear(item_instance, CAUSE_MARKS)

# ============================================================================
# SAVES (primitives only)
# ============================================================================

func write_primitive(item_instance: Dictionary, primitive: Dictionary):
	"""Add a wearing piece's durability fields to its save form"""
	if not wears(item_instance):
		return
	_ensure(item_instance)
	for key in ["notches", "notches_max", "notches_max_original", "marks", "age"]:
		primitive[key] = int(item_instance[key])
	for key in ["debuffs", "buffs", "wear_names"]:
		var words: Array = []
		for word in item_instance[key]:
			words.append(str(word))
		primitive[key] = words
	for key in ["kills", "caster_kills"]:
		if item_instance.has(key):
			primitive[key] = int(item_instance[key])
	if item_instance.has("kills_by_type"):
		primitive["kills_by_type"] = (item_instance.kills_by_type as Dictionary).duplicate()
	if item_instance.get("ever_broken", false):
		primitive["ever_broken"] = true

func read_primitive(item_instance: Dictionary, data: Dictionary):
	"""Restore a wearing piece's durability fields from its save form. A form
	without them is a whole piece."""
	if not wears(item_instance) or not data.has("notches"):
		return
	_ensure(item_instance)
	var original: int = maxi(1, int(data.get("notches_max_original", item_instance.notches_max_original)))
	item_instance["notches_max_original"] = original
	item_instance["notches_max"] = clampi(int(data.get("notches_max", original)), 1, original)
	item_instance["notches"] = clampi(int(data.get("notches", original)), 0, int(item_instance.notches_max))
	item_instance["marks"] = maxi(0, int(data.get("marks", 0)))
	item_instance["age"] = maxi(0, int(data.get("age", 0)))
	for key in ["debuffs", "buffs", "wear_names"]:
		var words: Array = []
		if data.get(key) is Array:
			for word in data[key]:
				words.append(str(word))
		item_instance[key] = words
	for key in ["kills", "caster_kills"]:
		if data.has(key):
			item_instance[key] = int(data[key])
	if data.get("kills_by_type") is Dictionary:
		var by_type: Dictionary = {}
		for creature in data["kills_by_type"]:
			by_type[str(creature)] = int(data["kills_by_type"][creature])
		item_instance["kills_by_type"] = by_type
	if data.get("ever_broken", false):
		item_instance["ever_broken"] = true

func points_to_notches(item_id: String, quality: int, magic: int, points: int) -> Dictionary:
	"""What an item of the old durability points becomes (save format 4 to 5):
	the durability fields of a wearing piece, with as large a share of its
	notches as it had of its points - whole for a whole piece, and never broken
	while it had a point left. {} for an item that does not wear."""
	var item_data: ItemData = ItemDatabase.get_item(item_id)
	if not wears_item(item_data):
		return {}
	var count: int = get_original_max(item_data, quality, magic)
	# Weapons and armour had points, as many as their material's durability
	# score; the cloaks and belts had none, and are whole
	var old_max: int = item_data.material.durability_score if (item_data.is_weapon or item_data.is_armor) else 0
	var notches: int = count
	if old_max > 0 and points < old_max:
		notches = clampi(int(floor(float(count) * float(maxi(0, points)) / float(old_max) + 0.5)), 1 if points > 0 else 0, count)
	return {"notches": notches, "notches_max": count, "notches_max_original": count, "marks": 0, "age": 0,
		"debuffs": [], "buffs": [], "wear_names": []}

# ============================================================================
# HELPERS
# ============================================================================

func force_rolls(results: Array):
	"""Fix what the next rolls give, in order: numbers from 0.0 up to, not
	including, 1.0. For checks. A critical hit without a shield rolls where it
	lands (below two thirds: the body armour) and then, on another piece, which;
	a magic piece then rolls once for each notch (below its chance: ignored)."""
	_forced_rolls = results.duplicate()

func _roll() -> float:
	"""One roll, from 0.0 up to, not including, 1.0"""
	if not _forced_rolls.is_empty():
		return float(_forced_rolls.pop_front())
	return randf()

func _owner_stats(owner):
	"""The CharacterStats behind an owner given as a combatant or as stats"""
	if owner is CharacterStats:
		return owner
	if is_instance_valid(owner) and owner is Combatant:
		return owner.stats
	return null

func _owner_name(owner) -> String:
	if owner is CharacterStats:
		return str(owner.character_name)
	if is_instance_valid(owner) and owner is Combatant:
		return owner.get_display_name()
	return ""

func _piece_label(item_instance: Dictionary, owner) -> String:
	"""'Aldric's Wrought Iron Shield', or the piece alone when nobody is known to hold it"""
	var piece_name: String = ItemDatabase.get_instance_name(item_instance)
	var owner_name: String = _owner_name(owner)
	return piece_name if owner_name == "" else "%s's %s" % [owner_name, piece_name]

func _refresh_owner(owner):
	"""A piece changed: work its wearer's numbers out again and tell the sheet"""
	var stats = _owner_stats(owner)
	if stats != null and InventoryManager.equipped_items.has(stats):
		InventoryManager.recalculate_character_stats(stats)
		EventBus.equipment_changed.emit(stats)

func _announce_loss(item_instance: Dictionary, owner, notches_lost: int, cause: String, debuffs: Array):
	"""Say that a piece lost notches, what came with them, and whether it broke"""
	if notches_lost <= 0:
		return
	var how: String = "to wear"
	if cause == CAUSE_CRITICAL:
		how = "to a critical hit"
	elif cause == CAUSE_NATURAL_ONE:
		how = "to a natural 1"
	var label: String = _piece_label(item_instance, owner)
	var lost_text: String = "a notch" if notches_lost == 1 else "%d notches" % notches_lost
	if is_broken(item_instance):
		_announce("break", item_instance, owner, "%s loses %s %s and is BROKEN. It gives nothing until it is repaired." % [label, lost_text, how],
			"error", true, {"notches_lost": notches_lost, "cause": cause, "debuffs": debuffs})
		return
	var text: String = "%s loses %s %s: %d of %d left." % [label, lost_text, how, get_notches(item_instance), get_max_notches(item_instance)]
	for debuff in debuffs:
		text += " %s." % get_debuff_text(str(debuff))
	_announce("notch", item_instance, owner, text, "warning", true, {"notches_lost": notches_lost, "cause": cause, "debuffs": debuffs})

func _announce(kind: String, item_instance: Dictionary, owner, text: String, level: String, toast: bool = true, extra: Dictionary = {}):
	"""Tell the combat log, and with toast the player, what happened to a piece.
	The event: {kind ("notch" | "break" | "mark" | "resist" | "buff" | "repair"
	| "age" | "salvage" | "fight"), instance, owner, text, level, ...extra}."""
	var event: Dictionary = {"kind": kind, "instance": item_instance, "owner": owner if (owner is CharacterStats or is_instance_valid(owner)) else null,
		"text": text, "level": level}
	event.merge(extra)
	print("Durability: ", text)
	EventBus.item_wear_event.emit(event)
	if toast:
		EventBus.ui_notification.emit(text, level)
