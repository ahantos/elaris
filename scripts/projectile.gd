# projectile.gd
# What a ranged attack looks like on its way: an arrow, drawn in code, that
# flies from the attacker to the target and is gone when it lands. Display
# only: the attack was rolled and its damage applied before the arrow left.
# It moves in _process, so it stands still while the game is paused.
extends Node2D
class_name Projectile

const SPEED: float = 900.0      # pixels per second (about 28 tiles on the 32px grid)
const MIN_FLIGHT: float = 0.08  # seconds, however short the shot
const MAX_FLIGHT: float = 0.35  # seconds, however long

const SHAFT_COLOR := Color(0.93, 0.87, 0.72)
const HEAD_COLOR := Color(0.82, 0.84, 0.9)
const FLETCHING_COLOR := Color(0.85, 0.3, 0.25)

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _flight: float = MIN_FLIGHT
var _elapsed: float = 0.0
var _on_landed: Callable = Callable()

static func launch(parent: Node, from: Vector2, to: Vector2, on_landed: Callable = Callable()) -> Projectile:
	"""Send an arrow from one world position to another under parent.
	on_landed is called once, when it arrives; it is never called when the
	arrow is freed on the way (the scene went away)."""
	var projectile := Projectile.new()
	projectile._from = from
	projectile._to = to
	projectile._flight = clampf(from.distance_to(to) / SPEED, MIN_FLIGHT, MAX_FLIGHT)
	projectile._on_landed = on_landed
	parent.add_child(projectile)
	projectile.global_position = from
	projectile.rotation = (to - from).angle()
	return projectile

func _ready():
	z_index = 900  # over every combatant, under the floating numbers

func get_flight_time() -> float:
	"""Seconds from the bow to the target"""
	return _flight

func _process(delta):
	_elapsed += delta
	var progress: float = minf(_elapsed / _flight, 1.0)
	global_position = _from.lerp(_to, progress)
	if progress >= 1.0:
		set_process(false)
		if _on_landed.is_valid():
			_on_landed.call()
		queue_free()

func _draw():
	draw_line(Vector2(-8, 0), Vector2(5, 0), SHAFT_COLOR, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(9, 0), Vector2(4, -3), Vector2(4, 3)]), HEAD_COLOR)
	draw_line(Vector2(-8, 0), Vector2(-11, -3), FLETCHING_COLOR, 1.5)
	draw_line(Vector2(-8, 0), Vector2(-11, 3), FLETCHING_COLOR, 1.5)
