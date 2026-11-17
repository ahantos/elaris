# bottomui.gd
extends Control
class_name BottomUI

# Main game UI that covers bottom 1/4 of screen: the character's health on the
# left, the action bar (scenes/ui/action_bar.tscn) in the middle, the state of
# the fight and the key hints on the right.

const ACTION_BAR_SCENE := preload("res://scenes/ui/action_bar.tscn")

var player: GridCharacter
var controller: CombatController = null
var action_bar: Control = null

# Cached world reference (avoids per-frame scene tree lookups)
var world_node = null

# UI element references
var hp_label: Label
var hp_bar: ProgressBar
var turn_label: Label
var combat_status_label: Label

func _ready():
	# Anchor to bottom of screen (anchors AND offsets: set_anchors_preset alone
	# keeps the current 0x0 rect, which left the bar with no width or background)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)

	# Take up the bottom 1/4 of the screen. Sizes come from the viewport RECT
	# (the 1920x1080 design size), not the window's pixel size.
	var screen_height = get_viewport_rect().size.y
	var ui_height = screen_height / 4.0

	custom_minimum_size = Vector2(0, ui_height)
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

func setup(p_player: GridCharacter, p_controller: CombatController = null):
	"""Initialize with the character whose bar this is and the combat controller"""
	player = p_player
	controller = p_controller
	create_ui_elements()

func create_ui_elements():
	"""Create all UI elements"""
	create_player_info()
	create_action_bar()
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
	hint_label.text = "🎯 Click to move | Ctrl+Click for waypoints\n⚔️ 1-7 - Actions on the bar | Space - End Turn\n👆 Attack: pick it, then click an enemy"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	player_section.add_child(hint_label)

func create_action_bar():
	"""The action bar is a scene of its own; it fills this panel and centres itself"""
	action_bar = ACTION_BAR_SCENE.instantiate()
	add_child(action_bar)
	action_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action_bar.setup(player, controller)

func create_status_info():
	"""Create status and info display"""
	var status_section = VBoxContainer.new()
	var screen_width = get_viewport_rect().size.x
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
	
	# Separator
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(200, 2)
	status_section.add_child(separator)
	
	# Additional info
	var info_label = Label.new()
	info_label.text = "I sheet · B spells · C craft · J quests\nO map · P party · F5/F6 save/load\nF7/F8 rest · T turn mode · F3 debug keys"
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_section.add_child(info_label)

func _get_world():
	"""Get the cached World node (re-resolves if missing/freed)"""
	if not is_instance_valid(world_node):
		world_node = get_tree().root.get_node_or_null("World")
	return world_node

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
	
	# Update combat status
	if combat_status_label:
		var world = _get_world()
		if world and world.in_combat:
			combat_status_label.visible = true
		else:
			combat_status_label.visible = false
