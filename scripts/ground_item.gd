# ground_item.gd
# Node2D that represents dropped loot on the dungeon floor.
#
# API:
#   GroundItem.spawn(parent, grid_pos, tile_size, item_instances, gold) -> Node2D
#       Instantiate and position a drop marker in the scene tree.
#
#   ground_item.pickup() -> void
#       Add all stored items + gold to InventoryManager, emit signals per item,
#       show a ui_notification summary, then queue_free the node.
#
# Properties (readable by external systems):
#   grid_pos     : Vector2i   — the tile this drop lives on
#   item_instances : Array    — item instance Dictionaries (same format as InventoryManager)
#   gold         : int        — gold amount in the drop
#
# Integration note:
#   The orchestrator (world.gd / grid_character.gd) should call pickup() when the
#   player moves onto grid_pos. The node exposes grid_pos as a public property for that check.

extends Node2D

# ── Public properties ─────────────────────────────────────────────────
var grid_pos: Vector2i = Vector2i.ZERO
var item_instances: Array = []
var gold: int = 0

# ── Internal ──────────────────────────────────────────────────────────
var _bob_time: float = 0.0
const BOB_SPEED := 2.5
const BOB_AMPLITUDE := 3.0
var _base_y: float = 0.0


# =====================================================================
# STATIC FACTORY
# =====================================================================

static func spawn(parent: Node, grid_position: Vector2i, tile_size: int,
		instances: Array, gold_amount: int = 0) -> Node2D:
	"""
	Create a GroundItem node, attach it to parent, and position it at the
	center of the given grid tile. Returns the new node.
	"""
	var node := preload("res://scripts/ground_item.gd").new()
	node.name = "GroundItem_%d_%d" % [grid_position.x, grid_position.y]
	node.grid_pos = grid_position
	node.item_instances = instances.duplicate(true)
	node.gold = gold_amount

	parent.add_child(node)

	# Position at tile center
	var world_pos := Vector2(
		grid_position.x * tile_size + tile_size / 2,
		grid_position.y * tile_size + tile_size / 2
	)
	node.position = world_pos
	node._base_y = world_pos.y

	print("GroundItem: Spawned at ", grid_position, " with ", instances.size(),
		" items and ", gold_amount, " gold")
	return node


# =====================================================================
# GODOT OVERRIDES
# =====================================================================

func _ready():
	"""Build the visual: a gold/brown diamond drawn by draw calls."""
	# Visual is rendered by _draw(); nothing to add to scene tree here.
	pass


func _draw():
	"""Draw a simple diamond shape as the loot marker."""
	var color := Color(0.90, 0.70, 0.10) if gold > 0 else Color(0.75, 0.50, 0.25)
	var size := 6.0
	var points := PackedVector2Array([
		Vector2(0, -size),
		Vector2(size, 0),
		Vector2(0, size),
		Vector2(-size, 0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 1.0)

	# Small "?" if there are items
	if not item_instances.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-3, 4), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)


func _process(delta: float):
	"""Bob the sprite up and down."""
	_bob_time += delta * BOB_SPEED
	position.y = _base_y + sin(_bob_time) * BOB_AMPLITUDE
	queue_redraw()


# =====================================================================
# PICKUP
# =====================================================================

func pickup():
	"""
	Transfer all items and gold to InventoryManager.
	Emits EventBus.item_picked_up per item and a ui_notification summary.
	Then frees this node.
	"""
	var picked_count := 0
	var picked_names: Array = []

	for inst in item_instances:
		if inst.is_empty():
			continue
		var success := InventoryManager.add_item(inst)
		if success:
			picked_count += 1
			var item_data: ItemData = inst.get("item_data", null)
			if item_data:
				picked_names.append(item_data.item_name)
			EventBus.item_picked_up.emit(inst)

	if gold > 0:
		InventoryManager.add_gold(gold)

	# Summary notification
	var summary := ""
	if picked_count > 0:
		if picked_names.size() <= 2:
			summary = "Picked up: " + ", ".join(picked_names)
		else:
			summary = "Picked up %d items" % picked_count
	if gold > 0:
		if summary != "":
			summary += " and %d gold" % gold
		else:
			summary = "Picked up %d gold" % gold

	if summary != "":
		EventBus.ui_notification.emit(summary, "success")

	print("GroundItem: Picked up at ", grid_pos, " — ", summary)
	queue_free()
