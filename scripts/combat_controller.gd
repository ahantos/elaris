# combat_controller.gd
# The one authority for whose turn it is. A Node owned by the World scene.
# It notices when a fight should start, rolls initiative for every combatant in
# it, hands out the turns in order, counts rounds, and ends the fight. Combatants
# ask it before they act; the HUD (turn banner, initiative bar) only shows what
# it says. What a combatant does with its turn is the combatant's own business.
extends Node
class_name CombatController

signal combat_started(combatants: Array)   # the whole initiative order
signal combat_ended(victory: bool)         # victory: the party outlived every hostile in the fight
signal turn_started(combatant: Combatant)
signal turn_ended(combatant: Combatant)
signal round_started(round_number: int)
signal order_changed()                     # someone joined or left the running fight

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

func end_turn(combatant) -> bool:
	"""The turn-holder says it is done. Refused for anyone else."""
	if not is_turn_of(combatant):
		return false
	_finish_turn()
	return true

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

	print("⚔️ COMBAT INITIATED!")
	print("=== INITIATIVE ORDER ===")
	for i in range(_order.size()):
		print("%d. %s (Initiative: %d)" % [i + 1, _order[i].name, _rolls[i]])

	# Fresh round: everyone's reaction (opportunity attack) is available
	CombatManager.reset_round_reactions()

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
	await get_tree().create_timer(SETTLE_DELAY, false).timeout
	if active and serial == _combat_serial:
		end_combat()

# ============================================================================
# THE TURN LOOP
# ============================================================================

func _begin_turn():
	"""Hand the turn to the combatant under the cursor. A player-controlled
	combatant keeps it until it calls end_turn(); anyone else acts through
	take_turn() and the turn winds up by itself."""
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

	turn_started.emit(combatant)
	EventBus.turn_started.emit(combatant)
	if not _turn_is_live(serial):
		return

	if combatant.is_player_controlled():
		combatant.start_new_turn()
		return

	combatant.take_turn()

	# Timers are pause-bound, so the fight freezes while a menu is open. The
	# body may be freed mid-turn (dungeon regenerated, companion dismissed).
	var polls = 0
	while _turn_is_live(serial) and is_instance_valid(combatant) and combatant.is_moving and polls < MAX_MOVE_POLLS:
		await get_tree().create_timer(MOVE_POLL, false).timeout
		polls += 1
	if not _turn_is_live(serial):
		return

	var pause = HOSTILE_TURN_PAUSE
	if is_instance_valid(combatant) and combatant.team == Combatant.Team.PARTY:
		pause = PARTY_TURN_PAUSE
	await get_tree().create_timer(pause, false).timeout
	if not _turn_is_live(serial):
		return

	_finish_turn()

func _finish_turn():
	"""Close the running turn and start the next one"""
	var ended = _current
	_current = null
	if is_instance_valid(ended):
		turn_ended.emit(ended)
		EventBus.turn_ended.emit(ended)
	if not active:
		return
	_advance()
	_begin_turn()

func _advance():
	"""Move the cursor to the next living combatant. Passing the end of the
	order starts a new round: once-per-round reactions come back."""
	for i in range(_order.size() - 1, -1, -1):
		if not _is_fit(_order[i]):
			_remove_at(i)
	if _order.is_empty():
		return

	_cursor += 1
	if _cursor >= _order.size():
		_cursor = 0
		round_number += 1
		CombatManager.reset_round_reactions()
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
# HELPERS
# ============================================================================

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
