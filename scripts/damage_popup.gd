extends Node2D
class_name DamagePopup

# Visual feedback for damage numbers and combat effects

var damage: int = 0
var velocity: Vector2 = Vector2(0, -50)
var lifetime: float = 1.0
var fade_time: float = 0.5
var elapsed: float = 0.0
var is_critical: bool = false
var is_heal: bool = false
var is_miss: bool = false
var scale_factor: float = 1.0

func _ready():
	z_index = 1000  # Always on top

func setup(p_damage: int, p_is_critical: bool = false, p_is_heal: bool = false, p_is_miss: bool = false):
	"""Initialize the damage popup"""
	damage = p_damage
	is_critical = p_is_critical
	is_heal = p_is_heal
	is_miss = p_is_miss
	
	# Randomize horizontal drift slightly
	velocity.x = randf_range(-30, 30)
	
	# Critical hits and misses behave differently
	if is_critical:
		velocity.y = -100
		lifetime = 1.8
		scale_factor = 1.5
	elif is_miss:
		velocity.y = -40
		velocity.x = randf_range(-60, 60)
		lifetime = 1.2
	elif is_heal:
		velocity.y = -60
		lifetime = 1.3
	
	queue_redraw()

func _process(delta):
	elapsed += delta
	position += velocity * delta
	
	# Slow down over time
	velocity = velocity.lerp(Vector2.ZERO, delta * 2.5)
	
	# Gravity effect for misses
	if is_miss:
		velocity.y += 20 * delta
	
	# Fade out near end of lifetime
	queue_redraw()
	
	if elapsed >= lifetime:
		queue_free()

func _draw():
	# Calculate alpha for fade out
	var alpha = 1.0
	if elapsed > lifetime - fade_time:
		alpha = (lifetime - elapsed) / fade_time
	
	# Calculate scale animation (starts bigger, shrinks slightly)
	var anim_scale = scale_factor
	if elapsed < 0.2:
		anim_scale *= 1.0 + (0.2 - elapsed) * 2.0
	
	# Choose color and format text based on type
	var color: Color
	var text: String
	
	if is_miss:
		color = Color(0.6, 0.6, 0.6, alpha)  # Grey for miss
		text = "MISS"
	elif is_heal:
		color = Color(0.3, 1.0, 0.3, alpha)  # Green for healing
		text = "+%d" % damage
	elif is_critical:
		color = Color(1.0, 0.4, 0.0, alpha)  # Orange for crits
		text = "CRIT! %d" % damage
	else:
		color = Color(1.0, 1.0, 1.0, alpha)  # White for normal damage
		text = str(damage)
	
	# Font settings
	var font = ThemeDB.fallback_font
	var base_font_size = 20
	if is_critical:
		base_font_size = 28
	elif is_miss:
		base_font_size = 24
	
	var font_size = int(base_font_size * anim_scale)
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	
	# Draw outline for visibility (thicker for important messages)
	var outline_thickness = 2 if (is_critical or is_miss) else 1
	for i in range(outline_thickness):
		for offset in [
			Vector2(-1-i, -1-i), Vector2(0, -1-i), Vector2(1+i, -1-i),
			Vector2(-1-i, 0), Vector2(1+i, 0),
			Vector2(-1-i, 1+i), Vector2(0, 1+i), Vector2(1+i, 1+i)
		]:
			draw_string(font, Vector2(-text_size.x / 2, 0) + offset, text, 
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, alpha * 0.8))
	
	# Draw main text
	draw_string(font, Vector2(-text_size.x / 2, 0), text, 
		HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	
	# Draw additional effects for critical
	if is_critical and elapsed < 0.5:
		var spark_alpha = (0.5 - elapsed) / 0.5
		for i in range(6):
			var angle = (TAU / 6.0) * i + elapsed * 10
			var spark_pos = Vector2(cos(angle), sin(angle)) * 20 * (1.0 + elapsed * 2)
			draw_circle(spark_pos, 2, Color(1.0, 0.8, 0.0, alpha * spark_alpha))


# ============================================================================
# HELPER FUNCTIONS TO ADD TO GRIDCHARACTER AND ENEMY CLASSES
# ============================================================================

# Add these functions to both GridCharacter and Enemy classes:

static func spawn_damage_popup_at(world: Node2D, world_pos: Vector2, damage: int, is_critical: bool = false):
	"""Static helper to spawn a damage popup at a world position"""
	var popup = DamagePopup.new()
	world.add_child(popup)
	popup.global_position = world_pos
	popup.setup(damage, is_critical, false, false)

static func spawn_heal_popup_at(world: Node2D, world_pos: Vector2, amount: int):
	"""Static helper to spawn a healing popup at a world position"""
	var popup = DamagePopup.new()
	world.add_child(popup)
	popup.global_position = world_pos
	popup.setup(amount, false, true, false)

static func spawn_miss_popup_at(world: Node2D, world_pos: Vector2):
	"""Static helper to spawn a miss popup at a world position"""
	var popup = DamagePopup.new()
	world.add_child(popup)
	popup.global_position = world_pos
	popup.setup(0, false, false, true)


# ============================================================================
# UPDATED TAKE_DAMAGE FUNCTIONS FOR YOUR CLASSES
# ============================================================================

# Replace the take_damage function in GridCharacter with this:
"""
func take_damage(amount: int):
	current_hp -= amount
	print("%s took %d damage! HP: %d/%d" % [name, amount, current_hp, max_hp])
	
	# Spawn damage popup
	var world = get_parent()
	if world:
		var popup_pos = global_position + Vector2(0, -tile_size * 0.8)
		DamagePopup.spawn_damage_popup_at(world, popup_pos, amount, false)
	
	# Flash effect
	flash_damage()
	
	queue_redraw()
	
	if current_hp <= 0:
		die()

func flash_damage():
	# Quick red flash effect
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func heal(amount: int):
	current_hp = min(current_hp + amount, max_hp)
	print("%s healed %d HP! HP: %d/%d" % [name, amount, current_hp, max_hp])
	
	# Spawn heal popup
	var world = get_parent()
	if world:
		var popup_pos = global_position + Vector2(0, -tile_size * 0.8)
		DamagePopup.spawn_heal_popup_at(world, popup_pos, amount)
	
	queue_redraw()
"""

# Replace the take_damage function in Enemy with this:
"""
func take_damage(amount: int):
	current_hp -= amount
	print("%s took %d damage! HP: %d/%d" % [name, amount, current_hp, max_hp])
	
	# Spawn damage popup
	var world = get_parent()
	if world:
		var popup_pos = global_position + Vector2(0, -tile_size * 0.8)
		DamagePopup.spawn_damage_popup_at(world, popup_pos, amount, false)
	
	# Flash effect
	flash_damage()
	
	queue_redraw()
	
	if current_hp <= 0:
		die()

func flash_damage():
	# Quick red flash effect
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 0.5, 0.5), 0.1)
		tween.tween_property(sprite, "modulate", enemy_color, 0.2)
"""

# ============================================================================
# ATTACK ANIMATION HELPER
# ============================================================================

# Add this to GridCharacter to animate attacks:
"""
func attack_enemy(enemy: Enemy, attack_type: String):
	if not enemy or not turn_based_mode:
		return
	
	if has_attacked_this_turn:
		print("You've already attacked this turn!")
		return
	
	var damage = 0
	var attack_name = ""
	
	match attack_type:
		"light":
			damage = light_attack_damage
			attack_name = "Light Attack"
		"medium":
			damage = medium_attack_damage
			attack_name = "Medium Attack"
		"heavy":
			damage = heavy_attack_damage
			attack_name = "Heavy Attack"
	
	# Attack animation - lunge toward enemy
	animate_attack(enemy.global_position)
	
	print("Player uses %s on %s for %d damage!" % [attack_name, enemy.name, damage])
	
	# Delay damage until animation halfway through
	await get_tree().create_timer(0.15).timeout
	enemy.take_damage(damage)
	
	# Mark that we've attacked this turn
	has_attacked_this_turn = true
	
	# Cancel attack mode after attacking
	attack_mode = false
	selected_attack_type = ""
	queue_redraw()

func animate_attack(target_pos: Vector2):
	var original_pos = global_position
	var direction = (target_pos - original_pos).normalized()
	var lunge_distance = tile_size * 0.5
	
	# Quick lunge toward target
	var tween = create_tween()
	tween.tween_property(self, "global_position", original_pos + direction * lunge_distance, 0.1)
	tween.tween_property(self, "global_position", original_pos, 0.15)
"""
