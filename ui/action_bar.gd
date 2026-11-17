# action_bar.gd
# The action bar (scenes/ui/action_bar.tscn): what the combatant the player
# controls can do with its turn - Attack, Cast, Use Item, Dash, Disengage,
# Dodge, End Turn - and, above the buttons, the turn resources of whoever holds
# the turn: movement left, and whether the action, bonus action and reaction
# are spent.
# Display and input only. Each button asks the CombatController whether its
# action is available and shows the answer; a press goes to the combatant,
# which asks the controller for the action. What the weapons are and how far
# they reach is CombatManager's to say.
extends Control

const TITLES: Dictionary = {
	CombatController.ACTION_ATTACK: "Attack",
	CombatController.ACTION_CAST: "Cast",
	CombatController.ACTION_USE_ITEM: "Use Item",
	CombatController.ACTION_DASH: "Dash",
	CombatController.ACTION_DISENGAGE: "Disengage",
	CombatController.ACTION_DODGE: "Dodge",
	CombatController.ACTION_END_TURN: "End Turn",
}

const HINTS: Dictionary = {
	CombatController.ACTION_ATTACK: "One attack with the weapon that suits the target: the melee weapon in hand on an adjacent enemy, the ranged weapon you carry on one further away. Pick it, then click a marked enemy; resting the pointer on an enemy shows the chance to hit. Takes your action.",
	CombatController.ACTION_CAST: "Open the spellbook and ready a spell, then click its target. Takes the action or bonus action the spell says.",
	CombatController.ACTION_USE_ITEM: "Open the pack and right-click a potion, scroll or wand. Takes your action in a fight.",
	CombatController.ACTION_DASH: "Move your speed again this turn. Takes your action.",
	CombatController.ACTION_DISENGAGE: "For the rest of the turn your movement provokes no opportunity attacks. Takes your action.",
	CombatController.ACTION_DODGE: "Until your next turn, attacks against you have disadvantage and you make Dexterity saves with advantage. Takes your action.",
	CombatController.ACTION_END_TURN: "Pass the turn to the next in the initiative order. Space does the same.",
}

const COLOR_READY := Color(0.55, 0.9, 0.55)
const COLOR_SPENT := Color(0.62, 0.45, 0.45)
const COLOR_PLAIN := Color(0.88, 0.88, 0.92)

# Who this bar gives orders to, and the authority it asks
var combatant: Combatant = null
var controller: CombatController = null

# action id -> its button (an ActionButton)
var _buttons: Dictionary = {}

@onready var _button_row: HBoxContainer = %Buttons
@onready var _turn_label: Label = %TurnLabel
@onready var _movement_label: Label = %MovementLabel
@onready var _action_label: Label = %ActionLabel
@onready var _bonus_label: Label = %BonusLabel
@onready var _reaction_label: Label = %ReactionLabel
@onready var _state_label: Label = %StateLabel
@onready var _hint: Label = %Hint

func _ready():
	for i in range(CombatController.ACTION_BAR.size()):
		var action_id: String = CombatController.ACTION_BAR[i]
		var button: Button = _button_row.get_child(i)
		_buttons[action_id] = button
		button.pressed.connect(_on_action_pressed.bind(action_id))
	_hint.text = ""

func setup(p_combatant: Combatant, p_controller: CombatController):
	"""Give the bar the combatant it gives orders to and the controller it asks"""
	combatant = p_combatant
	controller = p_controller
	refresh()

func _process(_delta):
	refresh()

func get_button(action_id: String) -> Button:
	"""The button of an action (see CombatController.ACTION_BAR)"""
	return _buttons.get(action_id)

func refresh():
	"""Show the state of the turn and of every action as it is right now"""
	if not is_instance_valid(combatant) or controller == null or combatant.stats == null:
		return
	_refresh_strip()
	for i in range(CombatController.ACTION_BAR.size()):
		var action_id: String = CombatController.ACTION_BAR[i]
		_buttons[action_id].show_action(str(i + 1), TITLES[action_id], _detail_for(action_id), _reason_for(action_id),
			action_id == CombatController.ACTION_ATTACK and combatant.is_aiming_attack(), HINTS[action_id], _note_for(action_id))
	_hint.text = _hint_text()

func _on_action_pressed(action_id: String):
	if is_instance_valid(combatant):
		combatant.choose_action(action_id)
	refresh()

# --- the strip above the buttons ---

func _refresh_strip():
	"""The turn resources of whoever holds the turn; outside a fight, of the
	bar's own combatant"""
	var fighting: bool = controller.active
	var shown: Combatant = controller.current_combatant() if fighting else null
	if shown == null:
		shown = combatant

	if not fighting:
		_turn_label.text = "Turn mode" if combatant.is_taking_turns() else "Exploring"
	elif shown == combatant:
		_turn_label.text = "Your turn"
	else:
		_turn_label.text = "%s's turn" % shown.get_display_name()

	if shown.is_taking_turns():
		_movement_label.text = "Movement %d / %d" % [shown.movement_left, max(shown.movement_left, shown.movement_granted)]
		_movement_label.add_theme_color_override("font_color", COLOR_READY if shown.movement_left > 0 else COLOR_SPENT)
	else:
		_movement_label.text = "Movement free"
		_movement_label.add_theme_color_override("font_color", COLOR_PLAIN)

	# The action economy only exists in a fight
	_action_label.visible = fighting
	_bonus_label.visible = fighting
	_reaction_label.visible = fighting
	_show_resource(_action_label, "Action", shown.action_used)
	_show_resource(_bonus_label, "Bonus action", shown.bonus_action_used)
	_show_resource(_reaction_label, "Reaction", shown.reaction_used)

	var states: Array = []
	if shown.is_dodging():
		states.append("Dodging")
	if shown.disengaged:
		states.append("Disengaged")
	_state_label.text = " · ".join(states)
	_state_label.visible = not states.is_empty()

func _show_resource(label: Label, title: String, spent: bool):
	label.text = "%s %s" % [title, "spent" if spent else "ready"]
	label.add_theme_color_override("font_color", COLOR_SPENT if spent else COLOR_READY)

# --- what each button says ---

func _detail_for(action_id: String) -> String:
	match action_id:
		CombatController.ACTION_ATTACK:
			return _attack_detail()
		CombatController.ACTION_CAST:
			var pending: String = SpellManager.get_pending_cast(combatant)
			if pending != "":
				return "%s\nreadied" % str(SpellDatabase.get_spell(pending).get("display_name", pending))
			return "Spellbook\n(B)"
		CombatController.ACTION_USE_ITEM:
			return "Potions, scrolls,\nwands (I)"
		CombatController.ACTION_DASH:
			return "+%d tiles of\nmovement" % combatant.get_turn_speed()
		CombatController.ACTION_DISENGAGE:
			return "Move away without\nbeing attacked"
		CombatController.ACTION_DODGE:
			return "Attacks against you\nat disadvantage"
		CombatController.ACTION_END_TURN:
			return "Space"
	return ""

func _attack_detail() -> String:
	"""What Attack is made with. One weapon: its name, then its damage. A melee
	weapon and a ranged one: a line each, the melee one first, as
	'Longsword 1d8+2'."""
	var melee: Dictionary = CombatManager.get_melee_profile(combatant)
	var ranged: Dictionary = CombatManager.get_ranged_profile(combatant)
	if ranged.is_empty() or melee.weapon == null:
		var profile: Dictionary = CombatManager.get_attack_profile(combatant)
		return "%s\n%s" % [profile.weapon_name, CombatManager.get_damage_text(profile)]
	return "%s\n%s" % [_weapon_line(melee), _weapon_line(ranged)]

func _weapon_line(profile: Dictionary) -> String:
	"""'Light Crossbow 1d8+1': the kind of weapon and its damage, short enough
	for one line of a button"""
	var weapon: ItemData = profile.weapon
	var kind: String = weapon.weapon_type.capitalize() if weapon.weapon_type != "" else str(profile.weapon_name)
	return "%s %s" % [kind, CombatManager.get_damage_text(profile).get_slice(" ", 0)]

func _reason_for(action_id: String) -> String:
	"""Why the action cannot be taken right now, or "" when it can"""
	var check: Dictionary = controller.check_action(combatant, action_id)
	return "" if check.ok else str(check.reason)

func _note_for(action_id: String) -> String:
	"""Something to know about an action that can be taken: for Attack, a
	ranged weapon that cannot be fired as things stand"""
	if action_id != CombatController.ACTION_ATTACK:
		return ""
	var ranged: Dictionary = CombatManager.get_ranged_profile(combatant)
	return str(ranged.reason) if not ranged.is_empty() and not ranged.usable else ""

func _hint_text() -> String:
	"""What the next click will do, while an attack or a spell is being aimed"""
	var pending: String = SpellManager.get_pending_cast(combatant)
	if pending != "":
		return "%s readied: click its target. Esc cancels." % str(SpellDatabase.get_spell(pending).get("display_name", pending))
	if combatant.is_aiming_attack():
		return "Attack: click a marked enemy. %s. Esc cancels." % _reach_text()
	return ""

func _reach_text() -> String:
	"""How far the combatant's attacks reach, in words: 'Iron Longsword on an
	adjacent enemy, Oak Light Crossbow to 16 tiles (to 64 at disadvantage)'"""
	var melee: Dictionary = CombatManager.get_melee_profile(combatant)
	var ranged: Dictionary = CombatManager.get_ranged_profile(combatant)
	var can_shoot: bool = not ranged.is_empty() and ranged.usable
	var parts: Array[String] = []
	if melee.weapon != null or not can_shoot:
		parts.append("%s on an adjacent enemy" % str(melee.weapon_name))
	if can_shoot:
		var reach: String = "%s to %d tiles" % [str(ranged.weapon_name), int(ranged.range_normal)]
		if int(ranged.range_max) > int(ranged.range_normal):
			reach += " (to %d at disadvantage)" % int(ranged.range_max)
		parts.append(reach)
	return ", ".join(parts)
