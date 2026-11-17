# attack_preview.gd
# The readout beside an enemy while an attack is aimed at it
# (scenes/ui/attack_preview.tscn): the weapon that would be used, the chance to
# hit, the damage, whether the target resists it, is vulnerable or immune to
# it, and what gives the roll advantage or disadvantage or the target cover -
# or, for an enemy that cannot be attacked, the reason.
# Display only. Everything it shows is the CombatController's answer
# (preview_attack), which the combatant keeps while the pointer rests on an
# enemy (Combatant.get_aim_preview).
extends Control

# Where the panel sits: beside the target's tile, clear of the screen edges
const GAP: float = 14.0
const EDGE_MARGIN: float = 8.0

const COLOR_GOOD := Color(0.55, 0.9, 0.55)
const COLOR_FAIR := Color(1.0, 0.9, 0.3)
const COLOR_POOR := Color(0.95, 0.62, 0.3)

# Whose aim this shows, and the HUD it must not cover
var combatant: Combatant = null
var _keep_clear: Control = null

@onready var _panel: PanelContainer = %Panel
@onready var _target: Label = %Target
@onready var _weapon: Label = %Weapon
@onready var _chance: Label = %Chance
@onready var _damage: Label = %Damage
@onready var _response: Label = %Response
@onready var _advantage: Label = %Advantage
@onready var _disadvantage: Label = %Disadvantage
@onready var _cover: Label = %Cover
@onready var _refusal: Label = %Refusal

func _ready():
	_panel.visible = false

func setup(p_combatant: Combatant, keep_clear: Control = null):
	"""Give the readout the combatant whose aim it shows, and the part of the
	HUD (the bottom bar) it stays out of"""
	combatant = p_combatant
	_keep_clear = keep_clear
	refresh()

func _process(_delta):
	refresh()

func is_showing() -> bool:
	return _panel.visible

func get_lines() -> Array[String]:
	"""The text on show, top to bottom: for checks"""
	var lines: Array[String] = []
	if _panel.visible:
		for label in [_target, _weapon, _chance, _damage, _response, _advantage, _disadvantage, _cover, _refusal]:
			if label.visible:
				lines.append(label.text)
	return lines

func refresh():
	"""Show what the combatant is aiming at right now, or nothing"""
	var preview: Dictionary = combatant.get_aim_preview() if is_instance_valid(combatant) else {}
	var target = preview.get("target")
	if preview.is_empty() or not is_instance_valid(target):
		_panel.visible = false
		return
	_fill(preview, target)
	_panel.visible = true
	_panel.reset_size()
	_place_beside(target)

func _fill(preview: Dictionary, target: Combatant):
	var can_attack: bool = preview.get("ok", false)
	var hit: Dictionary = preview.get("hit_chance", {})
	var cancelled: bool = hit.get("advantage", false) and hit.get("disadvantage", false)

	_target.text = target.get_display_name()
	_weapon.text = str(preview.get("weapon_name", ""))
	_weapon.visible = can_attack
	_chance.text = "%d%% to hit" % int(hit.get("percent", 0))
	_chance.add_theme_color_override("font_color", _chance_color(int(hit.get("percent", 0))))
	_chance.visible = can_attack
	_damage.text = "%s damage" % str(preview.get("damage_text", ""))
	_damage.visible = can_attack
	# What the target's nature does to this kind of damage: half, double, none
	var response_text: String = str(preview.get("damage_response", {}).get("text", ""))
	_response.text = response_text
	_response.visible = can_attack and response_text != ""

	_show_reasons(_advantage, "Advantage", hit.get("advantage_reasons", []), cancelled, can_attack)
	_show_reasons(_disadvantage, "Disadvantage", hit.get("disadvantage_reasons", []), cancelled, can_attack)
	var cover_bonus: int = int(hit.get("cover_bonus", 0))
	_cover.text = "%s cover: +%d armour class" % ["Full" if cover_bonus >= CombatGrid.COVER_FULL else "Half", cover_bonus]
	_cover.visible = can_attack and cover_bonus > 0

	_refusal.text = "Cannot attack: %s" % str(preview.get("reason", ""))
	_refusal.visible = not can_attack

func _show_reasons(label: Label, title: String, reasons: Array, cancelled: bool, can_attack: bool):
	"""'Disadvantage: long range, enemy adjacent'; advantage and disadvantage
	together are a plain roll, and both lines say so"""
	label.visible = can_attack and not reasons.is_empty()
	label.text = "%s: %s%s" % [title, ", ".join(reasons), " (cancelled out)" if cancelled else ""]

func _chance_color(percent: int) -> Color:
	if percent >= 65:
		return COLOR_GOOD
	return COLOR_FAIR if percent >= 40 else COLOR_POOR

func _place_beside(target: Combatant):
	"""Beside the target's tile, on the side away from the attacker so that the
	line between the two stays in view; on the other side when the screen ends
	there; never over the bottom bar"""
	var on_screen: Transform2D = target.get_global_transform_with_canvas()
	var centre: Vector2 = on_screen.origin
	var half_tile: float = target.tile_size * on_screen.get_scale().x / 2.0
	var area: Rect2 = get_viewport_rect()
	var floor_y: float = area.end.y
	if is_instance_valid(_keep_clear):
		floor_y = _keep_clear.get_global_rect().position.y
	var size_now: Vector2 = _panel.size

	var right_x: float = centre.x + half_tile + GAP
	var left_x: float = centre.x - half_tile - GAP - size_now.x
	var fits_right: bool = right_x + size_now.x <= area.end.x - EDGE_MARGIN
	var fits_left: bool = left_x >= EDGE_MARGIN
	var attacker_on_right: bool = combatant.get_global_transform_with_canvas().origin.x > centre.x
	var x: float = right_x
	if (attacker_on_right and fits_left) or not fits_right:
		x = left_x
	var y: float = clampf(centre.y - size_now.y / 2.0, EDGE_MARGIN, maxf(EDGE_MARGIN, floor_y - EDGE_MARGIN - size_now.y))
	_panel.position = Vector2(maxf(EDGE_MARGIN, x), y)
