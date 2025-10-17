# bottomui.gd - REFACTORED TO USE CHARACTERSTATS
extends Control
class_name BottomUI

# Main game UI that covers bottom 1/4 of screen

var player: GridCharacter

# UI element references
var hp_label: Label
var hp_bar: ProgressBar
var turn_label: Label
var moves_label: Label
var combat_status_label: Label
var light_btn: Button
var medium_btn: Button
var heavy_btn: Button
var end_turn_btn: Button
var attack_info_label: Label

func _ready():
	# Anchor to bottom of screen
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	
	# Take up bottom 1/4 of screen
	var screen_height = get_viewport().size.y
	var ui_height = screen_height / 4.0
	
	custom_minimum_size = Vector2(0, ui_height)
	size = Vector2(get_viewport().size.x, ui_height)
	offset_top = -ui_height
	
	# Background panel
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_top = 3
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.border_color = Color(0.3, 0.3, 0.4)
	panel.add_theme_stylebox_override("panel", style)

func setup(p_player: GridCharacter):
	"""Initialize with player reference"""
	player = p_player
	create_ui_elements()

func create_ui_elements():
	"""Create all UI elements"""
	create_player_info()
	create_action_buttons()
	create_status_info()

func create_player_info():
	"""Create player health and stats display"""
	var player_section = VBoxContainer.new()
	player_section.position = Vector2(20, 15)
	player_section.add_theme_constant_override("separation", 8)
	add_child(player_section)
	
	# Player name/title
	var name_label = Label.new()
	name_label.text = "⚔️ PLAYER"
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	player_section.add_child(name_label)
	
	# HP label
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 18)
	player_section.add_child(hp_label)
	
	# HP progress bar
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(200, 20)
	hp_bar.show_percentage = false
	player_section.add_child(hp_bar)
	
	# Style HP bar background
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.2, 0.2)
	bar_bg.border_width_left = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_bottom = 1
	bar_bg.border_color = Color(0.4, 0.4, 0.4)
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	
	# Style HP bar fill
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.8, 0.2)
	hp_bar.add_theme_stylebox_override("fill", bar_fill)
	
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	player_section.add_child(spacer)
	
	# Instructions
	var hint_label = Label.new()
	hint_label.text = "🎯 Click to move | Ctrl+Click for waypoints\n⚔️ 1/2/3 - Select attack | Space - End Turn\n👆 Click enemy when attack selected"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	player_section.add_child(hint_label)

func create_action_buttons():
	"""Create attack and action buttons"""
	var container = VBoxContainer.new()
	var screen_width = get_viewport().size.x
	container.position = Vector2(screen_width / 2 - 250, 10)
	container.add_theme_constant_override("separation", 10)
	add_child(container)
	
	# Attack mode info label
	attack_info_label = Label.new()
	attack_info_label.text = ""
	attack_info_label.add_theme_font_size_override("font_size", 14)
	attack_info_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	attack_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_info_label.visible = false
	container.add_child(attack_info_label)
	
	# Buttons container
	var actions_section = HBoxContainer.new()
	actions_section.add_theme_constant_override("separation", 12)
	container.add_child(actions_section)
	
	# Light attack button
	light_btn = create_attack_button("Light Attack", "1 DMG", "Key: 1", Color(1.0, 1.0, 0.0))
	light_btn.pressed.connect(_on_light_attack_pressed)
	actions_section.add_child(light_btn)
	
	# Medium attack button
	medium_btn = create_attack_button("Medium Attack", "5 DMG", "Key: 2", Color(1.0, 0.5, 0.0))
	medium_btn.pressed.connect(_on_medium_attack_pressed)
	actions_section.add_child(medium_btn)
	
	# Heavy attack button
	heavy_btn = create_attack_button("Heavy Attack", "10 DMG", "Key: 3", Color(1.0, 0.0, 0.0))
	heavy_btn.pressed.connect(_on_heavy_attack_pressed)
	actions_section.add_child(heavy_btn)
	
	# End turn button
	end_turn_btn = create_end_turn_button()
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	actions_section.add_child(end_turn_btn)

func create_attack_button(title: String, damage: String, key_hint: String, color: Color) -> Button:
	"""Create a styled attack button"""
	var btn = Button.new()
	btn.text = title + "\n" + damage + "\n" + key_hint
	btn.custom_minimum_size = Vector2(115, 85)
	btn.add_theme_font_size_override("font_size", 13)
	
	# Normal style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = color * 0.7
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal_style)
	
	# Hover style
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4)
	hover_style.border_width_left = 2
	hover_style.border_width_right = 2
	hover_style.border_width_top = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = color
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed style
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = color * 0.6
	pressed_style.border_width_left = 3
	pressed_style.border_width_right = 3
	pressed_style.border_width_top = 3
	pressed_style.border_width_bottom = 3
	pressed_style.border_color = Color.WHITE
	pressed_style.corner_radius_top_left = 6
	pressed_style.corner_radius_top_right = 6
	pressed_style.corner_radius_bottom_left = 6
	pressed_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	# Disabled style
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.15, 0.15, 0.15)
	disabled_style.border_width_left = 2
	disabled_style.border_width_right = 2
	disabled_style.border_width_top = 2
	disabled_style.border_width_bottom = 2
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	disabled_style.corner_radius_top_left = 6
	disabled_style.corner_radius_top_right = 6
	disabled_style.corner_radius_bottom_left = 6
	disabled_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	return btn

func create_end_turn_button() -> Button:
	"""Create the end turn button"""
	var btn = Button.new()
	btn.text = "⏭️ End Turn\n(SPACE)"
	btn.custom_minimum_size = Vector2(115, 85)
	btn.add_theme_font_size_override("font_size", 14)
	
	# Normal style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.3, 0.5)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.4, 0.5, 0.7)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal_style)
	
	# Hover style
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.4, 0.6)
	hover_style.border_width_left = 2
	hover_style.border_width_right = 2
	hover_style.border_width_top = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(0.5, 0.6, 0.8)
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed style
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.4, 0.5, 0.7)
	pressed_style.border_width_left = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_bottom = 2
	pressed_style.border_color = Color(0.4, 0.5, 0.7)
	pressed_style.corner_radius_top_left = 6
	pressed_style.corner_radius_top_right = 6
	pressed_style.corner_radius_bottom_left = 6
	pressed_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	# Disabled style
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.15, 0.15, 0.15)
	disabled_style.border_width_left = 2
	disabled_style.border_width_right = 2
	disabled_style.border_width_top = 2
	disabled_style.border_width_bottom = 2
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	disabled_style.corner_radius_top_left = 6
	disabled_style.corner_radius_top_right = 6
	disabled_style.corner_radius_bottom_left = 6
	disabled_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	return btn

func create_status_info():
	"""Create status and info display"""
	var status_section = VBoxContainer.new()
	var screen_width = get_viewport().size.x
	status_section.position = Vector2(screen_width - 230, 15)
	status_section.add_theme_constant_override("separation", 8)
	add_child(status_section)
	
	# Combat status header
	combat_status_label = Label.new()
	combat_status_label.text = "⚔️ IN COMBAT"
	combat_status_label.add_theme_font_size_override("font_size", 20)
	combat_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	combat_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_section.add_child(combat_status_label)
	
	# Turn info
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 16)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_section.add_child(turn_label)
	
	# Moves remaining
	moves_label = Label.new()
	moves_label.add_theme_font_size_override("font_size", 16)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_section.add_child(moves_label)
	
	# Separator
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(200, 2)
	status_section.add_child(separator)
	
	# Additional info
	var info_label = Label.new()
	info_label.text = "📍 T - Toggle turn mode\n🗺️ M - Toggle fog of war\n🔄 R - Regenerate dungeon"
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_section.add_child(info_label)

func _process(_delta):
	"""Update UI every frame"""
	if player:
		update_display()

func update_display():
	"""Update all UI elements with current data (REFACTORED)"""
	if not player or not player.stats:
		return
	
	# Update HP
	if hp_label and hp_bar:
		var hp_percent = player.stats.get_hp_percent()
		var hp_color = Color.GREEN.lerp(Color.RED, 1.0 - hp_percent)
		
		hp_label.text = "HP: %d / %d" % [player.stats.current_hp, player.stats.max_hp]
		hp_label.add_theme_color_override("font_color", hp_color)
		
		hp_bar.max_value = player.stats.max_hp
		hp_bar.value = player.stats.current_hp
		
		# Update bar color
		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = hp_color
		hp_bar.add_theme_stylebox_override("fill", bar_fill)
	
	# Update turn info
	if turn_label:
		if player.turn_based_mode:
			turn_label.text = "🎲 Turn: %d" % player.get_turn_number()
			turn_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			turn_label.text = "🏃 Free Movement"
			turn_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# Update moves
	if moves_label:
		if player.turn_based_mode:
			var moves = player.get_moves_remaining()
			var moves_color: Color
			if moves > 3:
				moves_color = Color(0.3, 1.0, 0.3)
			elif moves > 0:
				moves_color = Color(1.0, 1.0, 0.3)
			else:
				moves_color = Color(1.0, 0.3, 0.3)
			
			moves_label.text = "🦶 Moves: %d / %d" % [moves, player.stats.movement_speed]
			moves_label.add_theme_color_override("font_color", moves_color)
			moves_label.visible = true
		else:
			moves_label.visible = false
	
	# Update combat status
	if combat_status_label:
		var world = get_tree().root.get_node_or_null("World")
		if world and world.in_combat:
			combat_status_label.visible = true
		else:
			combat_status_label.visible = false
	
	# Update attack mode indicator
	if attack_info_label:
		if player.attack_mode:
			var attack_name = ""
			var damage = 0
			match player.selected_attack_type:
				"light":
					attack_name = "LIGHT ATTACK"
					damage = player.light_attack_damage
				"medium":
					attack_name = "MEDIUM ATTACK"
					damage = player.medium_attack_damage
				"heavy":
					attack_name = "HEAVY ATTACK"
					damage = player.heavy_attack_damage
			
			attack_info_label.text = "🎯 %s SELECTED (%d DMG) - Click adjacent enemy!" % [attack_name, damage]
			attack_info_label.visible = true
		else:
			attack_info_label.visible = false
	
	# Update button states
	update_button_states()

func update_button_states():
	"""Enable/disable buttons based on game state"""
	if not player or not player.turn_based_mode:
		if light_btn: light_btn.disabled = true
		if medium_btn: medium_btn.disabled = true
		if heavy_btn: heavy_btn.disabled = true
		if end_turn_btn: end_turn_btn.disabled = true
		return
	
	var can_attack = not player.has_attacked_this_turn and not player.is_moving
	var can_end_turn = not player.is_moving
	
	if light_btn:
		light_btn.disabled = not can_attack
		if player.attack_mode and player.selected_attack_type == "light":
			light_btn.button_pressed = true
		else:
			light_btn.button_pressed = false
	
	if medium_btn:
		medium_btn.disabled = not can_attack
		if player.attack_mode and player.selected_attack_type == "medium":
			medium_btn.button_pressed = true
		else:
			medium_btn.button_pressed = false
	
	if heavy_btn:
		heavy_btn.disabled = not can_attack
		if player.attack_mode and player.selected_attack_type == "heavy":
			heavy_btn.button_pressed = true
		else:
			heavy_btn.button_pressed = false
	
	if end_turn_btn:
		end_turn_btn.disabled = not can_end_turn

# Button callbacks
func _on_light_attack_pressed():
	if player and player.turn_based_mode and not player.has_attacked_this_turn:
		if player.attack_mode and player.selected_attack_type == "light":
			player.attack_mode = false
			player.selected_attack_type = ""
			print("Attack cancelled.")
		else:
			player.attack_mode = true
			player.selected_attack_type = "light"
			print("💛 Light attack selected (1 DMG)! Click an adjacent enemy.")
		player.queue_redraw()

func _on_medium_attack_pressed():
	if player and player.turn_based_mode and not player.has_attacked_this_turn:
		if player.attack_mode and player.selected_attack_type == "medium":
			player.attack_mode = false
			player.selected_attack_type = ""
			print("Attack cancelled.")
		else:
			player.attack_mode = true
			player.selected_attack_type = "medium"
			print("🧡 Medium attack selected (5 DMG)! Click an adjacent enemy.")
		player.queue_redraw()

func _on_heavy_attack_pressed():
	if player and player.turn_based_mode and not player.has_attacked_this_turn:
		if player.attack_mode and player.selected_attack_type == "heavy":
			player.attack_mode = false
			player.selected_attack_type = ""
			print("Attack cancelled.")
		else:
			player.attack_mode = true
			player.selected_attack_type = "heavy"
			print("❤️ Heavy attack selected (10 DMG)! Click an adjacent enemy.")
		player.queue_redraw()

func _on_end_turn_pressed():
	if player and player.turn_based_mode:
		player.end_turn()
