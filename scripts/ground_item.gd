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
var _sprite: Sprite2D = null
var _tile_size: int = ArtLibrary.TILE_SIZE


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
	node._tile_size = tile_size
	node._refresh_sprite()

	print("GroundItem: Spawned at ", grid_position, " with ", instances.size(),
		" items and ", gold_amount, " gold")
	return node


# =====================================================================
# GODOT OVERRIDES
# =====================================================================

func _ready():
	"""Build the visual: the loot sprite from ArtLibrary."""
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	add_child(_sprite)
	_refresh_sprite()


func _refresh_sprite():
	"""A bag while the drop holds items, a pile of coins when it is gold only."""
	if _sprite:
		ArtLibrary.fit_sprite(_sprite, ArtLibrary.loot_marker(not item_instances.is_empty()), _tile_size)


func _process(delta: float):
	"""Bob the sprite up and down."""
	_bob_time += delta * BOB_SPEED
	position.y = _base_y + sin(_bob_time) * BOB_AMPLITUDE


# =====================================================================
# PICKUP
# =====================================================================

func pickup():
	"""
	Transfer items and gold to InventoryManager.
	Emits EventBus.item_picked_up per item and a ui_notification summary.
	Items the bag refuses (too heavy) STAY on the ground; the node is only
	freed once nothing is left in it.
	"""
	var picked_count := 0
	var picked_names: Array = []
	var left_behind: Array = []
	var picked_gold := gold

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
		else:
			left_behind.append(inst)

	if gold > 0:
		InventoryManager.add_gold(gold)
	item_instances = left_behind
	gold = 0

	# Summary notification
	var summary := ""
	if picked_count > 0:
		if picked_names.size() <= 2:
			summary = "Picked up: " + ", ".join(picked_names)
		else:
			summary = "Picked up %d items" % picked_count
	if picked_gold > 0:
		if summary != "":
			summary += " and %d gold" % picked_gold
		else:
			summary = "Picked up %d gold" % picked_gold

	if summary != "":
		EventBus.ui_notification.emit(summary, "success")

	print("GroundItem: Picked up at ", grid_pos, " — ", summary)

	if left_behind.is_empty():
		queue_free()
	else:
		EventBus.ui_notification.emit(
			"Too heavy to carry: %d item(s) left on the ground." % left_behind.size(), "warning")
		_refresh_sprite()
