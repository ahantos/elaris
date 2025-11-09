# character_screen.gd
# Full-screen character + inventory UI for a single character
extends Control
class_name CharacterScreen

# Current character being displayed
var current_character: CharacterStats

# UI references
var equipment_panel: Panel
var stats_panel: Panel
var inventory_panel: Panel

# Equipment slot buttons (14 slots total)
var slot_buttons: Dictionary = {}

# Expandable accessory panels
var rings_panel: Panel
var trinkets_panel: Panel
var rings_expanded: bool = false
var trinkets_expanded: bool = false
var equipped_rings: Array = []      # Array of item instances
var equipped_trinkets: Array = []   # Array of item instances

# Inventory grid
var inventory_grid: GridContainer
var inventory_slots: Array = []
const INVENTORY_COLS: int = 5
const INVENTORY_ROWS: int = 5
const SLOT_SIZE: int = 64

# Drag-and-drop system
var dragging_item: Dictionary = {}
var drag_source_type: String = ""  # "equipment" or "inventory"
var drag_source_id: String = ""  # slot_id or inventory index
var drag_preview: Control
var is_dragging: bool = false

# Tooltip
var tooltip: PanelContainer

func _ready():
	setup_ui()
	connect_signals()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_ui():
	"""Create the complete UI layout"""
	# Full screen overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Dark background overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	# Main container
	var main_container = HBoxContainer.new()
	main_container.anchor_left = 0.5
	main_container.anchor_top = 0.5
	main_container.anchor_right = 0.5
	main_container.anchor_bottom = 0.5
	main_container.offset_left = -700
	main_container.offset_top = -400
	main_container.offset_right = 700
	main_container.offset_bottom = 400
	main_container.grow_horizontal = GROW_DIRECTION_BOTH
	main_container.grow_vertical = GROW_DIRECTION_BOTH
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# === LEFT: EQUIPMENT PANEL ===
	equipment_panel = create_equipment_panel()
	equipment_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(equipment_panel)
	
	# === CENTER: STATS PANEL ===
	stats_panel = create_stats_panel()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(stats_panel)
	
	# === RIGHT: INVENTORY PANEL ===
	inventory_panel = create_inventory_panel()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(inventory_panel)
	
	# Close button (top-right corner)
	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.position = Vector2(get_viewport_rect().size.x - 60, 20)
	close_button.pressed.connect(hide_screen)
	add_child(close_button)
	
	# Create tooltip
	create_tooltip()

func create_equipment_panel() -> Panel:
	"""Create left panel with equipment slots (paper doll style)"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(450, 800)  # Match other panels
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	
	# Add CenterContainer to center the entire VBoxContainer
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	center.add_child(content)
	
	# Title
	var title = Label.new()
	title.text = "EQUIPMENT"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(title)
	
	content.add_child(VSeparator.new())  # Spacer
	
	# Center container for paper doll
	var center_container = CenterContainer.new()
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center_container)
	
	# Paper doll layout using Control for absolute positioning
	var paper_doll = Control.new()
	paper_doll.custom_minimum_size = Vector2(400, 680)
	center_container.add_child(paper_doll)
	
	# Character model area in center (200 wide, centered in 400)
	var character_bg = ColorRect.new()
	character_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	character_bg.size = Vector2(200, 380)
	character_bg.position = Vector2(100, 40)  # User's posted value
	paper_doll.add_child(character_bg)
	
	var char_label = Label.new()
	char_label.text = "CHARACTER\nMODEL"
	char_label.position = Vector2(100, 200)  # Match character box position
	char_label.size = Vector2(200, 0)  # Width matches character box
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_label.add_theme_font_size_override("font_size", 12)
	paper_doll.add_child(char_label)
	
	# Equipment slots with MORE spacing and proper positioning
	# Character model: x=100 to x=300 (200 wide)
	# Left column should be further left, right column further right
	
	var left_x = 40         # User's posted value
	var right_x = 360       # User's posted value
	var spacing = 95
	var start_y = 40
	
	var slot_positions = [
		# Left column (6 slots - added wrist)
		["head", "HEAD", left_x, start_y],
		["neck", "NECK", left_x, start_y + spacing],
		["shoulder", "SHOULDER", left_x, start_y + spacing * 2],
		["back", "BACK", left_x, start_y + spacing * 3],
		["chest", "CHEST", left_x, start_y + spacing * 4],
		["wrist", "WRIST", left_x, start_y + spacing * 5],
		
		# Right column (6 slots - last 2 are expandable collections)
		["hands", "HANDS", right_x, start_y],
		["waist", "WAIST", right_x, start_y + spacing],
		["legs", "LEGS", right_x, start_y + spacing * 2],
		["feet", "FEET", right_x, start_y + spacing * 3],
		["rings", "RINGS ▼", right_x, start_y + spacing * 4],      # Expandable
		["trinkets", "TRINKETS ▼", right_x, start_y + spacing * 5], # Expandable
		
		# Bottom center: weapons and ranged below character model
		["main_hand", "MAIN\nHAND", 150, 500],  # User's posted values
		["off_hand", "OFF\nHAND", 250, 500],
		["ranged", "RANGED", 200, 570],  # Centered below weapons
	]
	
	for slot_data in slot_positions:
		var slot_id = slot_data[0]
		var label_text = slot_data[1]
		var x = slot_data[2]
		var y = slot_data[3]
		
		create_positioned_equipment_slot(paper_doll, slot_id, label_text, x, y)
	
	return panel

func create_positioned_equipment_slot(parent: Control, slot_id: String, label_text: String, x: int, y: int):
	"""Create an equipment slot at a specific position"""
	# Button
	var button = Button.new()
	button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	button.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	button.position = Vector2(x - SLOT_SIZE/2, y - SLOT_SIZE/2)  # Center on position
	button.text = ""
	button.name = "slot_" + slot_id
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Check if this is an expandable slot (rings or trinkets)
	if slot_id == "rings" or slot_id == "trinkets":
		button.pressed.connect(_on_expandable_slot_pressed.bind(slot_id))
	else:
		button.gui_input.connect(_on_equipment_slot_gui_input.bind(slot_id))
	
	slot_buttons[slot_id] = button
	parent.add_child(button)
	
	# Label below button
	var label = Label.new()
	label.text = label_text
	label.position = Vector2(x - 30, y + SLOT_SIZE/2 + 8)  # Increased from 2 to 8 pixels below
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(60, 0)
	label.add_theme_font_size_override("font_size", 9)
	parent.add_child(label)

func create_stats_panel() -> Panel:
	"""Create center panel with character stats"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(450, 800)  # Match other panels
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(content)
	
	# Character name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Character Name"
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(name_label)
	
	# Level and class
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Level 1 Fighter"
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(level_label)
	
	content.add_child(HSeparator.new())
	
	# HP bar
	var hp_container = VBoxContainer.new()
	hp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "HP: 50/50"
	hp_label.add_theme_font_size_override("font_size", 20)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_container.add_child(hp_label)
	
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.max_value = 50
	hp_bar.value = 50
	hp_bar.custom_minimum_size = Vector2(0, 30)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_container.add_child(hp_bar)
	content.add_child(hp_container)
	
	content.add_child(HSeparator.new())
	
	# Ability scores (3x2 grid)
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 30)
	stats_grid.add_theme_constant_override("v_separation", 8)
	stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
	for stat in stat_names:
		var stat_label = Label.new()
		stat_label.name = stat + "Label"
		stat_label.text = stat + ": 10 (+0)"
		stat_label.add_theme_font_size_override("font_size", 18)
		stats_grid.add_child(stat_label)
	
	content.add_child(stats_grid)
	
	content.add_child(HSeparator.new())
	
	# Derived stats
	var derived_vbox = VBoxContainer.new()
	derived_vbox.add_theme_constant_override("separation", 5)
	derived_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var derived_stats = ["AC", "Initiative", "Proficiency", "Speed"]
	for stat in derived_stats:
		var label = Label.new()
		label.name = stat + "Label"
		label.text = stat + ": --"
		label.add_theme_font_size_override("font_size", 16)
		derived_vbox.add_child(label)
	
	content.add_child(derived_vbox)
	
	content.add_child(HSeparator.new())
	
	# Encumbrance info
	var encumbrance_label = Label.new()
	encumbrance_label.name = "EncumbranceLabel"
	encumbrance_label.text = "Encumbrance: Normal"
	encumbrance_label.add_theme_font_size_override("font_size", 16)
	encumbrance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encumbrance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(encumbrance_label)
	
	return panel

func create_inventory_panel() -> Panel:
	"""Create right panel with inventory grid"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(450, 800)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(content)
	
	# Title
	var title = Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(title)
	
	# Slot counter
	var slot_label = Label.new()
	slot_label.name = "SlotLabel"
	slot_label.text = "Slots: 0/25"
	slot_label.add_theme_font_size_override("font_size", 18)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(slot_label)
	
	# Inventory grid
	inventory_grid = GridContainer.new()
	inventory_grid.columns = INVENTORY_COLS
	inventory_grid.add_theme_constant_override("h_separation", 4)
	inventory_grid.add_theme_constant_override("v_separation", 4)
	inventory_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Create inventory slots (5x5 = 25 visual slots)
	for i in range(INVENTORY_COLS * INVENTORY_ROWS):
		var slot = create_inventory_slot(i)
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)
	
	content.add_child(inventory_grid)
	
	# Sort and filter buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	button_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var sort_button = Button.new()
	sort_button.text = "SORT"
	sort_button.pressed.connect(_on_sort_pressed)
	button_row.add_child(sort_button)
	
	var filter_button = Button.new()
	filter_button.text = "FILTER"
	filter_button.pressed.connect(_on_filter_pressed)
	button_row.add_child(filter_button)
	
	content.add_child(button_row)
	
	# Gold display
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: 0g"
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(gold_label)
	
	return panel

func create_inventory_slot(index: int) -> Button:
	"""Create a single inventory slot button"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	button.text = ""
	button.name = "inv_slot_" + str(index)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect drag signals
	button.gui_input.connect(_on_inventory_slot_gui_input.bind(index))
	
	return button

func create_tooltip():
	"""Create tooltip for item hover"""
	tooltip = PanelContainer.new()
	tooltip.visible = false
	tooltip.z_index = 3000
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tooltip.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.name = "TooltipContent"
	margin.add_child(vbox)
	
	add_child(tooltip)

# === PUBLIC METHODS ===

func show_character(character: CharacterStats):
	"""Show screen for a specific character"""
	current_character = character
	refresh_all()
	visible = true
	get_tree().paused = true

func hide_screen():
	"""Hide the character screen"""
	visible = false
	get_tree().paused = false

func refresh_all():
	"""Refresh all UI elements"""
	if not current_character:
		return
	
	refresh_stats()
	refresh_equipment()
	refresh_inventory()

func refresh_stats():
	"""Update stats panel"""
	if not current_character:
		return
	
	# Name and level
	var name_label = stats_panel.find_child("NameLabel", true, false)
	if name_label:
		name_label.text = "Character Name"  # TODO: Add name to CharacterStats
	
	var level_label = stats_panel.find_child("LevelLabel", true, false)
	if level_label:
		level_label.text = "Level %d" % current_character.level
	
	# HP
	var hp_label = stats_panel.find_child("HPLabel", true, false)
	if hp_label:
		hp_label.text = "HP: %d/%d" % [current_character.current_hp, current_character.max_hp]
	
	var hp_bar = stats_panel.find_child("HPBar", true, false)
	if hp_bar:
		hp_bar.max_value = current_character.max_hp
		hp_bar.value = current_character.current_hp
	
	# Ability scores
	var stats_map = {
		"STR": [current_character.strength, current_character.get_str_modifier()],
		"DEX": [current_character.dexterity, current_character.get_dex_modifier()],
		"CON": [current_character.constitution, current_character.get_con_modifier()],
		"INT": [current_character.intelligence, current_character.get_int_modifier()],
		"WIS": [current_character.wisdom, current_character.get_wis_modifier()],
		"CHA": [current_character.charisma, current_character.get_cha_modifier()]
	}
	
	for stat_name in stats_map:
		var label = stats_panel.find_child(stat_name + "Label", true, false)
		if label:
			var score = stats_map[stat_name][0]
			var mod = stats_map[stat_name][1]
			var mod_str = "+%d" % mod if mod >= 0 else str(mod)
			label.text = "%s: %d (%s)" % [stat_name, score, mod_str]
	
	# Derived stats
	var ac_label = stats_panel.find_child("ACLabel", true, false)
	if ac_label:
		ac_label.text = "AC: %d" % current_character.armor_class
	
	var init_label = stats_panel.find_child("InitiativeLabel", true, false)
	if init_label:
		init_label.text = "Initiative: +%d" % current_character.initiative_bonus
	
	var prof_label = stats_panel.find_child("ProficiencyLabel", true, false)
	if prof_label:
		prof_label.text = "Proficiency: +%d" % current_character.proficiency_bonus
	
	var speed_label = stats_panel.find_child("SpeedLabel", true, false)
	if speed_label:
		var speed = current_character.movement_speed + InventoryManager.get_encumbrance_speed_penalty()
		speed_label.text = "Speed: %d ft" % max(0, speed)
	
	# Encumbrance
	var enc_label = stats_panel.find_child("EncumbranceLabel", true, false)
	if enc_label:
		enc_label.text = "Encumbrance: " + InventoryManager.get_encumbrance_text()

func refresh_equipment():
	"""Update equipment slots"""
	for slot_id in slot_buttons:
		var button = slot_buttons[slot_id]
		
		# Handle expandable accessory slots differently
		if slot_id == "rings" or slot_id == "trinkets":
			var accessories = InventoryManager.get_equipped_accessories(current_character, slot_id)
			var count = accessories.size()
			
			if count > 0:
				button.text = str(count)
			else:
				button.text = ""
			button.icon = null
			
			# Update the arrays for the panels
			if slot_id == "rings":
				equipped_rings = accessories
			else:
				equipped_trinkets = accessories
		else:
			# Normal single-item slots
			var equipped = InventoryManager.get_equipped_item(current_character, slot_id)
			
			if equipped.is_empty():
				button.text = ""
				button.icon = null
			else:
				var item_data: ItemData = equipped.item_data
				button.text = item_data.item_name[0]  # First letter
				button.icon = item_data.icon  # Set item icon (will be null until you add icons)

func refresh_inventory():
	"""Update inventory grid"""
	# Clear all slots
	for slot in inventory_slots:
		slot.text = ""
		slot.icon = null
	
	# Fill with items
	var items = InventoryManager.items
	for i in range(min(items.size(), inventory_slots.size())):
		var item = items[i]
		var item_data: ItemData = item.item_data
		var button = inventory_slots[i]
		
		button.text = item_data.item_name[0]
		button.icon = item_data.icon  # Set item icon (will be null until you add icons)
		
		# Show stack count
		if item.has("stack_count") and item.stack_count > 1:
			button.text += "\nx" + str(item.stack_count)
	
	# Update slot counter
	var slot_label = inventory_panel.find_child("SlotLabel", true, false)
	if slot_label:
		slot_label.text = "Slots: %d/%d" % [InventoryManager.get_slots_used(), InventoryManager.get_max_slots()]
	
	# Update gold
	var gold_label = inventory_panel.find_child("GoldLabel", true, false)
	if gold_label:
		gold_label.text = "Gold: %dg" % InventoryManager.gold

# === DRAG AND DROP SYSTEM ===

func _on_equipment_slot_gui_input(event: InputEvent, slot_id: String):
	"""Handle equipment slot drag and drop"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag from equipment slot
				var equipped = InventoryManager.get_equipped_item(current_character, slot_id)
				if not equipped.is_empty():
					start_drag(equipped, "equipment", slot_id)
			elif is_dragging:
				# Drop onto equipment slot
				end_drag_on_equipment(slot_id)

func _on_inventory_slot_gui_input(event: InputEvent, index: int):
	"""Handle inventory slot drag and drop"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag from inventory slot
				if index < InventoryManager.items.size():
					var item = InventoryManager.items[index]
					start_drag(item, "inventory", str(index))
			elif is_dragging:
				# Drop onto inventory slot
				end_drag_on_inventory(index)

func start_drag(item: Dictionary, source_type: String, source_id: String):
	"""Start dragging an item"""
	dragging_item = item
	drag_source_type = source_type
	drag_source_id = source_id
	is_dragging = true
	
	# Create drag preview
	create_drag_preview(item)
	
	print("Started dragging: ", item.item_data.item_name, " from ", source_type)

func create_drag_preview(item: Dictionary):
	"""Create visual preview of dragged item"""
	if drag_preview:
		drag_preview.queue_free()
	
	drag_preview = PanelContainer.new()
	drag_preview.z_index = 2000
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var preview_button = Button.new()
	preview_button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	preview_button.text = item.item_data.item_name[0]
	preview_button.icon = item.item_data.icon  # Show icon in drag preview
	preview_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_button.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
	
	drag_preview.add_child(preview_button)
	add_child(drag_preview)
	
	# Position at mouse
	update_drag_preview_position()

func update_drag_preview_position():
	"""Update drag preview position to follow mouse"""
	if drag_preview and is_dragging:
		drag_preview.global_position = get_global_mouse_position() - Vector2(SLOT_SIZE / 2, SLOT_SIZE / 2)

func end_drag_on_equipment(target_slot_id: String):
	"""Handle dropping item onto equipment slot"""
	if not is_dragging or dragging_item.is_empty():
		return
	
	var item_data: ItemData = dragging_item.item_data
	
	# Check if item can be equipped in this slot
	if item_data.equip_slot != target_slot_id:
		print("Cannot equip ", item_data.item_name, " in ", target_slot_id, " slot")
		cancel_drag()
		return
	
	# Handle different source types
	if drag_source_type == "equipment":
		# Swapping between equipment slots
		var source_slot = drag_source_id
		if source_slot != target_slot_id:
			# Swap items between slots
			var target_item = InventoryManager.get_equipped_item(current_character, target_slot_id)
			
			if not target_item.is_empty():
				# Both slots have items - swap them
				InventoryManager.unequip_item(current_character, target_slot_id)
				InventoryManager.unequip_item(current_character, source_slot)
				InventoryManager.equip_item(target_item, current_character, source_slot)
				InventoryManager.equip_item(dragging_item, current_character, target_slot_id)
			else:
				# Target slot empty - just move
				InventoryManager.unequip_item(current_character, source_slot)
				InventoryManager.equip_item(dragging_item, current_character, target_slot_id)
			
			print("Moved ", item_data.item_name, " from ", source_slot, " to ", target_slot_id)
	
	elif drag_source_type == "inventory":
		# Equipping from inventory
		InventoryManager.equip_item(dragging_item, current_character, target_slot_id)
		print("Equipped ", item_data.item_name, " to ", target_slot_id)
	
	cancel_drag()

func end_drag_on_inventory(target_index: int):
	"""Handle dropping item onto inventory slot"""
	if not is_dragging or dragging_item.is_empty():
		return
	
	# Handle different source types
	if drag_source_type == "equipment":
		# Unequipping to inventory
		var source_slot = drag_source_id
		InventoryManager.unequip_item(current_character, source_slot)
		print("Unequipped ", dragging_item.item_data.item_name, " to inventory")
	
	elif drag_source_type == "inventory":
		# Reordering inventory (TODO: implement inventory reordering)
		print("Inventory reordering not yet implemented")
	
	cancel_drag()

func cancel_drag():
	"""Cancel drag operation"""
	is_dragging = false
	dragging_item = {}
	drag_source_type = ""
	drag_source_id = ""
	
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

func _process(_delta):
	"""Update drag preview position each frame"""
	if is_dragging:
		update_drag_preview_position()

# === SIGNAL HANDLERS ===

func connect_signals():
	"""Connect to EventBus signals"""
	EventBus.inventory_changed.connect(refresh_inventory)
	EventBus.equipment_changed.connect(func(_character): refresh_all())
	EventBus.slots_changed.connect(func(_used, _max): refresh_inventory())
	EventBus.gold_changed.connect(func(_gold): refresh_inventory())

func _on_sort_pressed():
	"""Sort inventory"""
	InventoryManager.sort_items_by("type")
	refresh_inventory()

func _on_filter_pressed():
	"""Filter inventory (TODO: implement filter UI)"""
	print("Filter pressed - not yet implemented")

func _on_expandable_slot_pressed(slot_id: String):
	"""Handle clicking expandable accessory slots (rings/trinkets)"""
	if slot_id == "rings":
		_toggle_rings_panel()
	elif slot_id == "trinkets":
		_toggle_trinkets_panel()

func _toggle_rings_panel():
	"""Toggle the rings expandable panel"""
	if rings_expanded:
		_hide_rings_panel()
	else:
		_show_rings_panel()

func _toggle_trinkets_panel():
	"""Toggle the trinkets expandable panel"""
	if trinkets_expanded:
		_hide_trinkets_panel()
	else:
		_show_trinkets_panel()

func _show_rings_panel():
	"""Show expandable panel for rings"""
	if not rings_panel:
		rings_panel = _create_accessory_panel("Rings", equipped_rings)
	
	# Refresh the panel contents with current data
	_refresh_accessory_panel(rings_panel, "rings", equipped_rings)
	
	rings_panel.visible = true
	rings_expanded = true
	
	# Update button text
	var button = slot_buttons.get("rings")
	if button:
		button.text = str(equipped_rings.size()) if equipped_rings.size() > 0 else ""

func _hide_rings_panel():
	"""Hide rings panel"""
	if rings_panel:
		rings_panel.visible = false
	rings_expanded = false

func _show_trinkets_panel():
	"""Show expandable panel for trinkets"""
	if not trinkets_panel:
		trinkets_panel = _create_accessory_panel("Trinkets", equipped_trinkets)
	
	# Refresh the panel contents with current data
	_refresh_accessory_panel(trinkets_panel, "trinkets", equipped_trinkets)
	
	trinkets_panel.visible = true
	trinkets_expanded = true
	
	# Update button text
	var button = slot_buttons.get("trinkets")
	if button:
		button.text = str(equipped_trinkets.size()) if equipped_trinkets.size() > 0 else ""

func _hide_trinkets_panel():
	"""Hide trinkets panel"""
	if trinkets_panel:
		trinkets_panel.visible = false
	trinkets_expanded = false

func _create_accessory_panel(title: String, items_array: Array) -> Panel:
	"""Create an expandable panel showing multiple accessories"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(350, 450)
	panel.position = Vector2(get_viewport_rect().size.x / 2 - 175, get_viewport_rect().size.y / 2 - 225)
	panel.z_index = 1000
	panel.name = title + "Panel"
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Title and close button row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	vbox.add_child(title_row)
	
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(func():
		if title == "Rings":
			_hide_rings_panel()
		else:
			_hide_trinkets_panel()
	)
	title_row.add_child(close_btn)
	
	# Scroll container for items
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.name = "ScrollContainer"
	vbox.add_child(scroll)
	
	var items_vbox = VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 8)
	items_vbox.name = "ItemsContainer"
	scroll.add_child(items_vbox)
	
	# We'll populate this dynamically when shown
	
	panel.visible = false
	return panel

func _refresh_accessory_panel(panel: Panel, slot_type: String, items_array: Array):
	"""Refresh the contents of an accessory panel"""
	var items_container = panel.find_child("ItemsContainer", true, false)
	if not items_container:
		return
	
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()
	
	# Add items
	if items_array.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No " + slot_type + " equipped"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		items_container.add_child(empty_label)
	else:
		for item in items_array:
			var item_row = HBoxContainer.new()
			item_row.add_theme_constant_override("separation", 10)
			items_container.add_child(item_row)
			
			# Item button (shows name)
			var item_button = Button.new()
			item_button.text = item.item_data.get_full_name()
			item_button.custom_minimum_size = Vector2(0, 40)
			item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			item_row.add_child(item_button)
			
			# Unequip button
			var unequip_btn = Button.new()
			unequip_btn.text = "✕"
			unequip_btn.custom_minimum_size = Vector2(40, 40)
			unequip_btn.pressed.connect(func():
				InventoryManager.unequip_item(current_character, slot_type, item)
				refresh_equipment()
				_refresh_accessory_panel(panel, slot_type, 
					equipped_rings if slot_type == "rings" else equipped_trinkets)
			)
			item_row.add_child(unequip_btn)

func _input(event):
	"""Handle input"""
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			hide_screen()
			get_viewport().set_input_as_handled()
