extends Label
class_name TurnUI

# UI label for displaying turn-based information

var player: GridCharacter
var current_turn_type: String = "player"  # "player" or "enemy"
var enemy_number: int = 0
var total_enemies: int = 0

func _ready():
	# Position at top center
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	position.y = 10
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Style the label
	add_theme_font_size_override("font_size", 32)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 3)
	
	# Start hidden
	visible = false

func setup(p_player: GridCharacter):
	"""Initialize with player reference"""
	player = p_player

func _process(_delta):
	if not player:
		return
	
	# Show/hide based on turn-based mode
	if player.turn_based_mode:
		visible = true
		update_text()
	else:
		visible = false

func set_player_turn():
	"""Set UI to show player's turn"""
	current_turn_type = "player"
	update_text()

func set_enemy_turn(enemy_num: int, total: int):
	"""Set UI to show enemy's turn"""
	current_turn_type = "enemy"
	enemy_number = enemy_num
	total_enemies = total
	update_text()

func update_text():
	"""Update the label text with current turn info"""
	if current_turn_type == "enemy":
		# Enemy turn
		text = "🗡️ ENEMY %d/%d TURN 🗡️" % [enemy_number, total_enemies]
		add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red
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
