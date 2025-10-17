extends Camera2D
class_name CameraController

# Simple camera that follows the player and accounts for UI

@export var target: Node2D  # The player to follow
@export var smoothing_speed: float = 5.0
@export var ui_bottom_fraction: float = 0.25  # UI takes up bottom 25% of screen

func _ready():
	enabled = true
	make_current()
	print("CameraController ready")

func _process(delta):
	if not target:
		print("CameraController: No target set!")
		return
	
	# Get viewport dimensions
	var viewport_height = get_viewport_rect().size.y
	
	# UI takes bottom 25% of screen
	var ui_height = viewport_height * ui_bottom_fraction
	
	# To center character in the TOP 3/4 of screen:
	# The playable area's center is at 3/8 from the top (half of 3/4)
	# Screen center is at 1/2 from the top
	# We need to shift view UP by (1/2 - 3/8) = 1/8 of screen
	# Moving view UP means moving camera DOWN in world (positive Y offset)
	var camera_offset_y = ui_height / 2.0
	
	# Target position with offset
	var target_pos = target.global_position
	target_pos.y += camera_offset_y
	
	# Smooth follow
	global_position = global_position.lerp(target_pos, smoothing_speed * delta)
