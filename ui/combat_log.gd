# combat_log.gd
extends PanelContainer

@onready var log_text: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/LogText
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var clear_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ClearButton
@onready var toggle_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ToggleButton

var max_lines: int = 100
var current_lines: int = 0
var is_visible_log: bool = true

func _ready():
	# Null checks with helpful errors
	if not log_text:
		push_error("CombatLog: LogText (RichTextLabel) not found at path: MarginContainer/VBoxContainer/ScrollContainer/LogText")
		return
	if not scroll_container:
		push_error("CombatLog: ScrollContainer not found")
		return
	if not clear_button:
		push_error("CombatLog: ClearButton not found")
		return
	if not toggle_button:
		push_error("CombatLog: ToggleButton not found")
		return
	
	print("CombatLog: All nodes found, initializing...")
	
	# Setup
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	
	# Connect buttons
	clear_button.pressed.connect(_on_clear_pressed)
	toggle_button.pressed.connect(_on_toggle_pressed)
	
	# Connect to EventBus
	if EventBus:
		EventBus.damage_applied.connect(_on_damage_applied)
		EventBus.turn_started.connect(_on_turn_started)
		EventBus.turn_ended.connect(_on_turn_ended)
		EventBus.character_died.connect(_on_character_died)
		EventBus.enemy_died.connect(_on_enemy_died)
	else:
		push_warning("CombatLog: EventBus not found, some features won't work")
	
	# Welcome message
	add_message("[color=yellow]⚔️ Combat Log Ready[/color]")
	add_separator()
	
	print("CombatLog: Initialization complete!")

func add_message(text: String):
	"""Add a message to the log"""
	if not log_text:
		return
	
	log_text.append_text(text + "\n")
	current_lines += 1
	
	if current_lines > max_lines:
		clear_log()
	
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func add_separator():
	"""Add a visual separator"""
	add_message("[color=gray]" + "─".repeat(40) + "[/color]")

func _escape_bbcode(text: String) -> String:
	"""Escape '[' so arbitrary names can't break BBCode markup"""
	return text.replace("[", "[lb]")

func clear_log():
	"""Clear the log"""
	if not log_text:
		return
	
	log_text.clear()
	current_lines = 0
	add_message("[color=gray][i]Log cleared[/i][/color]")

func _on_clear_pressed():
	clear_log()

func _on_toggle_pressed():
	if not scroll_container or not toggle_button:
		return
	
	is_visible_log = !is_visible_log
	scroll_container.visible = is_visible_log
	toggle_button.text = "Hide" if is_visible_log else "Show"

# Event handlers
func _on_turn_started(character: Node):
	add_separator()
	var char_name = _escape_bbcode(character.name) if character else "Unknown"
	add_message("[color=cyan]▶ %s's Turn[/color]" % char_name)

func _on_turn_ended(character: Node):
	var char_name = _escape_bbcode(character.name) if character else "Unknown"
	add_message("[color=gray]◀ %s ended turn[/color]" % char_name)

func _on_damage_applied(event: Dictionary):
	"""One line for every time damage is applied (CombatManager.deal_damage):
	who did it, how much of what kind, and whether the target resisted it, was
	vulnerable or immune to it, or was kept on its feet by something"""
	var attacker = event.get("source")
	var target = event.get("target")
	var damage: int = int(event.get("amount", 0))
	var damage_type: String = str(event.get("damage_type", ""))
	var response: String = str(event.get("response", ""))
	var target_name = _escape_bbcode(target.name) if is_instance_valid(target) else "Unknown"
	var what: String = "%d damage" % damage
	if damage_type != "" and damage_type != "physical":
		what = "%d %s damage" % [damage, damage_type]
	if response == "resisted":
		what += " (resisted: halved)"
	elif response == "vulnerable":
		what += " (vulnerable: doubled)"

	if response == "immune":
		add_message("[color=gray]🛡 %s is immune to %s: no damage[/color]" % [target_name, damage_type])
	elif damage <= 0:
		return
	elif not is_instance_valid(attacker):
		add_message("[color=orange]⚔️ %s takes %s[/color]" % [target_name, what])
	elif event.get("is_critical", false):
		add_message("[color=red]💥 CRITICAL HIT! %s hit %s for %s![/color]" % [_escape_bbcode(attacker.name), target_name, what])
	else:
		add_message("[color=orange]⚔️ %s hit %s for %s[/color]" % [_escape_bbcode(attacker.name), target_name, what])
	if event.get("prevented", false):
		add_message("[color=yellow]   %s: %s stays on its feet[/color]" % [_escape_bbcode(str(event.get("prevented_by", ""))), target_name])

	if target and target.has_method("get_hp") and target.has_method("get_max_hp"):
		var hp = target.get_hp()
		var max_hp = target.get_max_hp()
		add_message("[color=gray]   %s: %d/%d HP[/color]" % [target_name, hp, max_hp])

func _on_character_died(character: Node):
	var char_name = _escape_bbcode(character.name) if character else "Character"
	add_message("[color=red]💀 %s has been slain![/color]" % char_name)
	add_separator()

func _on_enemy_died(enemy: Node):
	var enemy_name = _escape_bbcode(enemy.name) if enemy else "Enemy"
	add_message("[color=green]✓ %s defeated![/color]" % enemy_name)

# Custom log functions
func log_attack(attacker_name: String, roll: int, total: int, target_ac: int, hit: bool, is_crit: bool, is_fumble: bool):
	if is_fumble:
		add_message("[color=red]💀 %s rolled a FUMBLE! (Natural 1)[/color]" % attacker_name)
	elif is_crit:
		add_message("[color=yellow]🎲 %s rolled: [b]20[/b] (Natural 20!) vs AC %d - CRITICAL HIT![/color]" % [attacker_name, target_ac])
	elif hit:
		add_message("[color=white]🎲 %s rolled: %d + mods = [b]%d[/b] vs AC %d - HIT![/color]" % [attacker_name, roll, total, target_ac])
	else:
		add_message("[color=gray]🎲 %s rolled: %d + mods = [b]%d[/b] vs AC %d - Miss[/color]" % [attacker_name, roll, total, target_ac])

func log_miss(attacker_name: String):
	add_message("[color=gray]❌ %s missed![/color]" % attacker_name)

func log_heal(target_name: String, amount: int):
	add_message("[color=green]💚 %s healed for %d HP[/color]" % [target_name, amount])

func log_status_effect(target_name: String, effect: String, applied: bool):
	if applied:
		add_message("[color=purple]🔮 %s is now %s[/color]" % [target_name, effect])
	else:
		add_message("[color=gray]🔮 %s is no longer %s[/color]" % [target_name, effect])

func log_custom(message: String, color: String = "white"):
	add_message("[color=%s]%s[/color]" % [color, message])
