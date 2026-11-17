# combat_controller.gd
# The one authority for whose turn it is and what may be done with it. A Node
# owned by the World scene.
# It notices when a fight should start, rolls initiative for every combatant in
# it, hands out the turns in order with their resources (movement, action, bonus
# action, reaction), counts rounds, and ends the fight. Whatever a combatant
# wants to do - attack, move, dash, cast, use an item, end its turn - it asks
# for through request_action(); the controller checks the turn and the
# resources, applies the action and reports the result. That includes what it
# holds: swapping weapon sets, and equipping and unequipping outside a fight;
# and mending it: repairing with a kit and salvaging, outside a fight.
# It also tells the durability rules when a fight starts and how long it was.
# Player input, enemy AI and companion AI all come in that way. The HUD (turn
# banner, initiative bar, action bar) only shows what the controller says.
extends Node
class_name CombatController

signal combat_started(combatants: Array)   # the whole initiative order
signal combat_ended(victory: bool)         # victory: the party outlived every hostile in the fight
signal turn_started(combatant: Combatant)
signal turn_ended(combatant: Combatant)
signal round_started(round_number: int)
signal order_changed()                     # someone joined or left the running fight
signal action_taken(combatant: Combatant, action_id: String, result: Dictionary)  # a request was approved and applied

# What a combatant can ask for (request_action)
const ACTION_ATTACK := "attack"
const ACTION_CAST := "cast"
const ACTION_USE_ITEM := "use_item"
const ACTION_DASH := "dash"
const ACTION_DISENGAGE := "disengage"
const ACTION_DODGE := "dodge"
const ACTION_SWAP_WEAPONS := "swap_weapons"
const ACTION_END_TURN := "end_turn"
const ACTION_MOVE := "move"
const ACTION_EQUIP := "equip"
const ACTION_UNEQUIP := "unequip"
const ACTION_REPAIR := "repair"
const ACTION_REPAIR_ALL := "repair_all"
const ACTION_SALVAGE := "salvage"

# The action bar, in the order of its buttons and number keys (1 to 8)
const ACTION_BAR: Array[String] = [
	ACTION_ATTACK, ACTION_CAST, ACTION_USE_ITEM, ACTION_DASH, ACTION_DISENGAGE, ACTION_DODGE, ACTION_SWAP_WEAPONS, ACTION_END_TURN,
]

# Why gear cannot be changed in a fight, nor mended
const REASON_GEAR_IN_FIGHT := "Gear cannot be changed in a fight - swap weapon sets instead"
const REASON_REPAIR_IN_FIGHT := "Gear cannot be repaired or salvaged in a fight"

# Tiles, straight line. A fight starts when a hostile is within detection_range
# of the player; hostiles within activation_range are pulled into it.
var detection_range: int = 10
var activation_range: int = 20

# Pacing of a turn that runs without input (seconds)
const MOVE_POLL: float = 0.1
const MAX_MOVE_POLLS: int = 100
const HOSTILE_TURN_PAUSE: float = 1.3
const PARTY_TURN_PAUSE: float = 0.2
# After the last blow, before the fight is called
const SETTLE_DELAY: float = 1.0

var world = null

var active: bool = false
var round_number: int = 0

# The initiative order (Combatants) and each entry's roll, highest first.
# Untyped on purpose: a body freed without notice must not trip a typed read.
var _order: Array = []
var _rolls: Array[int] = []
# Index in _order of whoever holds the turn. When the turn-holder leaves the
# fight the cursor steps back, so that advancing lands on its successor.
var _cursor: int = 0
var _current = null
# Everyone who took part, dead or alive, for the end-of-combat hook
var _participants: Array = []
# Stale awaits compare against these and give up
var _turn_serial: int = 0
var _combat_serial: int = 0
var _settling: bool = false

func setup(world_node):
	"""Called by the World scene that owns this controller"""
	world = world_node

func _process(_delta):
	if not active:
		_look_for_a_fight()

# ============================================================================
# WHO HOLDS THE TURN
# ============================================================================

func current_combatant() -> Combatant:
	"""Whoever holds the turn, or null between turns and outside combat"""
	return _current if active and is_instance_valid(_current) else null

func is_turn_of(combatant) -> bool:
	"""True only for the combatant that holds the turn in a running fight"""
	return active and combatant != null and combatant == _current

func get_order() -> Array[Combatant]:
	"""The initiative order, highest roll first"""
	var order: Array[Combatant] = []
	for combatant in _order:
		if is_instance_valid(combatant):
			order.append(combatant)
	return order

func get_initiative(combatant) -> int:
	"""The combatant's initiative roll in this fight (0 when it is not in it)"""
	var index = _order.find(combatant)
	return _rolls[index] if index >= 0 else 0

# ============================================================================
# STARTING AND ENDING A FIGHT
# ============================================================================

func start_combat(participants: Array) -> bool:
	"""Begin a fight between the given combatants: roll initiative for each,
	sort, and hand out the first turn. Refused when a fight is already running
	or the group holds no two living combatants hostile to each other."""
	if active:
		return false

	var entrants: Array = []
	for combatant in participants:
		if _is_fit(combatant) and not entrants.has(combatant):
			entrants.append(combatant)
	if not _has_opposing_sides(entrants):
		return false

	var seats: Array = []
	for combatant in entrants:
		seats.append({"combatant": combatant, "roll": CombatManager.roll_initiative(combatant.stats), "seat": seats.size()})
	# Highest roll first; a tie keeps the order the group was given in
	seats.sort_custom(func(a, b): return a.roll > b.roll or (a.roll == b.roll and a.seat < b.seat))

	_order.clear()
	_rolls.clear()
	for seat in seats:
		_order.append(seat.combatant)
		_rolls.append(seat.roll)

	active = true
	GameManager.in_combat = true
	_combat_serial += 1
	_settling = false
	round_number = 1
	_cursor = 0
	_current = null
	_participants = _order.duplicate()
	DurabilityManager.begin_fight()

	print("⚔️ COMBAT INITIATED!")
	print("=== INITIATIVE ORDER ===")
	for i in range(_order.size()):
		print("%d. %s (Initiative: %d)" % [i + 1, _order[i].name, _rolls[i]])

	# Everyone starts the fight with nothing spent, reaction included
	for combatant in _order:
		combatant.on_combat_started()

	combat_started.emit(get_order())
	EventBus.combat_started.emit(_order.filter(func(c): return c.team == Combatant.Team.HOSTILE))
	round_started.emit(round_number)

	_begin_turn()
	return true

func end_combat():
	"""Stop the fight now. Does nothing when none is running."""
	if not active:
		return

	var victory = _team_alive(Combatant.Team.PARTY) and not _team_alive(Combatant.Team.HOSTILE)

	active = false
	GameManager.in_combat = false
	_turn_serial += 1
	_settling = false
	_current = null
	var took_part: Array = _participants.duplicate()
	_order.clear()
	_rolls.clear()
	_participants.clear()

	# What was used in the fight wears by how long it lasted
	DurabilityManager.end_fight(round_number)

	for combatant in took_part:
		if is_instance_valid(combatant):
			combatant.on_combat_ended()

	combat_ended.emit(victory)
	EventBus.combat_ended.emit(victory)
	print("⚔️ COMBAT ENDED")

func add_combatant(combatant: Combatant) -> bool:
	"""Bring a latecomer into the running fight. It rolls initiative and takes
	its place in the order; whose turn it is does not change."""
	if not active or not _is_fit(combatant) or _order.has(combatant):
		return false

	var roll: int = CombatManager.roll_initiative(combatant.stats)
	var at: int = _order.size()
	for i in range(_order.size()):
		if _rolls[i] < roll:
			at = i
			break
	_order.insert(at, combatant)
	_rolls.insert(at, roll)
	if at <= _cursor:
		_cursor += 1
	_participants.append(combatant)

	combatant.on_combat_started()
	order_changed.emit()
	return true

func remove_combatant(combatant):
	"""Take a combatant out of the fight (it died or left). Whose turn it is
	does not change. If it was this one's turn, the turn passes to its successor
	when the running turn winds up - nobody is skipped."""
	var index = _order.find(combatant)
	if index < 0:
		return
	_remove_at(index)
	order_changed.emit()
	if active and not _fight_is_live():
		_end_when_settled()

func _look_for_a_fight():
	"""A fight starts when a living hostile comes within detection range of the player"""
	if world == null:
		return
	var leader = world.player
	if not is_instance_valid(leader) or not leader.is_alive():
		return
	var leader_pos: Vector2i = leader.get_grid_position()
	for hostile in leader.get_hostiles():
		if leader_pos.distance_to(hostile.get_grid_position()) <= detection_range:
			start_combat(_participants_around(leader))
			return

func _participants_around(leader: Combatant) -> Array[Combatant]:
	"""The leader, everyone alive on the leader's side, and the hostiles near enough"""
	var group: Array[Combatant] = [leader]
	var leader_pos: Vector2i = leader.get_grid_position()
	for other in world.get_combatants():
		if other == leader or not other.is_alive():
			continue
		if not leader.is_hostile_to(other) or leader_pos.distance_to(other.get_grid_position()) <= activation_range:
			group.append(other)
	return group

func _end_when_settled():
	"""Only one side is left standing: let the last blow land, then end the fight"""
	if _settling:
		return
	_settling = true
	print("Combat: only one side is left standing")
	var serial = _combat_serial
	await _timer(SETTLE_DELAY).timeout
	if active and serial == _combat_serial:
		end_combat()

# ============================================================================
# THE TURN LOOP
# ============================================================================

func _begin_turn():
	"""Hand the turn to the combatant under the cursor, with a fresh set of
	turn resources. A player-controlled combatant keeps the turn until it asks
	to end it; anyone else acts through take_turn() and the turn winds up by
	itself."""
	if not active:
		return
	if not _fight_is_live():
		_current = null
		_end_when_settled()
		return

	_turn_serial += 1
	var serial = _turn_serial
	var combatant = _order[_cursor]
	_current = combatant
	combatant.refresh_turn_resources()

	turn_started.emit(combatant)
	EventBus.turn_started.emit(combatant)
	if not _turn_is_live(serial):
		return

	if combatant.is_player_controlled():
		combatant.start_new_turn()
		return

	combatant.take_turn()

	# The waits are pause-bound, so the fight freezes while a menu is open. The
	# body may be freed mid-turn (dungeon regenerated, companion dismissed).
	var polls = 0
	while _turn_is_live(serial) and is_instance_valid(combatant) and combatant.is_moving and polls < MAX_MOVE_POLLS:
		await _timer(MOVE_POLL).timeout
		polls += 1
	if not _turn_is_live(serial):
		return

	var pause = HOSTILE_TURN_PAUSE
	if is_instance_valid(combatant) and combatant.team == Combatant.Team.PARTY:
		pause = PARTY_TURN_PAUSE
	await _timer(pause).timeout
	if not _turn_is_live(serial):
		return

	_finish_turn()

func _finish_turn():
	"""Close the running turn and start the next one"""
	var ended = _current
	_current = null
	if is_instance_valid(ended):
		ended.expire_turn_resources()
		turn_ended.emit(ended)
		EventBus.turn_ended.emit(ended)
	if not active:
		return
	_advance()
	_begin_turn()

func _advance():
	"""Move the cursor to the next living combatant. Passing the end of the
	order starts a new round."""
	for i in range(_order.size() - 1, -1, -1):
		if not _is_fit(_order[i]):
			_remove_at(i)
	if _order.is_empty():
		return

	_cursor += 1
	if _cursor >= _order.size():
		_cursor = 0
		round_number += 1
		round_started.emit(round_number)

func _remove_at(index: int):
	"""Drop one entry and keep the cursor on the same combatant. Dropping the
	turn-holder itself leaves the cursor just before its successor."""
	var removed = _order[index]
	_order.remove_at(index)
	_rolls.remove_at(index)
	if index <= _cursor:
		_cursor -= 1
	if removed == _current:
		_current = null

# ============================================================================
# ACTIONS (what a combatant asks for; see ACTION_* above)
# ============================================================================
#
# request_action(combatant, action_id, params) -> {ok, action, reason, ...}
#
#   attack     {target: Combatant}      one attack on a hostile with the weapon
#                                       set in hand: a melee weapon on a target
#                                       in reach, a ranged weapon on one in
#                                       range and in sight. Costs the action.
#   swap_weapons {}                     take the other weapon set in hand. Costs
#                                       the action in a fight; free outside one.
#   dash       {}                       adds the combatant's speed to this turn's
#                                       movement. Costs the action.
#   disengage  {}                       its movement provokes no opportunity
#                                       attack for the rest of the turn. Action.
#   dodge      {}                       until its next turn starts, attacks on it
#                                       have disadvantage and it makes Dexterity
#                                       saves with advantage. Action.
#   cast       {spell_id, target}       target is a Combatant or a tile, as the
#                                       spell wants. Costs what the spell's
#                                       casting_time says.
#   use_item   {item: instance}         a potion, scroll or wand from the pack.
#                                       Costs the action.
#   move       {path: Array[Vector2i]}  walk the tiles, from the combatant's own.
#                                       Costs a tile of movement for each.
#   end_turn   {}
#   equip      {item: instance, slot}   put an item from the pack in an equipment
#              (+ from_slot)            slot; with from_slot, move a weapon or
#                                       shield between the weapon sets instead.
#                                       Refused in a fight.
#   unequip    {slot} (+ item)          back to the pack; item names which ring
#                                       or trinket. Refused in a fight.
#   repair     {item: instance}         mend one notch of a piece the combatant
#                                       has equipped or the pack holds, with a
#                                       repair kit and a unit of scrap from the
#                                       pack. Refused in a fight.
#   repair_all {}                       the same for everything the combatant
#                                       has equipped, the worst piece first,
#                                       while kits and scrap last. Refused in a
#                                       fight.
#   salvage    {item: instance}         turn a weapon or a piece of armour from
#                                       the pack into scrap. Refused in a fight.
#
# In a fight a request is approved only on the combatant's own turn, and the
# action, bonus action and movement it costs must still be there. Outside a
# fight nothing is spent and there is no turn to wait for; Attack, Dash,
# Disengage and Dodge are then refused, as there is no turn to take them in.
# Gear is the other way round: in a fight the only way to change what is in
# hand is swap_weapons, and equip, unequip, repair, repair_all and salvage are
# refused.

func check_action(combatant, action_id: String, params: Dictionary = {}) -> Dictionary:
	"""Would request_action() be approved right now? Returns {ok, reason} and
	changes nothing. Without a target, spell or item in params it answers the
	action bar's question: is this action available at all?"""
	if not _is_fit(combatant):
		return _refuse("Cannot act")
	if active and action_id in [ACTION_EQUIP, ACTION_UNEQUIP]:
		return _refuse(REASON_GEAR_IN_FIGHT, true)
	if active and action_id in [ACTION_REPAIR, ACTION_REPAIR_ALL, ACTION_SALVAGE]:
		return _refuse(REASON_REPAIR_IN_FIGHT, true)
	if active and not is_turn_of(combatant):
		return _refuse("Not your turn")
	match action_id:
		ACTION_ATTACK:
			return _check_attack(combatant, params)
		ACTION_SWAP_WEAPONS:
			return _check_swap(combatant)
		ACTION_EQUIP:
			return _check_equip(combatant, params)
		ACTION_UNEQUIP:
			return _check_unequip(combatant, params)
		ACTION_REPAIR:
			return _check_repair(combatant, params)
		ACTION_REPAIR_ALL:
			return _check_gear_answer(DurabilityManager.get_repair_all_refusal(combatant.stats))
		ACTION_SALVAGE:
			return _check_salvage(params)
		ACTION_DASH, ACTION_DISENGAGE, ACTION_DODGE:
			return _check_fight_action(combatant)
		ACTION_CAST:
			return _check_cast(combatant, params)
		ACTION_USE_ITEM:
			return _check_use_item(combatant, params)
		ACTION_MOVE:
			return _check_move(combatant, params)
		ACTION_END_TURN:
			return _check_end_turn(combatant)
	return _refuse("Unknown action '%s'" % action_id)

func request_action(combatant, action_id: String, params: Dictionary = {}) -> Dictionary:
	"""The one way anything is done with a turn. Checks that it is the
	combatant's turn, that it still has what the action costs and that the
	action is legal; then applies it and returns what happened:
	{ok, action, reason} plus what the action adds (an attack's roll and
	damage, a cast's result, the movement a Dash gave). A refused request
	changes nothing and says why in reason."""
	var result: Dictionary = check_action(combatant, action_id, params)
	result["action"] = action_id
	if not result.ok:
		return result

	match action_id:
		ACTION_ATTACK:
			_apply_attack(combatant, params, result)
		ACTION_DASH:
			combatant.action_used = true
			var extra: int = combatant.get_turn_speed()
			combatant.add_movement(extra)
			result["movement_added"] = extra
			print("%s dashes: %d more tiles of movement" % [combatant.name, extra])
		ACTION_DISENGAGE:
			combatant.action_used = true
			combatant.disengaged = true
			print("%s disengages" % combatant.name)
		ACTION_DODGE:
			combatant.action_used = true
			combatant.dodging = true
			print("%s dodges" % combatant.name)
		ACTION_SWAP_WEAPONS:
			if active:
				combatant.action_used = true
			result["weapon_set"] = combatant.swap_weapon_set()
			result["weapon_name"] = str(CombatManager.get_attack_profile(combatant).weapon_name)
			print("%s swaps to weapon set %d (%s)" % [combatant.name, int(result.weapon_set), str(result.weapon_name)])
		ACTION_EQUIP:
			_apply_equip(combatant, params, result)
		ACTION_UNEQUIP:
			_apply_unequip(combatant, params, result)
		ACTION_REPAIR:
			_apply_gear_result(result, DurabilityManager.repair_with_kit(params["item"], combatant))
		ACTION_REPAIR_ALL:
			_apply_gear_result(result, DurabilityManager.repair_all(combatant.stats, combatant))
		ACTION_SALVAGE:
			_apply_gear_result(result, DurabilityManager.salvage(params["item"], combatant))
		ACTION_CAST:
			_apply_cast(combatant, params, result)
		ACTION_USE_ITEM:
			_apply_use_item(combatant, params, result)
		ACTION_MOVE:
			result["steps"] = params["path"].size() - 1
			combatant.follow_path(params["path"])
		ACTION_END_TURN:
			# Announced first: ending the turn starts the next one
			action_taken.emit(combatant, action_id, result)
			if active:
				_finish_turn()
			return result

	if result.ok:
		action_taken.emit(combatant, action_id, result)
	return result

func get_attack_targets(combatant) -> Array[Combatant]:
	"""The living hostiles the combatant could attack from where it stands with
	the weapon set in hand: in reach of a melee weapon, or within the range of a
	ranged one and in its line of sight. About position and weapons only;
	whether it has the turn and the action is check_action's to say."""
	var targets: Array[Combatant] = []
	if not _is_fit(combatant):
		return targets
	for hostile in combatant.get_hostiles():
		if _check_attack_target(combatant, hostile).ok:
			targets.append(hostile)
	return targets

func preview_attack(combatant, target) -> Dictionary:
	"""What attacking the target would be, for showing before the player
	commits. Changes nothing and rolls nothing.
	Returns {ok, reason} as check_action answers the attack, and with them
	{target, profile (the weapon that would be used, see
	CombatManager.build_attack_profile), weapon_name, damage_text, distance,
	hit_chance (CombatManager.get_hit_chance: chance, percent, advantage,
	disadvantage, reasons, cover_bonus, ...), damage_response (what the target's
	nature would do to the damage: CombatManager.get_damage_response),
	wear_notes (what the weapon's lost notches, debuffs and buffs and the
	target's torn or breached gear do to the attack, as lines to show:
	DurabilityManager.get_attack_notes)}."""
	var preview: Dictionary = check_action(combatant, ACTION_ATTACK, {"target": target})
	if not _is_fit(combatant) or not _is_fit(target):
		return preview
	var profile: Dictionary = CombatManager.get_attack_profile(combatant)
	preview["target"] = target
	preview["profile"] = profile
	preview["weapon_name"] = str(profile.weapon_name)
	preview["damage_text"] = CombatManager.get_damage_text(profile)
	preview["distance"] = CombatGrid.get_distance_tiles(combatant.get_grid_position(), target.get_grid_position())
	preview["hit_chance"] = CombatManager.get_hit_chance(combatant, target, profile)
	preview["damage_response"] = CombatManager.get_damage_response(target, str(profile.damage_type))
	preview["wear_notes"] = DurabilityManager.get_attack_notes(profile.weapon_instance, target)
	return preview

# --- checks ---

func _approve() -> Dictionary:
	return {"ok": true, "reason": ""}

func _refuse(reason: String, final: bool = false) -> Dictionary:
	"""final: asking again with another target would not help either"""
	var refusal: Dictionary = {"ok": false, "reason": reason}
	if final:
		refusal["final"] = true
	return refusal

func _check_fight_action(combatant) -> Dictionary:
	"""What Attack, Dash, Disengage and Dodge share: taken in a fight, by a
	combatant that is able and standing still, with its action"""
	if not active:
		return _refuse("Not in combat")
	if StatusEffectManager.is_incapacitated(combatant):
		return _refuse("Incapacitated")
	if combatant.is_moving:
		return _refuse("Still moving")
	if combatant.action_used:
		return _refuse("Action spent")
	return _approve()

func _check_attack(combatant, params: Dictionary) -> Dictionary:
	var check: Dictionary = _check_fight_action(combatant)
	if not check.ok:
		return check
	if params.has("target"):
		return _check_attack_target(combatant, params["target"])

	# No target named: is there anyone this combatant could attack right now?
	if not get_attack_targets(combatant).is_empty():
		return _approve()
	var profile: Dictionary = CombatManager.get_attack_profile(combatant)
	var nobody: String = "No enemy in range and in sight" if profile.is_ranged else "No enemy in reach"
	if not profile.usable:
		# A two-handed weapon beside a full off hand, or a broken weapon
		nobody = str(profile.reason)
	for hostile in combatant.get_hostiles():
		var swap: String = _swap_advice(combatant, hostile)
		if swap != "":
			return _refuse("%s - %s" % [nobody, swap])
	return _refuse(nobody)

func _check_attack_target(combatant, target) -> Dictionary:
	"""Can the combatant attack this target from where it stands, with the
	weapon set it has in hand? A hostile, and in reach of a melee weapon (or an
	unarmed strike), or within the maximum range of a ranged weapon and in its
	line of sight. A refusal says what would help when the other weapon set
	could do it ("Out of reach - swap to the Oak Light Crossbow"). Says nothing
	about the turn or the action."""
	if not _is_fit(target) or not combatant.is_hostile_to(target):
		return _refuse("Not an enemy")
	var check: Dictionary = _check_attack_with(combatant, target, CombatManager.get_attack_profile(combatant))
	if not check.ok:
		var swap: String = _swap_advice(combatant, target)
		if swap != "":
			check["reason"] = "%s - %s" % [str(check.reason).get_slice(" - ", 0), swap]
	return check

func _check_attack_with(combatant, target, profile: Dictionary) -> Dictionary:
	"""Could an attack with this profile be made on the target from where the
	combatant stands: usable, and in reach, or in range and in sight?"""
	var from: Vector2i = combatant.get_grid_position()
	var to: Vector2i = target.get_grid_position()
	var distance: int = CombatGrid.get_distance_tiles(from, to)
	if not profile.usable:
		return _refuse(str(profile.reason))
	if not profile.is_ranged:
		if distance > CombatManager.MELEE_REACH:
			return _refuse("Out of reach - a melee attack needs an adjacent enemy")
		return _approve()
	if distance > int(profile.range_max):
		return _refuse("Out of range - %s reaches %d tiles" % [str(profile.weapon_name), int(profile.range_max)])
	# Out of sight: a wall on the straight line between the two, or every line
	# from the attacker's tile to the corners of the target's blocked
	var grid: Array = _dungeon_grid()
	if not grid.is_empty() and (not CombatGrid.has_line_of_sight(from, to, grid) or not CombatGrid.get_cover(from, to, grid).line_of_sight):
		return _refuse("No line of sight")
	return _approve()

func _swap_advice(combatant, target) -> String:
	"""'swap to the Oak Light Crossbow' when the combatant's other weapon set
	could attack the target from here; "" when it could not, or there is none.
	Empty hands are worth a swap only when the weapon in hand is broken."""
	if combatant.get_weapon_set_count() < 2:
		return ""
	var other: Dictionary = CombatManager.get_set_profile(combatant, combatant.get_other_weapon_set())
	if not _check_attack_with(combatant, target, other).ok:
		return ""
	if other.weapon == null:
		var in_hand: Dictionary = CombatManager.get_attack_profile(combatant)
		return "swap to your empty hands" if DurabilityManager.is_broken(in_hand.weapon_instance) else ""
	return "swap to the %s" % str(other.weapon_name)

func _check_swap(combatant) -> Dictionary:
	"""Taking the other weapon set in hand: the action in a fight, free outside one"""
	if combatant.get_weapon_set_count() < 2:
		return _refuse("No second weapon set", true)
	if combatant.is_weapon_set_empty(1) and combatant.is_weapon_set_empty(2):
		return _refuse("Both weapon sets are empty", true)
	if StatusEffectManager.is_incapacitated(combatant):
		return _refuse("Incapacitated")
	if active:
		if combatant.is_moving:
			return _refuse("Still moving")
		if combatant.action_used:
			return _refuse("Action spent")
	return _approve()

func _check_equip(combatant, params: Dictionary) -> Dictionary:
	"""Outside a fight: does the item belong in the slot? (In a fight the
	request never gets this far.)"""
	var item = params.get("item")
	var slot: String = str(params.get("slot", ""))
	if not (item is Dictionary) or not (item.get("item_data") is ItemData) or slot == "":
		return _refuse("Nothing to equip", true)
	var from_slot: String = str(params.get("from_slot", ""))
	var refusal: String = ""
	if from_slot != "":
		refusal = InventoryManager.get_move_refusal(combatant.stats, from_slot, slot)
	elif InventoryManager.get_item(str(item.get("instance_id", ""))).is_empty():
		refusal = "That is not in the pack"
	else:
		refusal = InventoryManager.get_equip_refusal(item, combatant.stats, slot)
	return _approve() if refusal == "" else _refuse(refusal, true)

func _check_unequip(combatant, params: Dictionary) -> Dictionary:
	var slot: String = str(params.get("slot", ""))
	var held = InventoryManager.equipped_items.get(combatant.stats, {}).get(slot)
	if held == null or (held is Array and not held.has(params.get("item"))):
		return _refuse("Nothing is equipped there", true)
	return _approve()

func _check_repair(combatant, params: Dictionary) -> Dictionary:
	"""Outside a fight: is the piece the combatant's to mend - equipped by it or
	in the party's pack - and can a kit mend it now?"""
	var item = params.get("item")
	if not (item is Dictionary) or not (item.get("item_data") is ItemData):
		return _refuse("Nothing to repair", true)
	var held: bool = false
	for equipped in InventoryManager.get_all_equipped_items(combatant.stats):
		if is_same(equipped, item):
			held = true
	if not held and InventoryManager.get_item(str(item.get("instance_id", ""))).is_empty():
		return _refuse("That is not yours to repair", true)
	return _check_gear_answer(DurabilityManager.get_repair_refusal(item))

func _check_salvage(params: Dictionary) -> Dictionary:
	"""Outside a fight: is it a weapon or a piece of armour from the pack?"""
	var item = params.get("item")
	if not (item is Dictionary) or not (item.get("item_data") is ItemData):
		return _refuse("Nothing to salvage", true)
	return _check_gear_answer(DurabilityManager.get_salvage_refusal(item))

func _check_gear_answer(refusal: String) -> Dictionary:
	"""Approve, or refuse with what the durability rules say stands in the way"""
	return _approve() if refusal == "" else _refuse(refusal, true)

func _check_cast(combatant, params: Dictionary) -> Dictionary:
	if combatant.is_moving:
		return _refuse("Still moving")
	var spell_id: String = str(params.get("spell_id", ""))
	if spell_id == "":
		if not SpellManager.is_caster(combatant.stats):
			return _refuse("No spells known")
		if active and combatant.action_used and combatant.bonus_action_used:
			return _refuse("Action and bonus action spent")
		return _approve()

	var spell: Dictionary = SpellDatabase.get_spell(spell_id)
	if spell.is_empty():
		return _refuse("Unknown spell", true)
	var casting_time: String = str(spell.get("casting_time", "action"))
	if casting_time == "reaction":
		return _refuse("%s is a reaction: it cannot be cast on your own turn yet" % str(spell.get("display_name", spell_id)), true)
	if active:
		if casting_time == "bonus_action":
			if combatant.bonus_action_used:
				return _refuse("Bonus action spent")
		elif combatant.action_used:
			return _refuse("Action spent")
	var castable: Dictionary = SpellManager.can_cast(combatant, spell_id)
	if not castable.get("ok", false):
		return _refuse(str(castable.get("reason", "Cannot cast")), true)
	if params.has("target"):
		return _check_cast_target(combatant, spell, params["target"])
	return _approve()

func _check_cast_target(caster, spell: Dictionary, target) -> Dictionary:
	"""Is the target the kind the spell wants, in range and in sight?"""
	var target_type: String = str(spell.get("target_type", "enemy"))
	var target_tile: Vector2i
	match target_type:
		"enemy":
			if not _is_fit(target) or not caster.is_hostile_to(target):
				return _refuse("No enemy there")
			target_tile = target.get_grid_position()
		"ally", "self":
			if not is_instance_valid(target) or not (target is Combatant) or caster.is_hostile_to(target):
				return _refuse("Not an ally")
			target_tile = target.get_grid_position()
		_:
			if not (target is Vector2i):
				return _refuse("That spell is aimed at a place")
			target_tile = target

	# Outside a fight only spells on oneself or an ally (heals, buffs) are cast
	if not active and target_type in ["enemy", "point"]:
		return _refuse("That spell needs a combat target.")

	# Range and line of sight (range_tiles 0 = the caster's own tile only)
	var from: Vector2i = caster.get_grid_position()
	if target_tile != from:
		if CombatGrid.get_distance_tiles(from, target_tile) > int(spell.get("range_tiles", 0)):
			return _refuse("Out of range!")
		var grid: Array = _dungeon_grid()
		if not grid.is_empty() and not CombatGrid.has_line_of_sight(from, target_tile, grid):
			return _refuse("No line of sight!")
	return _approve()

func _check_use_item(combatant, params: Dictionary) -> Dictionary:
	if active and combatant.action_used:
		return _refuse("Action spent")
	if StatusEffectManager.is_incapacitated(combatant):
		return _refuse("Incapacitated")
	if not params.has("item"):
		return _approve()

	var item = params["item"]
	if not (item is Dictionary) or InventoryManager.get_item(str(item.get("instance_id", ""))).is_empty():
		return _refuse("That is not in the pack")
	var item_data = item.get("item_data")
	if not (item_data is ItemData):
		return _refuse("That cannot be used")
	var prefix: String = _spell_item_prefix(item_data)
	if prefix != "":
		# A scroll or a wand casts the spell it holds
		var spell: Dictionary = SpellDatabase.get_spell(str(item_data.item_id).substr(prefix.length()))
		if spell.is_empty():
			return _refuse("Nothing happens...")
		if str(spell.get("target_type", "enemy")) in ["enemy", "point"]:
			return _refuse("That must be aimed at a target, which cannot be done from the pack yet.")
		return _approve()
	if item_data.is_consumable:
		return _approve()
	return _refuse("%s cannot be used" % item_data.item_name)

func _check_move(combatant, params: Dictionary) -> Dictionary:
	var path = params.get("path")
	if not (path is Array) or path.size() < 2:
		return _refuse("Nowhere to go")
	if combatant.is_moving:
		return _refuse("Already moving")
	if StatusEffectManager.is_incapacitated(combatant):
		return _refuse("Incapacitated")
	if path[0] != combatant.get_grid_position():
		return _refuse("That path starts somewhere else")
	for i in range(1, path.size()):
		if not (path[i] is Vector2i) or CombatGrid.get_distance_tiles(path[i - 1], path[i]) != 1 or not combatant.is_walkable(path[i]):
			return _refuse("The way is blocked")
	var steps: int = path.size() - 1
	if combatant.is_taking_turns() and steps > combatant.movement_left:
		return _refuse("Not enough movement: %d tiles needed, %d left" % [steps, combatant.movement_left])
	return _approve()

func _check_end_turn(combatant) -> Dictionary:
	if not combatant.is_taking_turns():
		return _refuse("Not in combat")
	if combatant.is_moving:
		return _refuse("Still moving")
	return _approve()

# --- applying an approved request ---

func _apply_attack(combatant, params: Dictionary, result: Dictionary):
	"""Spend the action and resolve the attack at once, with the weapon set in
	hand: the roll and the damage. The number over the target's
	head follows at once for a melee attack, and when the projectile lands for
	a ranged one."""
	if not params.has("target"):
		result["ok"] = false
		result["reason"] = "No target given"
		return
	var target = params["target"]
	combatant.action_used = true
	var attack: Dictionary = CombatManager.make_attack(combatant, target, CombatManager.get_attack_profile(combatant))
	if attack.is_empty():
		result["ok"] = false
		result["reason"] = "The attack could not be made"
		return
	result.merge(attack)
	result["target"] = target
	_present_attack(combatant, target, attack)
	# A shot reaches further than the fight was drawn: whoever is attacked is
	# in it from then on
	add_combatant(target)

func _apply_equip(combatant, params: Dictionary, result: Dictionary):
	"""Put an item from the pack in a slot, or move one between the weapon sets"""
	var slot: String = str(params.get("slot", ""))
	var from_slot: String = str(params.get("from_slot", ""))
	var done: bool = false
	if from_slot != "":
		done = InventoryManager.move_equipped_item(combatant.stats, from_slot, slot)
	else:
		done = InventoryManager.equip_item(params["item"], combatant.stats, slot)
	if not done:
		result["ok"] = false
		result["reason"] = "There is no room in the pack for what was there"

func _apply_unequip(combatant, params: Dictionary, result: Dictionary):
	"""Take an item off and put it in the pack"""
	var item = params.get("item")
	var taken: Dictionary = InventoryManager.unequip_item(combatant.stats, str(params.get("slot", "")), item if item is Dictionary else {})
	if taken.is_empty():
		result["ok"] = false
		result["reason"] = "There is no room in the pack"

func _apply_gear_result(result: Dictionary, outcome: Dictionary):
	"""Put what a repair or a salvage did into the request's result"""
	result.merge(outcome, true)

func _apply_cast(combatant, params: Dictionary, result: Dictionary):
	"""Cast the spell through SpellManager and spend what its casting time costs"""
	var spell_id: String = str(params.get("spell_id", ""))
	if spell_id == "" or not params.has("target"):
		result["ok"] = false
		result["reason"] = "No spell or target given"
		return
	var was_fighting: bool = active
	var cast: Dictionary = SpellManager.cast_spell(combatant, spell_id, params["target"])
	if not cast.get("ok", false):
		result["ok"] = false
		result["reason"] = str(cast.get("reason", "The spell fizzles."))
		result["final"] = true
		return
	if was_fighting:
		if str(SpellDatabase.get_spell(spell_id).get("casting_time", "action")) == "bonus_action":
			combatant.bonus_action_used = true
		else:
			combatant.action_used = true
	result["cast"] = cast

	# A teleport (misty step) moves the caster to the tile it named
	var teleport_to = cast.get("teleport_to")
	if teleport_to is Vector2i and is_instance_valid(combatant) and combatant.teleport_to_grid(teleport_to):
		combatant.on_tile_entered()
	_present_cast(cast)

func _apply_use_item(combatant, params: Dictionary, result: Dictionary):
	"""Use a potion, scroll or wand from the pack; in a fight that is the action"""
	if not params.has("item"):
		result["ok"] = false
		result["reason"] = "No item given"
		return
	var item: Dictionary = params["item"]
	var item_data: ItemData = item.get("item_data")
	var was_fighting: bool = active
	var used: bool = false
	var reason: String = ""
	# Scrolls are flagged consumable too: the spell items are sorted out first
	match _spell_item_prefix(item_data):
		"scroll_":
			var cast: Dictionary = SpellManager.use_scroll(item, combatant, null)
			used = cast.get("ok", false)
			reason = str(cast.get("reason", ""))
			result["cast"] = cast
		"wand_":
			var cast: Dictionary = SpellManager.use_wand(item, combatant, null)
			used = cast.get("ok", false)
			reason = str(cast.get("reason", ""))
			result["cast"] = cast
		_:
			used = ItemDatabase.use_consumable(item, combatant)
	if not used:
		result["ok"] = false
		result["reason"] = reason if reason != "" else "Nothing happens..."
		return
	if was_fighting and is_instance_valid(combatant):
		combatant.action_used = true
	print("%s uses %s" % [combatant.name, item_data.item_name])

func _present_attack(attacker, target, attack: Dictionary):
	"""Show an attack that has been resolved. Melee: the lunge, and the damage
	or the miss over the target. Ranged: a projectile from the attacker to the
	target, and the damage or the miss when it lands."""
	if world == null or not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	if attack.hit:
		var response: String = str(attack.get("damage_response", ""))
		print("%s %s %s with %s for %d %s damage%s" % [attacker.name, "CRITS" if attack.is_crit else "hits",
			target.name, attack.weapon_name, attack.damage, attack.damage_type, (" (%s)" % response) if response != "" else ""])
	else:
		print("%s misses %s with %s (rolled %d vs AC %d)" % [attacker.name, target.name, attack.weapon_name,
			attack.total, attack.target_ac])

	# Where the number goes is fixed now: the target may be gone when the shot lands
	var popup_pos: Vector2 = target.global_position + Vector2(0, -attacker.tile_size * 0.8)
	if attack.get("is_ranged", false):
		Projectile.launch(world, attacker.global_position, target.global_position, _show_attack_outcome.bind(popup_pos, attack))
	else:
		attacker.animate_attack(target.global_position)
		_show_attack_outcome(popup_pos, attack)

func _show_attack_outcome(popup_pos: Vector2, attack: Dictionary):
	"""The floating number of a hit, or the word for a miss"""
	if world == null or not is_instance_valid(world):
		return
	if attack.hit:
		DamagePopup.spawn_damage_popup_at(world, popup_pos, attack.damage, attack.is_crit, str(attack.get("damage_response", "")))
	else:
		DamagePopup.spawn_miss_popup_at(world, popup_pos)

func _present_cast(cast: Dictionary):
	"""Floating numbers for what a spell did to each of its targets"""
	if world == null:
		return
	for entry in cast.get("hits", []):
		var target = entry.get("target", null)
		if target == null or not (target is Node2D) or not is_instance_valid(target):
			continue
		var popup_pos: Vector2 = target.global_position + Vector2(0, -ArtLibrary.TILE_SIZE * 0.8)
		var damage: int = int(entry.get("damage", 0))
		var healed: int = int(entry.get("healed", 0))
		var response: String = str(entry.get("response", ""))
		if damage > 0 or response != "":
			DamagePopup.spawn_damage_popup_at(world, popup_pos, damage, bool(entry.get("is_crit", false)), response)
		elif healed > 0:
			DamagePopup.spawn_heal_popup_at(world, popup_pos, healed)
		elif not entry.get("hit", true):
			DamagePopup.spawn_miss_popup_at(world, popup_pos)

func _spell_item_prefix(item_data: ItemData) -> String:
	"""'scroll_' or 'wand_' for an item that casts a spell, '' for anything else"""
	var item_id: String = str(item_data.item_id)
	for prefix in ["scroll_", "wand_"]:
		if item_id.begins_with(prefix):
			return prefix
	return ""

func _dungeon_grid() -> Array:
	"""The dungeon's [y][x] tile grid, or [] when there is none to look at"""
	if world != null and is_instance_valid(world.current_dungeon):
		return world.current_dungeon.dungeon_grid
	return []

# ============================================================================
# HELPERS
# ============================================================================

func _timer(seconds: float) -> Timer:
	"""A one-shot timer to await (`await _timer(1.0).timeout`): game time, which
	stands still while the game is paused. It is a child node on purpose: it
	goes when the controller goes, and the wait with it. A wait on
	get_tree().create_timer(), or on a coroutine of the controller's own, is
	never released when the controller is freed in the middle of it - the
	engine reports the timer or the suspended function as leaked at exit."""
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.001)
	timer.autostart = true
	timer.timeout.connect(timer.queue_free)
	add_child(timer)
	return timer

func _turn_is_live(serial: int) -> bool:
	"""False once the fight has ended or another turn has begun"""
	return active and serial == _turn_serial

func _is_fit(combatant) -> bool:
	"""A combatant that exists and can still fight"""
	return is_instance_valid(combatant) and combatant is Combatant and combatant.is_alive()

func _fight_is_live() -> bool:
	"""True while the order still holds two living combatants hostile to each other"""
	return _has_opposing_sides(_order)

func _has_opposing_sides(group: Array) -> bool:
	var first = null
	for combatant in group:
		if not _is_fit(combatant):
			continue
		if first == null:
			first = combatant
		elif combatant.is_hostile_to(first):
			return true
	return false

func _team_alive(team: Combatant.Team) -> bool:
	for combatant in _order:
		if _is_fit(combatant) and combatant.team == team:
			return true
	return false
