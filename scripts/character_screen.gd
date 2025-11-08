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
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(1400, 800)
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# === LEFT: EQUIPMENT PANEL ===
	equipment_panel = create_equipment_panel()
	main_container.add_child(equipment_panel)
	
	# === CENTER: STATS PANEL ===
	stats_panel = create_stats_panel()
	main_container.add_child(stats_panel)
	
	# === RIGHT: INVENTORY PANEL ===
	inventory_panel = create_inventory_panel()
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
	panel.custom_minimum_size = Vector2(400, 800)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	
	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	
	# Title
	var title = Label.new()
	title.text = "EQUIPMENT"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	
	# Equipment slots in order
	var slot_order = [
		"head", "neck", "shoulder", "back",
		"left_weapon", "right_weapon",
		"wrist", "arm", "legs", "boots",
		"accessory_1", "accessory_2", "accessory_3", "accessory_4"
	]
	
	var slot_labels = {
		"head": "HEAD",
		"neck": "NECK",
		"shoulder": "SHOULDERS",
		"back": "BACK/CAPE",
		"left_weapon": "LEFT HAND",
		"right_weapon": "RIGHT HAND",
		"wrist": "WRIST/BRACERS",
		"arm": "ARMS/GLOVES",
		"legs": "LEGS",
		"boots": "BOOTS",
		"accessory_1": "RING 1",
		"accessory_2": "RING 2",
		"accessory_3": "RING 3",
		"accessory_4": "RING 4"
	}
	
	for slot_id in slot_order:
		var slot_container = create_equipment_slot(slot_id, slot_labels[slot_id])
		content.add_child(slot_container)
		
		# Add spacing after weapons
		if slot_id == "right_weapon":
			content.add_child(HSeparator.new())
	
	return panel

func create_equipment_slot(slot_id: String, label_text: String) -> HBoxContainer:
	"""Create a single equipment slot row"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	
	# Slot button (square)
	var button = Button.new()
	button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	button.text = ""
	button.name = "slot_" + slot_id
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect drag signals
	button.gui_input.connect(_on_equipment_slot_gui_input.bind(slot_id))
	
	slot_buttons[slot_id] = button
	container.add_child(button)
	
	# Label
	var label = Label.new()
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(label)
	
	return container

func create_stats_panel() -> Panel:
	"""Create center panel with character stats"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(350, 800)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	margin.add_child(content)
	
	# Character name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Character Name"
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	
	# Level and class
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Level 1 Fighter"
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(level_label)
	
	content.add_child(HSeparator.new())
	
	# HP bar
	var hp_container = VBoxContainer.new()
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "HP: 50/50"
	hp_label.add_theme_font_size_override("font_size", 20)
	hp_container.add_child(hp_label)
	
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.max_value = 50
	hp_bar.value = 50
	hp_bar.custom_minimum_size = Vector2(0, 30)
	hp_container.add_child(hp_bar)
	content.add_child(hp_container)
	
	content.add_child(HSeparator.new())
	
	# Ability scores (3x2 grid)
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 30)
	stats_grid.add_theme_constant_override("v_separation", 8)
	
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
	content.add_child(encumbrance_label)
	
	return panel

func create_inventory_panel() -> Panel:
	"""Create right panel with inventory grid"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(450, 800)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	
	# Title
	var title = Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	
	# Slot counter
	var slot_label = Label.new()
	slot_label.name = "SlotLabel"
	slot_label.text = "Slots: 0/25"
	slot_label.add_theme_font_size_override("font_size", 18)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(slot_label)
	
	# Inventory grid
	inventory_grid = GridContainer.new()
	inventory_grid.columns = INVENTORY_COLS
	inventory_grid.add_theme_constant_override("h_separation", 4)
	inventory_grid.add_theme_constant_override("v_separation", 4)
	
	# Create inventory slots (5x5 = 25 visual slots)
	for i in range(INVENTORY_COLS * INVENTORY_ROWS):
		var slot = create_inventory_slot(i)
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)
	
	content.add_child(inventory_grid)
	
	# Sort and filter buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	
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

func _input(event):
	"""Handle input"""
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			hide_screen()
			get_viewport().set_input_as_handled()
