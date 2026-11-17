extends Label
class_name TurnUI

# UI label for displaying turn-based information. In combat it shows whose turn
# the CombatController says it is.

var player: GridCharacter
var controller: CombatController = null
var current_turn_type: String = "player"  # "player", "ally" or "enemy"
var enemy_number: int = 0
var total_enemies: int = 0
var ally_name: String = ""

func _ready():
	# Top centre: full-width strip, text centred in it.
	# (anchors AND offsets - set_anchors_preset alone keeps the current 0x0 rect,
	# which left this label stuck in the top-left corner)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_top = 10
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Style the label
	add_theme_font_size_override("font_size", 32)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 3)

	# Start hidden
	visible = false

func setup(p_player: GridCharacter, p_controller: CombatController = null):
	"""Initialize with the player and the controller whose turns to show"""
	player = p_player
	controller = p_controller
	if controller:
		controller.turn_started.connect(_on_turn_started)
		controller.combat_ended.connect(_on_combat_ended)

func _process(_delta):
	if not player:
		return

	# Show/hide based on turn-based mode
	if player.turn_based_mode:
		visible = true
		update_text()
	else:
		visible = false

func _on_turn_started(combatant: Combatant):
	"""Show whose turn the controller has just started"""
	if combatant == player:
		set_player_turn()
	elif combatant.is_hostile_to(player):
		var order: Array[Combatant] = controller.get_order()
		set_enemy_turn(order.find(combatant) + 1, order.size())
	else:
		set_ally_turn(combatant)

func _on_combat_ended(_victory: bool):
	set_exploration_mode()

func set_player_turn():
	"""Set UI to show player's turn"""
	current_turn_type = "player"
	update_text()

func set_enemy_turn(enemy_num: int, total: int):
	"""Set UI to show an enemy's turn: its place in the initiative order"""
	current_turn_type = "enemy"
	enemy_number = enemy_num
	total_enemies = total
	update_text()

func set_ally_turn(ally: Combatant):
	"""Set UI to show a party member's turn"""
	current_turn_type = "ally"
	ally_name = ally.stats.character_name if ally.stats and ally.stats.character_name != "" else str(ally.name)
	update_text()

func set_exploration_mode():
	"""Reset UI when combat ends"""
	current_turn_type = "player"
	enemy_number = 0
	total_enemies = 0
	visible = false

func update_text():
	"""Update the label text with current turn info"""
	if current_turn_type == "enemy":
		# Enemy turn
		text = "🗡️ ENEMY %d/%d TURN 🗡️" % [enemy_number, total_enemies]
		add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red
	elif current_turn_type == "ally":
		text = "🛡️ %s'S TURN 🛡️" % ally_name.to_upper()
		add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))  # Blue
	else:
		# Player turn
		var moves = player.get_moves_remaining()
		var turn = player.get_turn_number()

		if moves <= 0:
			text = "⚔️ YOUR TURN %d | OUT OF MOVES - Press SPACE ⚔️" % turn
			add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))  # Orange
		else:
			text = "⚔️ YOUR TURN %d | Moves: %d ⚔️" % [turn, moves]
			add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Green
